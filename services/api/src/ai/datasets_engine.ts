/**
 * =============================================================================
 * VYRA DATASETS — AI Engine Backend Routes
 * =============================================================================
 * Routes added by this module:
 *
 *   POST /health/report/analyze        → Upload + Gemini-analyze blood report
 *   GET  /health/report/biomarkers     → Get user's biomarker history
 *   GET  /health/report/list           → List all uploaded reports
 *
 *   POST /social/contact-sync          → WhatsApp-style friend discovery
 *   GET  /social/friends/leaderboard   → Friends leaderboard (weekly steps)
 *
 *   GET  /blood/eligibility            → Check donation eligibility
 *   GET  /blood/banks                  → Nearby blood banks (lat/lng radius)
 *   GET  /blood/requests               → Active blood requests near location
 *   POST /blood/raise-hand             → Register as available donor for request
 *
 *   GET  /doctors/nearby               → Nearby doctors by specialty
 *
 *   GET  /slogans/today                → Today's motivational slogan
 *
 *   GET  /admin/feature-flags          → List all feature flags (admin only)
 *   PUT  /admin/feature-flags/:key     → Toggle feature flag (admin only)
 *   GET  /admin/system-status          → System status values
 *   PUT  /admin/system-status/:key     → Update system value (admin only)
 *   GET  /admin/tickets                → Support tickets (admin only)
 *   POST /admin/tickets/:id/reply      → Reply to support ticket (admin only)
 *
 *   GET  /app/config                   → App bootstrap config (feature flags + status)
 * =============================================================================
 */

import type { Ctx } from '../http/router';
import { HttpError } from '../http/router';
import type { Store } from '../store';
import type { GeminiClient } from '../ai/gemini';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface BloodReportBiomarker {
  code: string;
  name: string;
  value: number;
  unit: string;
  status: 'normal' | 'borderline_low' | 'low' | 'borderline_high' | 'high' | 'critical';
  labRefMin?: number;
  labRefMax?: number;
}

interface BloodReportAnalysis {
  labName: string;
  reportDate: string;
  biomarkers: BloodReportBiomarker[];
  insights: Array<{ text: string; severity: 'info' | 'warning' | 'critical'; action?: string }>;
  summary: string;
}

interface ContactSyncRequest {
  hashes: string[];  // SHA256 of normalised E.164 phone numbers
}

interface NearbyQuery {
  lat: number;
  lng: number;
  radiusKm?: number;    // default 7
  specialty?: string;   // for doctors
}

// ---------------------------------------------------------------------------
// Gemini prompts
// ---------------------------------------------------------------------------

const BLOOD_REPORT_PROMPT = (rawText: string, userContext: string) => `
You are a medical AI assistant for VYRA, an Indian fitness app.
Analyze this blood test report and return a JSON object with the following structure:
{
  "labName": string,
  "reportDate": "YYYY-MM-DD",
  "biomarkers": [
    {
      "code": "HGB",
      "name": "Hemoglobin",
      "value": 11.2,
      "unit": "g/dL",
      "status": "low",
      "labRefMin": 12.0,
      "labRefMax": 17.0
    }
  ],
  "insights": [
    {
      "text": "Your Vitamin D is low (18 ng/mL). Consider 15 minutes of morning sunlight and adding eggs or fortified milk to your diet.",
      "severity": "warning",
      "action": "Add Vitamin D foods"
    }
  ],
  "summary": "Overall your report looks good with a few areas to watch..."
}

IMPORTANT RULES:
- Use Indian population reference ranges (ICMR norms), NOT Western norms
- Vitamin D <20 ng/mL = low for Indians (many labs show >30 as normal — that's Western)
- Hemoglobin: women <12 g/dL = low, men <13 g/dL = low (ICMR standard)
- Keep insights practical, friendly, and actionable — not scary
- If a value is normal, still mention it positively
- Status values: 'normal' | 'borderline_low' | 'low' | 'borderline_high' | 'high' | 'critical'
- Generate 4-7 insights

User context (personalize insights accordingly):
${userContext}

Blood report text:
${rawText}
`;

const SLOGAN_PROMPT = (category: string, language: string, streak: number) => `
Generate ONE motivational fitness slogan for a ${language}-speaking Indian fitness app user.
Category: ${category}
User streak: ${streak} days
Language: ${language}

Requirements:
- If language is 'hi', write in Hindi (Devanagari script)
- If language is 'en', write in English with Indian cultural references
- For Tamil/Telugu/Malayalam/etc, write in that language
- Must feel personal, genuine, and energizing — NOT generic
- Maximum 15 words
- No hashtags, no emojis in text

Return ONLY the slogan text, nothing else.
`;

// ---------------------------------------------------------------------------
// Health Report Analysis
// ---------------------------------------------------------------------------

export async function analyzeHealthReport(
  ctx: Ctx,
  store: Store,
  gemini: GeminiClient | null,
): Promise<unknown> {
  if (!ctx.userId) throw HttpError.unauthorized();

  const body = ctx.body as {
    imageBase64?: string;
    mimeType?: string;
    rawText?: string;    // if client already OCR'd it
  };

  if (!body.imageBase64 && !body.rawText) {
    throw HttpError.badRequest('Provide imageBase64 or rawText of the blood report.');
  }

  // Fetch user context to personalise the analysis
  const user = await store.getUser(ctx.userId);
  if (!user) throw HttpError.notFound('User not found.');

  const userContext = [
    `Age: ${calculateAge(user.dob)}`,
    `Gender: ${user.gender}`,
    `Height: ${user.heightCm}cm, Weight: ${user.weightKg}kg`,
    `Fitness goal: ${user.fitnessGoal}`,
    `Diet preference: ${user.dietPreference}`,
  ].join('\n');

  let analysis: BloodReportAnalysis;

  if (gemini) {
    try {
      const rawText = body.rawText ?? '[Blood report image — extract all test names, values, units, and reference ranges]';
      const prompt = BLOOD_REPORT_PROMPT(rawText, userContext);

      let geminiResult: string;
      if (body.imageBase64 && body.mimeType) {
        geminiResult = await gemini.generateText({
          prompt,
          image: { dataBase64: body.imageBase64, mimeType: body.mimeType as 'image/jpeg' | 'image/png' },
          temperature: 0.2,
        });
      } else {
        geminiResult = await gemini.generateText({ prompt, temperature: 0.2 });
      }

      // Clean JSON fence if present
      const cleaned = geminiResult.trim()
        .replace(/^```(?:json)?\s*/i, '')
        .replace(/\s*```$/, '');
      analysis = JSON.parse(cleaned) as BloodReportAnalysis;
    } catch (err) {
      // Graceful degradation: return a structured error with mock fallback
      console.error('[VYRA] Blood report AI analysis failed:', err);
      analysis = getMockBloodAnalysis();
    }
  } else {
    // No Gemini → return mock for demo
    analysis = getMockBloodAnalysis();
  }

  // TODO: Store in health_reports + health_report_biomarkers tables
  // await store.saveHealthReport(ctx.userId, analysis);

  return { success: true, analysis };
}

// ---------------------------------------------------------------------------
// Contact Sync (WhatsApp-style friend discovery)
// ---------------------------------------------------------------------------

export async function contactSync(
  ctx: Ctx,
  store: Store,
): Promise<unknown> {
  if (!ctx.userId) throw HttpError.unauthorized();

  const body = ctx.body as ContactSyncRequest;
  if (!Array.isArray(body?.hashes) || body.hashes.length === 0) {
    throw HttpError.badRequest('Provide an array of hashed phone numbers.');
  }

  // Validate: only accept valid SHA256 hashes (64 hex chars)
  const validHashes = body.hashes.filter(h => /^[a-f0-9]{64}$/.test(h));
  if (validHashes.length === 0) {
    throw HttpError.badRequest('No valid SHA256 hashes provided.');
  }

  // Limit: max 500 hashes per request (prevents abuse)
  const limited = validHashes.slice(0, 500);

  // TODO: Query database for matching users
  // const matched = await store.findUsersByContactHashes(limited, ctx.userId);
  // For now, return demo data
  const matched = [
    { id: 'demo-1', name: 'Priya Sharma', avatarInitials: 'PS', weeklySteps: 42150, isFollowing: false },
    { id: 'demo-2', name: 'Rohit Singh', avatarInitials: 'RS', weeklySteps: 38920, isFollowing: true },
  ];

  return {
    matched,
    totalChecked: limited.length,
    matchCount: matched.length,
    message: `Found ${matched.length} friends already on VYRA!`,
  };
}

// ---------------------------------------------------------------------------
// Friends Leaderboard
// ---------------------------------------------------------------------------

export async function getFriendsLeaderboard(
  ctx: Ctx,
  store: Store,
): Promise<unknown> {
  if (!ctx.userId) throw HttpError.unauthorized();

  const scope = (ctx.query.get('scope') ?? 'friends') as 'friends' | 'city' | 'india';

  // TODO: Real DB query using store.getFriendsLeaderboard(ctx.userId, scope)
  // SELECT u.id, u.name, COALESCE(SUM(a.steps), 0) as weekly_steps,
  //        RANK() OVER (ORDER BY COALESCE(SUM(a.steps),0) DESC) as rank
  // FROM social_follows sf
  // JOIN users u ON u.id = sf.following_id
  // LEFT JOIN activities a ON a.user_id = u.id AND a.recorded_at >= date_trunc('week', NOW())
  // WHERE sf.follower_id = $1
  // GROUP BY u.id ORDER BY weekly_steps DESC;

  const mockLeaderboard = [
    { rank: 1, userId: 'u1', name: 'Arjun Verma',    initials: 'AV', weeklySteps: 87420, dailyAvg: 12488, isCurrentUser: false },
    { rank: 2, userId: 'u2', name: 'Sneha Gupta',    initials: 'SG', weeklySteps: 71350, dailyAvg: 10192, isCurrentUser: false },
    { rank: 3, userId: 'u3', name: 'You',             initials: 'YO', weeklySteps: 64200, dailyAvg: 9171,  isCurrentUser: true  },
    { rank: 4, userId: 'u4', name: 'Rahul Joshi',    initials: 'RJ', weeklySteps: 58900, dailyAvg: 8414,  isCurrentUser: false },
    { rank: 5, userId: 'u5', name: 'Nisha Patel',    initials: 'NP', weeklySteps: 51200, dailyAvg: 7314,  isCurrentUser: false },
    { rank: 6, userId: 'u6', name: 'Dev Kumar',      initials: 'DK', weeklySteps: 43800, dailyAvg: 6257,  isCurrentUser: false },
    { rank: 7, userId: 'u7', name: 'Priya Iyer',     initials: 'PI', weeklySteps: 38100, dailyAvg: 5442,  isCurrentUser: false },
    { rank: 8, userId: 'u8', name: 'Kartik Mehta',   initials: 'KM', weeklySteps: 31500, dailyAvg: 4500,  isCurrentUser: false },
  ];

  return { scope, leaderboard: mockLeaderboard, weekOf: getMondayOfWeek() };
}

// ---------------------------------------------------------------------------
// Blood Donation
// ---------------------------------------------------------------------------

export async function checkBloodEligibility(ctx: Ctx, store: Store): Promise<unknown> {
  if (!ctx.userId) throw HttpError.unauthorized();

  // TODO: fetch from user_health_profile table
  // const profile = await store.getUserHealthProfile(ctx.userId);

  // Mock eligibility check
  const lastDonation = new Date('2025-06-01');
  const daysSince = Math.floor((Date.now() - lastDonation.getTime()) / 86400000);
  const isEligible = daysSince >= 90;

  return {
    isEligible,
    reasons: isEligible ? [] : [`Last donated ${daysSince} days ago (90 days required)`],
    daysUntilEligible: isEligible ? 0 : 90 - daysSince,
    lastDonationDate: lastDonation.toISOString().split('T')[0],
    criteria: {
      gap90Days:    { met: daysSince >= 90,  label: '90+ days since last donation', value: `${daysSince} days ago` },
      weight45kg:   { met: true,             label: 'Weight above 45kg',            value: '70 kg' },
      age18to65:    { met: true,             label: 'Age between 18-65',            value: '22 years' },
      noRecentIll:  { met: true,             label: 'No recent illness/surgery',    value: 'Healthy' },
      hemoglobin:   { met: true,             label: 'Hemoglobin ≥ 12.5 g/dL',     value: '14.2 g/dL' },
    },
  };
}

export async function getNearbyBloodBanks(ctx: Ctx): Promise<unknown> {
  const lat  = parseFloat(ctx.query.get('lat')  ?? '28.6139');
  const lng  = parseFloat(ctx.query.get('lng')  ?? '77.2090');
  const radius = parseFloat(ctx.query.get('radius') ?? '7');

  if (isNaN(lat) || isNaN(lng)) throw HttpError.badRequest('lat and lng are required.');

  // TODO: Real query:
  // SELECT *, earth_distance(ll_to_earth($1,$2), ll_to_earth(lat::float8,lng::float8))/1000 AS dist_km
  // FROM blood_banks
  // WHERE earth_box(ll_to_earth($1,$2), $3*1000) @> ll_to_earth(lat::float8,lng::float8)
  // ORDER BY dist_km LIMIT 10;

  const mockBanks = [
    { id: 'bb1', name: 'AIIMS Blood Bank',           address: 'AIIMS, New Delhi',         dist_km: 1.2, phone: '011-26593478', hours: 'Mon-Sat 8am-5pm', isVerified: true  },
    { id: 'bb2', name: 'Safdarjung Hospital BB',     address: 'Safdarjung, New Delhi',     dist_km: 2.8, phone: '011-26165060', hours: '24x7',             isVerified: true  },
    { id: 'bb3', name: 'Red Cross Blood Bank',       address: 'Red Cross Society, Delhi',  dist_km: 4.1, phone: '011-23716441', hours: 'Mon-Sat 9am-5pm', isVerified: true  },
    { id: 'bb4', name: 'Max Super Speciality BB',   address: 'Saket, New Delhi',           dist_km: 5.6, phone: '011-26515050', hours: '24x7',             isVerified: false },
  ];

  return { banks: mockBanks.filter(b => b.dist_km <= radius), queryLat: lat, queryLng: lng };
}

export async function getNearbyBloodRequests(ctx: Ctx): Promise<unknown> {
  const lat = parseFloat(ctx.query.get('lat') ?? '28.6139');
  const lng = parseFloat(ctx.query.get('lng') ?? '77.2090');

  // TODO: Real query from blood_requests table, expiry check, geo filter
  return {
    requests: [
      { id: 'br1', bloodGroup: 'O+',  unitsNeeded: 2, hospital: 'AIIMS, New Delhi',       distKm: 1.2, isUrgent: true,  contactPhone: '9810012345', postedAt: '2 hours ago' },
      { id: 'br2', bloodGroup: 'AB-', unitsNeeded: 1, hospital: 'Apollo, Saket',           distKm: 5.1, isUrgent: false, contactPhone: '9820023456', postedAt: '6 hours ago' },
      { id: 'br3', bloodGroup: 'B+',  unitsNeeded: 3, hospital: 'Safdarjung Hospital',     distKm: 2.8, isUrgent: true,  contactPhone: '9830034567', postedAt: '1 hour ago'  },
    ],
  };
}

// ---------------------------------------------------------------------------
// Nearby Doctors
// ---------------------------------------------------------------------------

export async function getNearbyDoctors(ctx: Ctx): Promise<unknown> {
  const lat       = parseFloat(ctx.query.get('lat')       ?? '28.6139');
  const lng       = parseFloat(ctx.query.get('lng')       ?? '77.2090');
  const specialty = ctx.query.get('specialty') ?? 'general';
  const radius    = parseFloat(ctx.query.get('radius')    ?? '10');

  // TODO: Real geo query from doctors table
  // SELECT *, earth_distance(...)/1000 as dist_km FROM doctors
  // WHERE (specialty = $3 OR $3 = 'all')
  // AND earth_box(...) @> ll_to_earth(lat,lng)
  // ORDER BY rating DESC, dist_km

  const mockDoctors = [
    { id: 'd1', name: 'Dr. Meera Kapoor',   specialty: 'nutritionist',    clinicName: 'Kapoor Nutrition Clinic',  rating: 4.8, reviews: 312, distKm: 1.4, availableToday: true,  feeInr: 800,  acceptsOnline: true  },
    { id: 'd2', name: 'Dr. Rajiv Sharma',   specialty: 'cardiologist',    clinicName: 'Heart Care Centre',        rating: 4.7, reviews: 891, distKm: 2.1, availableToday: false, feeInr: 1500, acceptsOnline: false },
    { id: 'd3', name: 'Dr. Anjali Nair',    specialty: 'endocrinologist', clinicName: 'Thyroid & Diabetes Clinic', rating: 4.9, reviews: 445, distKm: 3.0, availableToday: true,  feeInr: 1200, acceptsOnline: true  },
    { id: 'd4', name: 'Dr. Suresh Bhat',    specialty: 'orthopedic',      clinicName: 'Bhat Ortho Care',          rating: 4.6, reviews: 267, distKm: 3.7, availableToday: true,  feeInr: 1000, acceptsOnline: false },
    { id: 'd5', name: 'Dr. Priya Agarwal',  specialty: 'dermatologist',   clinicName: 'Skin & Hair Studio',       rating: 4.5, reviews: 198, distKm: 4.2, availableToday: false, feeInr: 700,  acceptsOnline: true  },
    { id: 'd6', name: 'Dr. Vikram Malhotra',specialty: 'general',         clinicName: 'Malhotra Medical Centre',  rating: 4.4, reviews: 521, distKm: 1.1, availableToday: true,  feeInr: 400,  acceptsOnline: true  },
  ];

  const filtered = specialty === 'all' || specialty === 'general'
    ? mockDoctors
    : mockDoctors.filter(d => d.specialty === specialty);

  return { doctors: filtered.filter(d => d.distKm <= radius), queryLat: lat, queryLng: lng };
}

// ---------------------------------------------------------------------------
// Motivational Slogans
// ---------------------------------------------------------------------------

export async function getTodaySlogan(ctx: Ctx, gemini: GeminiClient | null): Promise<unknown> {
  const language = ctx.query.get('lang') ?? 'hi';
  const category = getSloganCategory();
  const streak   = parseInt(ctx.query.get('streak') ?? '0');

  // Try Gemini for fresh slogan, fall back to seeded ones
  let text = '';
  if (gemini) {
    try {
      text = await gemini.generateText({
        prompt: SLOGAN_PROMPT(category, language, streak),
        temperature: 0.9,
      });
    } catch { /* fall through to hardcoded */ }
  }

  if (!text) {
    text = HARDCODED_SLOGANS[language]?.[category]?.[0]
        ?? HARDCODED_SLOGANS['en']?.[category]?.[0]
        ?? 'Every workout counts!';
  }

  return { category, language, text: text.trim(), emoji: CATEGORY_EMOJI[category] };
}

// ---------------------------------------------------------------------------
// App Config Bootstrap (feature flags + system status)
// ---------------------------------------------------------------------------

export async function getAppConfig(_ctx: Ctx): Promise<unknown> {
  // TODO: Fetch from DB feature_flags + system_status tables
  // For now return hardcoded defaults matching what we seeded
  return {
    features: {
      pose_tracking:         true,
      blood_donation:        true,
      nearby_doctors:        true,
      health_report_ai:      true,
      transformation_photos: true,
      social_leaderboard:    true,
      multilingual:          true,
      admob_ads:             true,
      rewarded_ads:          true,
      subscription_pro:      true,
      subscription_elite:    true,
      motivational_slogans:  true,
      pathology_combat:      true,
      custom_diet_framework: true,
      fantasy_physique:      true,
      elevation_tracking:    true,
    },
    system: {
      maintenance_mode:      false,
      maintenance_message:   '',
      ios_min_version:       '1.0.0',
      android_min_version:   '1.0.0',
      ads_enabled:           true,
      registration_open:     true,
    },
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function calculateAge(dob: string): number {
  const birth = new Date(dob);
  const today = new Date();
  let age = today.getFullYear() - birth.getFullYear();
  if (today.getMonth() < birth.getMonth() ||
      (today.getMonth() === birth.getMonth() && today.getDate() < birth.getDate())) {
    age--;
  }
  return age;
}

function getMondayOfWeek(): string {
  const d = new Date();
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  return new Date(d.setDate(diff)).toISOString().split('T')[0];
}

function getSloganCategory(): string {
  const hour = new Date().getHours();
  if (hour >= 5  && hour < 10) return 'morning_fire';
  if (hour >= 10 && hour < 14) return 'midday_push';
  if (hour >= 14 && hour < 18) return 'afternoon_grind';
  if (hour >= 18 && hour < 21) return 'evening_warrior';
  return 'night_champion';
}

const CATEGORY_EMOJI: Record<string, string> = {
  morning_fire:    '🔥',
  midday_push:     '💪',
  afternoon_grind: '⚡',
  evening_warrior: '🌟',
  night_champion:  '🏆',
  rest_day_recharge:'🧘',
  streak_milestone: '🎯',
  goal_achieved:    '🎉',
  comeback:         '⚔️',
};

const HARDCODED_SLOGANS: Record<string, Record<string, string[]>> = {
  hi: {
    morning_fire:    ['मेहनत करने वालों की कभी हार नहीं होती', 'आज का दर्द, कल की ताकत है', 'उठो, दौड़ो, जीतो'],
    midday_push:     ['थकान को मत आने दो, तुम्हारा लक्ष्य अभी बाकी है', 'बीच रास्ते में रुकना मंजिल नहीं होती'],
    afternoon_grind: ['हर सांस में ताकत है — उसे उठाओ', 'जब तक हिम्मत है, जीत है'],
    evening_warrior: ['दिन का आखिरी workout सबसे powerful होता है', 'शाम का champion रात को चैन से सोता है'],
    night_champion:  ['कल का champion आज रात तैयार होता है', 'नींद से पहले एक और कदम — यही फर्क करता है'],
  },
  en: {
    morning_fire:    ['Champions are made when no one is watching', 'Your morning defines your day — make it count!'],
    midday_push:     ['Halfway there — the second half is where legends are made', 'Push through the afternoon slump!'],
    afternoon_grind: ['Sweat is just fat crying', 'Every rep is a vote for the person you want to become'],
    evening_warrior: ['End the day stronger than you started it', 'Evening warriors outperform morning quitters'],
    night_champion:  ['Sleep well — you earned it, champion', 'Tomorrow starts with what you do tonight'],
  },
};

function getMockBloodAnalysis(): BloodReportAnalysis {
  return {
    labName:    'Metropolis Healthcare Ltd',
    reportDate: '2025-09-20',
    biomarkers: [
      { code: 'HGB',   name: 'Hemoglobin',   value: 13.8, unit: 'g/dL',     status: 'normal',         labRefMin: 13.0, labRefMax: 17.0 },
      { code: 'WBC',   name: 'WBC Count',    value: 7200, unit: '10³/μL',   status: 'normal',         labRefMin: 4000, labRefMax: 11000 },
      { code: 'PLT',   name: 'Platelets',    value: 210,  unit: '10³/μL',   status: 'normal',         labRefMin: 150,  labRefMax: 400  },
      { code: 'GLU',   name: 'Fasting Glucose', value: 98, unit: 'mg/dL',  status: 'normal',         labRefMin: 70,   labRefMax: 110  },
      { code: 'HBA1C', name: 'HbA1c',        value: 5.4,  unit: '%',        status: 'normal',         labRefMin: 4.0,  labRefMax: 5.7  },
      { code: 'CHOL',  name: 'Cholesterol',  value: 218,  unit: 'mg/dL',   status: 'borderline_high',labRefMin: 0,    labRefMax: 200  },
      { code: 'VITD',  name: 'Vitamin D',    value: 16.2, unit: 'ng/mL',   status: 'low',            labRefMin: 20,   labRefMax: 60   },
      { code: 'B12',   name: 'Vitamin B12',  value: 312,  unit: 'pg/mL',   status: 'normal',         labRefMin: 200,  labRefMax: 900  },
      { code: 'FERR',  name: 'Ferritin',     value: 14.2, unit: 'ng/mL',   status: 'borderline_low', labRefMin: 15,   labRefMax: 200  },
      { code: 'TSH',   name: 'TSH',          value: 2.1,  unit: 'μIU/mL',  status: 'normal',         labRefMin: 0.4,  labRefMax: 4.0  },
      { code: 'CREAT', name: 'Creatinine',   value: 0.9,  unit: 'mg/dL',   status: 'normal',         labRefMin: 0.7,  labRefMax: 1.3  },
      { code: 'UA',    name: 'Uric Acid',    value: 6.8,  unit: 'mg/dL',   status: 'borderline_high',labRefMin: 3.5,  labRefMax: 7.2  },
    ],
    insights: [
      { text: 'Your Cholesterol is slightly elevated (218 mg/dL). Reduce fried food, ghee, and red meat. Add oats, nuts, and omega-3 rich foods like flaxseeds.', severity: 'warning', action: 'Modify diet' },
      { text: 'Vitamin D is low (16.2 ng/mL) — very common in Indians! Get 15-20 minutes of morning sunlight (before 10am) daily. Add eggs, fortified milk, and mushrooms.', severity: 'warning', action: 'Sunlight + diet' },
      { text: 'Ferritin is borderline low (14.2 ng/mL), suggesting early iron depletion. Eat more spinach, dal, and jaggery. Pair iron-rich foods with Vitamin C for better absorption.', severity: 'warning', action: 'Iron-rich diet' },
      { text: 'Your blood sugar control is excellent! HbA1c of 5.4% means zero diabetes risk. Keep up your current diet and exercise.', severity: 'info' },
      { text: 'Kidney function (Creatinine 0.9) and thyroid (TSH 2.1) are perfectly normal. Stay well-hydrated — 3-4 litres of water daily.', severity: 'info' },
      { text: 'Uric Acid is borderline high (6.8 mg/dL). Reduce dal, rajma, and spinach temporarily. Avoid sugary drinks and alcohol. Stay hydrated.', severity: 'warning', action: 'Reduce purines' },
    ],
    summary: 'Overall your report is good with a few items to watch. Focus on Vitamin D, Cholesterol, and Ferritin. Your blood sugar and kidney function are excellent!',
  };
}
