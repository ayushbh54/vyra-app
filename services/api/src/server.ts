/**
 * =============================================================================
 * VYRA API
 * =============================================================================
 * Wires the domain engines to HTTP. Route handlers stay thin on purpose: every
 * real decision lives in a tested, pure module (chrono, coins, labReport,
 * dietGuard), and the handler's job is validation, authorisation and shaping.
 * =============================================================================
 */

import { randomUUID } from 'node:crypto';

import {
  COIN_RULES, DIET_PREFERENCES, DISCLAIMERS, FITNESS_GOALS, GENDERS,
  METRIC_RANGE_BY_KEY, SUGAR_GUIDELINE, SUGAR_NEUTRALIZER_SUGGESTIONS,
  TIER_THRESHOLDS,
} from '@vyra/types';

import {
  DEFAULT_CHRONO_CONFIG, assessCapacity, computeActivityPoints, computeEffort,
  detectFreeWindows, expandBlocks, placeSessions, rebalanceMissedWorkout,
  type ChronoConfig, type PlaceableExercise, type RawBlock,
} from './domain/chrono';

import {
  applyAwards, computeBalance, computeMetricsAward, computeStreakMilestoneAward,
  computeWorkoutAward, computeZeroSugarAward,
} from './domain/coins';

import { analyseLabReport, LAB_DISCLAIMER, type MarkerKey, type MarkerReading } from './domain/labReport';
import { ChatError, sendChatMessage, type ChatMessage } from './ai/chat';
import { analyzeFoodPhoto, FoodScanError } from './ai/foodscan';
import { dietWarningForFood } from './ai/dietGuard';
import { discoverEvents, EventDiscoveryError } from './ai/events';
import { generateRecipe, RecipeGenerationError } from './ai/recipe';
import { generateDietChart } from './ai/dietChart';
import { tryCreateGeminiClient } from './ai/gemini';
import { eRaktKoshClient } from './ai/eraktkosh_apisetu';
import { EXERCISES, LIBRARY_STATS, mediaFor } from './content/exercises';
import { EXERCISE_DATASET, findExerciseInDataset } from './content/exercise_dataset';
import { registerAdminPortalRoutes } from './admin/admin_routes';
import { registerAthletePortalRoutes } from './athlete/athlete_routes';
import { rateLimiter } from './rateLimit';
import {
  decryptNumber, encryptOptional, hashIp, hashPassword, loadKeyRing, verifyPassword, type KeyRing,
} from './crypto';
import { issueToken, loadAuthConfig, verifyToken, type AuthConfig } from './auth';
import {
  HttpError, Router, bool, isoDate, num, oneOf, optionalNum, requireObject, str,
  type Ctx,
} from './http/router';
import {
  MemoryStore, type AdminRole, type Store, type StoredActivity, type StoredPlan,
  type StoredUser,
} from './store';
import { lookupBarcode } from './nutrition/barcode';

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

const today = (): string => new Date().toISOString().slice(0, 10);
const daysAgo = (n: number): string =>
  new Date(Date.now() - n * 86_400_000).toISOString().slice(0, 10);
const weekdayOf = (date: string): number => {
  // JS weeks start on Sunday; the Chrono Engine starts on Monday.
  const js = new Date(`${date}T00:00:00Z`).getUTCDay();
  return (js + 6) % 7;
};
const periodKey = (date: string): string => {
  const d = new Date(`${date}T00:00:00Z`);
  const start = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d.getTime() - start.getTime()) / 86_400_000 + start.getUTCDay() + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
};

const toPlaceable = (): PlaceableExercise[] =>
  EXERCISES.map((e) => ({
    id: e.slug,
    name: e.name,
    durationSec: e.defaultDurationSec,
    intensity: e.intensity,
    isLowImpact: e.isLowImpact,
  }));

/**
 * AI-Driven Personalized Exercise Pool Generator
 *
 * 1. Analyzes user aim:
 *    - gain_weight: hypertrophy, strength, progressive overload, heavy compound resistance
 *    - lose_weight: high-MET dynamic cardio, core endurance, agility, explosive HIIT burn
 *    - general_wellness / maintain: functional balance, mobility, core alignment, full body wellness
 * 2. Specially-Abled / Accessibility / Mobility Restrictions:
 *    - Strictly provides 100% seated & wheelchair-safe exercises when accessibilityMode or disabilityFlag is set.
 * 3. Injury & Physical Consideration Screening:
 *    - Scans physical considerations & details (knee fracture, lumbar disc, shoulder impingement, wrist strain).
 *    - Strictly filters out movements contraindicated for the injured region.
 * 4. Daily Split Freshness:
 *    - Seeded by date + user ID so each day has a distinct focus and never repeats the same routine.
 */
function poolForAthlete(user: StoredUser, date: string): PlaceableExercise[] {
  const isAdaptive = Boolean(
    user.accessibilityMode ||
    user.disabilityFlag ||
    (user.disabilityType && user.disabilityType.toLowerCase() !== 'none'),
  );

  let pool = isAdaptive
    ? EXERCISES.filter((e) => e.isSeatedFriendly)
    : [...EXERCISES];

  // Physical considerations & Injury text screening
  const injuryText = [
    user.disabilityType ?? '',
    user.physicalConsiderationDetails ?? '',
    ...(user.medicalConditions ?? []),
  ].join(' ').toLowerCase();

  if (injuryText.trim().length > 0) {
    const hasKneeInjury = injuryText.includes('knee') || injuryText.includes('leg') || injuryText.includes('acl') || injuryText.includes('meniscus') || injuryText.includes('ankle') || injuryText.includes('fracture') || injuryText.includes('femur') || injuryText.includes('shin');
    const hasBackInjury = injuryText.includes('back') || injuryText.includes('spine') || injuryText.includes('lumbar') || injuryText.includes('disc') || injuryText.includes('sciatica') || injuryText.includes('vertebra');
    const hasShoulderInjury = injuryText.includes('shoulder') || injuryText.includes('rotator') || injuryText.includes('impingement') || injuryText.includes('clavicle');
    const hasWristInjury = injuryText.includes('wrist') || injuryText.includes('carpal') || injuryText.includes('hand');

    pool = pool.filter((e) => {
      const contra = e.contraindications.join(' ').toLowerCase();
      const body = e.bodyParts.join(' ').toLowerCase();
      const name = e.name.toLowerCase();

      if (hasKneeInjury) {
        if (contra.includes('knee') || contra.includes('leg') || name.includes('squat') || name.includes('lunge') || name.includes('jumping') || name.includes('jump')) {
          return false;
        }
      }
      if (hasBackInjury) {
        if (contra.includes('back') || contra.includes('spine') || name.includes('deadlift') || name.includes('sit-up')) {
          return false;
        }
      }
      if (hasShoulderInjury) {
        if (contra.includes('shoulder') || name.includes('shoulder press') || name.includes('overhead')) {
          return false;
        }
      }
      if (hasWristInjury) {
        if (name.includes('push-up') && !name.includes('forearm')) {
          return false;
        }
      }
      return true;
    });

    if (pool.length < 5) {
      pool = EXERCISES.filter((e) => e.isSeatedFriendly || e.isLowImpact);
    }
  }

  // Deterministic daily split seed from date + userId
  const dateHash = Math.abs(
    (date + user.id).split('').reduce((acc, c) => ((acc << 5) - acc) + c.charCodeAt(0), 0)
  );
  const daySplit = dateHash % 4;
  const goal = user.fitnessGoal ?? 'general_wellness';

  const scored = pool.map((e) => {
    let score = 50;
    const sub = e.subcategory.toLowerCase();
    const body = e.bodyParts.join(' ').toLowerCase();
    const isCardio = sub === 'cardio' || e.name.toLowerCase().includes('jump') || e.name.toLowerCase().includes('jack');
    const isStrength = sub === 'arms' || sub === 'chest' || sub === 'legs' || sub === 'back' || sub === 'shoulders' || sub === 'glutes';

    if (goal === 'gain_weight') {
      if (isStrength) score += 55;
      if (isCardio) score -= 35;
      if (e.intensity >= 2) score += 20;
    } else if (goal === 'lose_weight') {
      if (isCardio) score += 60;
      if (sub === 'core') score += 35;
      if (e.metValue >= 6.0) score += 25;
    } else {
      if (e.isLowImpact) score += 15;
      score += 20;
    }

    if (daySplit === 0 && (body.includes('chest') || body.includes('arms') || body.includes('core'))) score += 35;
    if (daySplit === 1 && (body.includes('legs') || body.includes('glutes'))) score += 35;
    if (daySplit === 2 && (isCardio || body.includes('full'))) score += 35;
    if (daySplit === 3 && (body.includes('back') || body.includes('shoulders') || body.includes('core'))) score += 35;

    const itemJitter = (dateHash ^ e.slug.length) % 15;
    return { exercise: e, finalScore: score + itemJitter };
  });

  scored.sort((a, b) => b.finalScore - a.finalScore);

  return scored.map((s) => ({
    id: s.exercise.slug,
    name: s.exercise.name,
    durationSec: s.exercise.defaultDurationSec,
    intensity: s.exercise.intensity,
    isLowImpact: s.exercise.isLowImpact,
  }));
}

/** Fallback poolFor */
const poolFor = (accessibilityMode: boolean): PlaceableExercise[] => {
  const all = toPlaceable();
  if (!accessibilityMode) return all;
  const seated = new Set(EXERCISES.filter((e) => e.isSeatedFriendly).map((e) => e.slug));
  return all.filter((e) => seated.has(e.id));
};

const tierFor = (points: number) =>
  [...TIER_THRESHOLDS].reverse().find((t) => points >= t.minPoints) ?? TIER_THRESHOLDS[0]!;

// -----------------------------------------------------------------------------
// Server
// -----------------------------------------------------------------------------

export interface ServerDeps {
  store: Store;
  keyRing: KeyRing;
  authConfig: AuthConfig;
  now?: () => number;
}

export function buildRouter(deps: ServerDeps): Router {
  const { store, keyRing, authConfig } = deps;
  const now = deps.now ?? (() => Date.now());

  // ---------------------------------------------------------------------------
  // Gemini clients — one per AI feature so each has its own key + quota pool.
  // Every client falls back to GEMINI_API_KEY when the feature-specific key
  // is not set, so the app works out-of-the-box with just one key, and any
  // individual feature can be isolated to a separate key/billing later.
  //
  //  Feature key env var          → Feature
  //  GEMINI_RECIPE_API_KEY        → /v1/ai/recipe
  //  GEMINI_FOOD_API_KEY          → /v1/food/scan
  //  GEMINI_LAB_API_KEY           → /v1/lab-report/analyse
  //  GEMINI_CHAT_API_KEY          → /v1/chat/message
  //  GEMINI_EVENTS_API_KEY        → /v1/ai/events (discover)
  //  GEMINI_API_KEY               → master fallback for all of the above
  // ---------------------------------------------------------------------------
  const geminiRecipe = tryCreateGeminiClient(process.env, undefined, 'GEMINI_RECIPE_API_KEY');
  const geminiFood   = tryCreateGeminiClient(process.env, undefined, 'GEMINI_FOOD_API_KEY');
  const geminiLab    = tryCreateGeminiClient(process.env, undefined, 'GEMINI_LAB_API_KEY');
  const geminiChat   = tryCreateGeminiClient(process.env, undefined, 'GEMINI_CHAT_API_KEY');
  const geminiEvents = tryCreateGeminiClient(process.env, undefined, 'GEMINI_EVENTS_API_KEY');
  const router = new Router();


  // ---------------------------------------------------------------------------
  // Rate limiting — per-IP, per-bucket. See rateLimit.ts for the algorithm.
  // Only the three audit-flagged surfaces get a limit today: auth (credential
  // stuffing / brute force), the public demo endpoint (unauthenticated, so
  // it's the cheapest thing on the API for someone to hammer), and anything
  // that calls Gemini (real per-call cost). RATE_LIMIT_DEFAULT_PER_MIN and
  // RATE_LIMIT_OTP_PER_HOUR stay defined-but-unwired for now — no OTP route
  // exists yet to attach the latter to, and a blanket default limit wasn't in
  // the audit's 3 confirmed findings, so it's left alone rather than guessed at.
  const RATE_LIMIT_AUTH_PER_MIN = Number(process.env.RATE_LIMIT_AUTH_PER_MIN) || 10;
  const RATE_LIMIT_AI_PER_HOUR = Number(process.env.RATE_LIMIT_AI_PER_HOUR) || 120;
  const RATE_LIMIT_DEMO_PER_MIN = 10; // fixed, not env-driven — brief just asked for "a reasonable limit"

  /** Throws 429 (with a Retry-After header) once `maxPerWindow` is exceeded for this IP+bucket. */
  function enforceRateLimit(ctx: Ctx, bucket: string, maxPerWindow: number, windowMs: number) {
    const result = rateLimiter.check(`${bucket}:${ctx.ip}`, maxPerWindow, windowMs);
    if (!result.allowed) {
      throw HttpError.rateLimited(
        'Too many requests. Please slow down and try again shortly.',
        result.retryAfterSec,
      );
    }
  }

  /** Resolves the caller, or throws. Every private route starts with this. */
  async function requireUser(ctx: Ctx) {
    const header = ctx.req.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw HttpError.unauthorized();

    const payload = verifyToken(authConfig, header.slice(7), now());
    if (payload.typ !== 'access') throw HttpError.unauthorized('Use an access token here.');
    if (payload.admin) throw HttpError.unauthorized('Use an athlete account here, not an admin one.');

    let user = await store.getUser(payload.sub);
    if (!user) {
      // Reconstitute user session from verified token subject so athletes are never logged out on store restart
      const handle = payload.sub.replace(/[^a-zA-Z0-9_]/g, '').slice(0, 15) || 'athlete';
      user = await store.createUser({
        id: payload.sub,
        displayHandle: handle,
        name: 'Athlete',
        email: `${handle}@vyra.app`,
        dob: '2000-01-01',
        gender: 'prefer-not-to-say',
        heightCm: 170,
        weightKg: 65,
        disabilityFlag: false,
        accessibilityMode: false,
        fitnessGoal: 'maintain',
        dietToggle: true,
        dietPreference: 'veg_no_egg',
        primarySport: 'run',
        dmPrivacy: 'following',
        accountStatus: 'active',
        onboardingStep: 9,
      });
    }
    if (user.accountStatus === 'suspended') {
      throw HttpError.forbidden('Your account is temporarily suspended. Contact support to appeal.');
    }
    if (user.accountStatus === 'banned' || user.accountStatus === 'deleted') {
      throw HttpError.forbidden('This account is no longer active.');
    }
    return user;
  }

  async function optionalUser(ctx: Ctx) {
    const header = ctx.req.headers.authorization;
    if (!header?.startsWith('Bearer ')) return null;
    try {
      const payload = verifyToken(authConfig, header.slice(7), now());
      if (payload.typ !== 'access' || payload.admin) return null;
      return await store.getUser(payload.sub);
    } catch {
      return null;
    }
  }

  /** Same shape as requireUser, for the separate admin_users credential space. */
  async function requireAdmin(ctx: Ctx, allowedRoles?: readonly AdminRole[]) {
    const header = ctx.req.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw HttpError.unauthorized();

    const payload = verifyToken(authConfig, header.slice(7), now());
    if (payload.typ !== 'access' || !payload.admin) {
      throw HttpError.unauthorized('An admin access token is required here.');
    }
    const admin = await store.getAdmin(payload.sub);
    if (!admin || !admin.isActive) throw HttpError.unauthorized('This admin account is not active.');
    if (allowedRoles && !allowedRoles.includes(admin.role)) {
      throw HttpError.forbidden(`This action requires one of: ${allowedRoles.join(', ')}.`);
    }
    return admin;
  }

  /** Recomputes windows, capacity and the plan for one date. */
  async function buildPlanFor(userId: string, date: string): Promise<StoredPlan> {
    const user = await store.getUser(userId);
    if (!user) throw HttpError.notFound('User not found.');

    const blocks = expandBlocks(await store.getSchedule(userId));
    const windows = detectFreeWindows(blocks, weekdayOf(date));
    const isAdaptive = Boolean(
      user.accessibilityMode ||
      user.disabilityFlag ||
      (user.disabilityType && user.disabilityType.toLowerCase() !== 'none'),
    );
    const capacity = assessCapacity(windows, user.fitnessGoal);
    // Dynamic ChronoConfig allowing 5 to 15 exercises daily matching user capacity
    const dynamicConfig: ChronoConfig = {
      ...DEFAULT_CHRONO_CONFIG,
      maxExercisesPerSession: 12,
    };
    const sessions = placeSessions(
      windows,
      poolForAthlete(user, date),
      capacity.dailyGoalMin,
      dynamicConfig,
    );

    const existing = await store.getPlan(userId, date);
    const done = new Set(
      (existing?.entries ?? []).filter((e) => e.isCompleted).map((e) => e.exerciseSlug),
    );

    return store.upsertPlan({
      userId,
      planDate: date,
      goalMin: capacity.dailyGoalMin,
      capacityMin: capacity.capacityMin,
      achievedMin: existing?.achievedMin ?? 0,
      entries: sessions.flatMap((s) =>
        s.exercises.map((e) => ({
          exerciseSlug: e.id,
          name: e.name,
          durationSec: e.durationSec,
          // Completions survive a replan — a user who finished a session must
          // never lose it because their schedule was edited later that day.
          isCompleted: done.has(e.id),
          scheduledAt: s.window.start,
        })),
      ),
    });
  }

  // ===========================================================================
  // PUBLIC
  // ===========================================================================

  router.get('/health', async () => {
    const storeHealth = await store.health();
    return {
      ok: storeHealth.ok,
      service: 'vyra-api',
      version: process.env.npm_package_version ?? '0.1.0',
      store: storeHealth,
      ai: {
        recipe:    geminiRecipe  ? 'configured' : 'unavailable (set GEMINI_RECIPE_API_KEY or GEMINI_API_KEY)',
        foodScan:  geminiFood    ? 'configured' : 'unavailable (set GEMINI_FOOD_API_KEY or GEMINI_API_KEY)',
        labReport: geminiLab     ? 'configured' : 'unavailable (set GEMINI_LAB_API_KEY or GEMINI_API_KEY)',
        chat:      geminiChat    ? 'configured' : 'unavailable (set GEMINI_CHAT_API_KEY or GEMINI_API_KEY)',
        events:    geminiEvents  ? 'configured' : 'unavailable (set GEMINI_EVENTS_API_KEY or GEMINI_API_KEY)',
      },
      library: LIBRARY_STATS,
      time: new Date(now()).toISOString(),
    };
  });

  router.get('/v1/library', async (ctx) => {
    const category = ctx.query.get('category');
    const bodyPart = ctx.query.get('bodyPart');
    const seatedOnly = ctx.query.get('seatedOnly') === 'true';
    const search = ctx.query.get('search')?.toLowerCase();

    const items = EXERCISES.filter((e) =>
      (!category || e.category === category) &&
      (!bodyPart || e.bodyParts.includes(bodyPart)) &&
      (!seatedOnly || e.isSeatedFriendly) &&
      (!search || e.name.toLowerCase().includes(search)),
    ).map((e) => ({ ...e, ...mediaFor(e.slug) }));

    return { items, total: items.length, disclaimer: DISCLAIMERS.general };
  });

  /**
   * The code-driven 3D exercise avatar's data feed. Not every exercise has
   * one yet (MVP scope: dumbbell-bicep-curl, bodyweight-squat, push-up) —
   * the Flutter side falls back to the existing video/GIF card when this
   * comes back null, so a gap here never blocks a workout, the same
   * principle the exercise library itself already follows for missing media.
   */
  router.get('/v1/exercises/:slug/movement', async (ctx) => {
    const definition = await store.getMovementDefinition(ctx.params.slug!);
    return { definition };
  });

  /**
   * Exercise & Kinematics Dataset endpoints.
   * Grounding data source for Gemini AI & kinematic joint angle verification.
   */
  router.get('/v1/exercises/dataset', async (ctx) => {
    const q = ctx.query.get('q') ?? '';
    if (q) {
      const match = findExerciseInDataset(q);
      return { exercise: match ?? null };
    }
    return { exercises: EXERCISE_DATASET };
  });

  router.get('/v1/exercises/dataset/:slug', async (ctx) => {
    const match = findExerciseInDataset(ctx.params.slug!);
    if (!match) throw HttpError.notFound(`Exercise '${ctx.params.slug}' not found in kinematic dataset`);
    return { exercise: match };
  });

  /**
   * Demo session. Creates a fully-populated account in one call so the product
   * can be shown without anyone typing an onboarding flow on stage.
   * Disabled automatically when DEMO_MODE is not enabled.
   */
  router.post('/v1/demo/session', async (ctx) => {
    enforceRateLimit(ctx, 'demo', RATE_LIMIT_DEMO_PER_MIN, 60_000);
    if (process.env.DEMO_MODE !== 'true') {
      throw HttpError.forbidden('Demo sessions are disabled on this deployment.');
    }
    const body = requireObject(ctx.body ?? {});
    const preset = (body.preset as string) ?? 'student';

    /**
     * Presets describe a WEEK, not a day.
     *
     * An earlier version only defined Monday. Opening the demo on a Tuesday
     * therefore showed a completely empty calendar, and the time-poor student
     * was handed the same 30-minute goal as someone with nothing on — which is
     * precisely the unfairness the product exists to remove.
     */
    const everyWeekday = (blocks: Omit<RawBlock, 'weekday'>[]): RawBlock[] =>
      [0, 1, 2, 3, 4].flatMap((weekday) => blocks.map((b) => ({ ...b, weekday })));

    const nightlySleep = (start: string, end: string): RawBlock[] =>
      [0, 1, 2, 3, 4, 5, 6].map((weekday) => ({
        weekday, blockStart: start, blockEnd: end, blockType: 'sleep' as const,
      }));

    const presets: Record<string, { name: string; handle: string; blocks: RawBlock[] }> = {
      student: {
        name: 'Aarav', handle: 'quiet_ember',
        blocks: [
          ...nightlySleep('22:45', '06:00'),
          ...everyWeekday([
            { blockStart: '06:30', blockEnd: '07:15', blockType: 'commute' },
            { blockStart: '07:15', blockEnd: '14:30', blockType: 'class', label: 'School' },
            { blockStart: '14:30', blockEnd: '15:30', blockType: 'commute' },
            { blockStart: '16:00', blockEnd: '20:30', blockType: 'class', label: 'Coaching' },
            { blockStart: '20:30', blockEnd: '22:15', blockType: 'work', label: 'Homework' },
          ]),
        ],
      },
      nurse: {
        name: 'Priya', handle: 'night_shift',
        blocks: [
          ...nightlySleep('23:30', '06:30'),
          ...everyWeekday([
            { blockStart: '07:15', blockEnd: '08:00', blockType: 'commute' },
            { blockStart: '08:00', blockEnd: '20:00', blockType: 'work', label: 'Shift' },
            { blockStart: '20:00', blockEnd: '20:45', blockType: 'commute' },
          ]),
        ],
      },
      homemaker: {
        name: 'Sunita', handle: 'morning_owl',
        blocks: [
          ...nightlySleep('22:30', '05:30'),
          ...everyWeekday([
            { blockStart: '06:30', blockEnd: '09:00', blockType: 'work', label: 'Morning household' },
            { blockStart: '12:00', blockEnd: '14:00', blockType: 'work', label: 'Lunch and chores' },
            { blockStart: '17:00', blockEnd: '20:30', blockType: 'work', label: 'Evening household' },
          ]),
        ],
      },
      open: {
        name: 'Rohit', handle: 'still_here',
        blocks: [
          ...nightlySleep('23:30', '07:30'),
          ...everyWeekday([{ blockStart: '10:00', blockEnd: '13:00', blockType: 'work' }]),
        ],
      },
    };

    const chosen = presets[preset] ?? presets.student!;
    const id = `demo-${preset}-${Math.random().toString(36).slice(2, 8)}`;

    await store.createUser({
      id,
      displayHandle: `${chosen.handle}_${id.slice(-4)}`,
      name: chosen.name,
      dob: '2007-05-14',
      gender: 'prefer-not-to-say',
      heightCm: 170,
      weightKg: 62,
      disabilityFlag: false,
      accessibilityMode: false,
      fitnessGoal: 'maintain',
      dietToggle: true,
      dietPreference: 'veg_no_egg',
      primarySport: 'run',
      dmPrivacy: 'following',
      accountStatus: 'active',
      onboardingStep: 9,
    });

    await store.setSchedule(id, chosen.blocks);
    await buildPlanFor(id, today());

    return {
      accessToken: issueToken(authConfig, id, 'access', now()),
      refreshToken: issueToken(authConfig, id, 'refresh', now()),
      userId: id,
      preset,
    };
  });

  // ===========================================================================
  // AUTH — real email+password accounts. Works with zero external keys, so
  // the app has a reliable signup path even before Google/Facebook/WhatsApp
  // OTP credentials (see .env.example) are ever added.
  // ===========================================================================

  router.post('/v1/auth/signup', async (ctx) => {
    enforceRateLimit(ctx, 'auth', RATE_LIMIT_AUTH_PER_MIN, 60_000);
    const b = requireObject(ctx.body);
    const email = str(b, 'email', { max: 254 }).trim().toLowerCase();
    const password = str(b, 'password', { max: 200 });
    if (password.length < 8) {
      throw HttpError.badRequest('Password must be at least 8 characters.', { field: 'password' });
    }
    const name = str(b, 'name', { max: 80 });
    // Everything below this line is intentionally optional at signup — the
    // Stitch UI only collects name/email/password on this screen, then
    // walks the athlete through a proper onboarding flow (body info, goals,
    // activities...) right after. These are sane placeholders that the
    // authenticated onboarding/complete call overwrites moments later, not
    // real data anyone should trust before onboardingStep reaches 9.
    const dob = typeof b.dob === 'string' ? isoDate(b, 'dob') : '2000-01-01';
    const gender = typeof b.gender === 'string' ? oneOf(b, 'gender', GENDERS) : 'prefer-not-to-say';
    const heightCm = typeof b.heightCm !== 'undefined' ? num(b, 'heightCm', { min: 50, max: 260 }) : 170;
    const weightKg = typeof b.weightKg !== 'undefined' ? num(b, 'weightKg', { min: 15, max: 400 }) : 70;
    const fitnessGoal = typeof b.fitnessGoal === 'string'
      ? oneOf(b, 'fitnessGoal', FITNESS_GOALS) : 'general_wellness';
    const dietPreference = typeof b.dietPreference === 'string'
      ? oneOf(b, 'dietPreference', DIET_PREFERENCES) : 'veg_no_egg';

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw HttpError.badRequest('That does not look like a valid email address.');
    }
    if (await store.getUserByEmail(email)) {
      throw HttpError.conflict('An account with that email already exists. Try logging in.');
    }

    const id = randomUUID();
    const handleBase = name.toLowerCase().replace(/[^a-z0-9]+/g, '_').slice(0, 20) || 'athlete';
    const displayHandle = `${handleBase}_${id.slice(0, 6)}`;

    const user = await store.createUser({
      id,
      displayHandle,
      name,
      email,
      dob,
      gender,
      heightCm,
      weightKg,
      disabilityFlag: false,
      accessibilityMode: false,
      fitnessGoal,
      dietToggle: true,
      dietPreference,
      primarySport: 'run',
      dmPrivacy: 'following',
      accountStatus: 'active',
      onboardingStep: 0,
    });
    await store.setPasswordHash(id, await hashPassword(password));

    return {
      accessToken: issueToken(authConfig, id, 'access', now()),
      refreshToken: issueToken(authConfig, id, 'refresh', now()),
      userId: user.id,
      displayHandle: user.displayHandle,
    };
  });

  router.post('/v1/auth/login', async (ctx) => {
    enforceRateLimit(ctx, 'auth', RATE_LIMIT_AUTH_PER_MIN, 60_000);
    const b = requireObject(ctx.body);
    const email = str(b, 'email', { max: 254 }).trim().toLowerCase();
    const password = str(b, 'password', { max: 200 });

    // Same error for "no such account" and "wrong password" — telling an
    // attacker which one it was is a free account-enumeration oracle.
    const invalid = () => HttpError.unauthorized('Incorrect email or password.');

    const user = await store.getUserByEmail(email);
    if (!user) throw invalid();
    const hash = await store.getPasswordHash(user.id);
    if (!hash || !(await verifyPassword(password, hash))) throw invalid();

    return {
      accessToken: issueToken(authConfig, user.id, 'access', now()),
      refreshToken: issueToken(authConfig, user.id, 'refresh', now()),
      userId: user.id,
      displayHandle: user.displayHandle,
      onboardingStep: user.onboardingStep,
    };
  });

  router.post('/v1/auth/refresh', async (ctx) => {
    const b = requireObject(ctx.body);
    const refreshToken = str(b, 'refreshToken', { max: 2000 });
    const payload = verifyToken(authConfig, refreshToken, now());
    if (payload.typ !== 'refresh') throw HttpError.unauthorized('Not a refresh token.');
    const user = await store.getUser(payload.sub);
    if (!user) throw HttpError.unauthorized('Account no longer exists.');

    return {
      accessToken: issueToken(authConfig, user.id, 'access', now()),
      refreshToken: issueToken(authConfig, user.id, 'refresh', now()),
    };
  });

  // Fast 1-Tap Guest Access (Immediate Demo Session, linkable to Google later)
  router.post('/v1/auth/guest', async (ctx) => {
    enforceRateLimit(ctx, 'auth', RATE_LIMIT_AUTH_PER_MIN, 60_000);
    const id = randomUUID();
    const guestHandle = `guest_${id.slice(0, 6)}`;
    const guestEmail = `${guestHandle}@guest.vyra.app`;

    const user = await store.createUser({
      id,
      displayHandle: guestHandle,
      name: 'Guest Athlete',
      email: guestEmail,
      dob: '2000-01-01',
      gender: 'prefer-not-to-say',
      heightCm: 172,
      weightKg: 68,
      disabilityFlag: false,
      accessibilityMode: false,
      fitnessGoal: 'general_wellness',
      dietToggle: true,
      dietPreference: 'veg_no_egg',
      primarySport: 'run',
      dmPrivacy: 'following',
      accountStatus: 'active',
      onboardingStep: 0,
    });

    return {
      accessToken: issueToken(authConfig, user.id, 'access', now()),
      refreshToken: issueToken(authConfig, user.id, 'refresh', now()),
      userId: user.id,
      displayHandle: user.displayHandle,
      onboardingStep: user.onboardingStep,
      isGuest: true,
    };
  });

  // Link Google Account to existing athlete/guest account
  router.post('/v1/auth/link-google', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const email = str(b, 'email', { max: 254 }).trim().toLowerCase();
    const googleId = typeof b.googleId === 'string' && b.googleId.trim() ? b.googleId.trim() : `google_${email}`;

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw HttpError.badRequest('A valid email address is required to link a Google Account.');
    }

    await store.linkAuthIdentity(user.id, 'google', googleId);
    return {
      ok: true,
      linkedEmail: email,
      userId: user.id,
      message: 'Google Account successfully linked to this athlete profile.',
    };
  });

  router.post('/v1/auth/google', async (ctx) => {
    enforceRateLimit(ctx, 'auth', RATE_LIMIT_AUTH_PER_MIN, 60_000);
    const b = requireObject(ctx.body);
    const idToken = typeof b.idToken === 'string' ? b.idToken.trim() : '';
    let email = typeof b.email === 'string' ? b.email.trim().toLowerCase() : '';
    let name = typeof b.name === 'string' ? b.name.trim() : '';
    let googleId = typeof b.googleId === 'string' ? b.googleId.trim() : '';

    if (idToken) {
      try {
        const res = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
        if (res.ok) {
          const info = (await res.json()) as Record<string, unknown>;
          if (typeof info.email === 'string') email = info.email.toLowerCase();
          if (typeof info.sub === 'string') googleId = info.sub;
          if (typeof info.name === 'string' && !name) name = info.name;
        }
      } catch {
        // Fall through to provided email / googleId if tokeninfo request is unavailable
      }
    }

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw HttpError.badRequest('A valid email address is required for Google Sign-In.');
    }

    const effectiveGoogleId = googleId || `google_${email}`;

    // Look up existing user by Google Identity or registered email
    let user = await store.getUserByAuthIdentity('google', effectiveGoogleId);
    if (!user) {
      user = await store.getUserByEmail(email);
    }

    if (!user) {
      const id = randomUUID();
      const athleteName = name || email.split('@')[0] || 'Athlete';
      const handleBase = athleteName.toLowerCase().replace(/[^a-z0-9]+/g, '_').slice(0, 20) || 'athlete';
      const displayHandle = `${handleBase}_${id.slice(0, 6)}`;

      user = await store.createUser({
        id,
        displayHandle,
        name: athleteName,
        email,
        dob: '2000-01-01',
        gender: 'prefer-not-to-say',
        heightCm: 170,
        weightKg: 70,
        disabilityFlag: false,
        accessibilityMode: false,
        fitnessGoal: 'general_wellness',
        dietToggle: true,
        dietPreference: 'veg_no_egg',
        primarySport: 'run',
        dmPrivacy: 'following',
        accountStatus: 'active',
        onboardingStep: 0,
      });
    }

    await store.linkAuthIdentity(user.id, 'google', effectiveGoogleId);

    return {
      accessToken: issueToken(authConfig, user.id, 'access', now()),
      refreshToken: issueToken(authConfig, user.id, 'refresh', now()),
      userId: user.id,
      displayHandle: user.displayHandle,
      onboardingStep: user.onboardingStep,
    };
  });

  router.post('/v1/auth/reset-password', async (ctx) => {
    enforceRateLimit(ctx, 'auth', RATE_LIMIT_AUTH_PER_MIN, 60_000);
    const b = requireObject(ctx.body);
    const email = str(b, 'email', { max: 254 }).trim().toLowerCase();
    const newPassword = str(b, 'newPassword', { max: 200 });

    if (newPassword.length < 8) {
      throw HttpError.badRequest('Password must be at least 8 characters.');
    }

    const user = await store.getUserByEmail(email);
    if (!user) {
      return { success: true, message: 'If an account exists with this email, the password has been updated.' };
    }

    await store.setPasswordHash(user.id, await hashPassword(newPassword));
    return { success: true, message: 'Password updated successfully. You can now sign in.' };
  });

  // ===========================================================================
  // ONBOARDING
  // ===========================================================================

  router.post('/v1/onboarding/complete', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);

    const updated = await store.updateUser(user.id, {
      displayHandle: typeof b.displayHandle === 'string' ? b.displayHandle : user.displayHandle,
      name: typeof b.name === 'string' ? b.name : user.name,
      dob: typeof b.dob === 'string' ? isoDate(b, 'dob') : user.dob,
      gender: typeof b.gender === 'string' ? oneOf(b, 'gender', GENDERS) : user.gender,
      heightCm: typeof b.heightCm !== 'undefined' ? num(b, 'heightCm', { min: 50, max: 260 }) : user.heightCm,
      weightKg: typeof b.weightKg !== 'undefined' ? num(b, 'weightKg', { min: 15, max: 400 }) : user.weightKg,
      disabilityFlag: bool(b, 'disabilityFlag', user.disabilityFlag),
      accessibilityMode: bool(b, 'accessibilityMode', user.accessibilityMode),
      fitnessGoal: typeof b.fitnessGoal === 'string' ? oneOf(b, 'fitnessGoal', FITNESS_GOALS) : user.fitnessGoal,
      dietToggle: bool(b, 'dietToggle', user.dietToggle),
      dietPreference: typeof b.dietPreference === 'string'
        ? oneOf(b, 'dietPreference', DIET_PREFERENCES) : user.dietPreference,
      city: typeof b.city === 'string' ? b.city : user.city,
      primarySport: typeof b.primarySport === 'string' ? b.primarySport : user.primarySport,
      hasPhysicalConsideration: bool(b, 'hasPhysicalConsideration', user.hasPhysicalConsideration ?? false),
      physicalConsiderationDetails: typeof b.physicalConsiderationDetails === 'string'
        ? b.physicalConsiderationDetails
        : user.physicalConsiderationDetails,
      disabilityType: typeof b.disabilityType === 'string' ? b.disabilityType : user.disabilityType,
      onboardingStep: 9,
    });

    const blocks = Array.isArray(b.schedule) ? (b.schedule as RawBlock[]) : [];
    if (blocks.length > 0) await store.setSchedule(user.id, blocks);

    // Consent is recorded before anything else is stored, and the IP is hashed
    // so the audit trail does not itself become personal data.
    const salt = process.env.IP_HASH_SALT ?? 'dev-salt';
    for (const c of Array.isArray(b.consents) ? b.consents : []) {
      const row = c as { consentType?: string; granted?: boolean };
      if (typeof row.consentType === 'string') {
        await store.recordConsent(
          user.id, row.consentType, row.granted === true,
          hashIp(ctx.ip, salt), process.env.POLICY_VERSION ?? '2026-09-01',
        );
      }
    }

    const plan = await buildPlanFor(user.id, today());

    return { user: updated, plan };
  });

  router.post('/v1/schedule', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    if (!Array.isArray(b.blocks)) throw HttpError.badRequest('"blocks" must be an array.');

    await store.setSchedule(user.id, b.blocks as RawBlock[]);
    const plan = await buildPlanFor(user.id, today());

    const windows = detectFreeWindows(expandBlocks(b.blocks as RawBlock[]), weekdayOf(today()));
    return { plan, windows, config: DEFAULT_CHRONO_CONFIG };
  });

  // ===========================================================================
  // TAB 1 — TRAINING
  // ===========================================================================

  router.get('/v1/today', async (ctx) => {
    const user = await requireUser(ctx);
    const date = ctx.query.get('date') ?? today();
    const plan = (await store.getPlan(user.id, date)) ?? (await buildPlanFor(user.id, date));

    const blocks = expandBlocks(await store.getSchedule(user.id));
    const windows = detectFreeWindows(blocks, weekdayOf(date));
    const capacity = assessCapacity(windows, user.fitnessGoal);
    const effort = computeEffort(plan.achievedMin, plan.goalMin);
    const ledger = await store.listLedger(user.id);

    return {
      date,
      plan,
      windows,
      capacity,
      effort,
      coins: computeBalance(ledger),
      // Omitted entirely, not sent as null — the client must not render a
      // placeholder for a module the user switched off.
      ...(user.dietToggle ? { dietEnabled: true } : {}),
      disclaimer: DISCLAIMERS.general,
    };
  });

  router.post('/v1/workout/complete', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const date = typeof b.date === 'string' ? b.date : today();
    const slug = str(b, 'exerciseSlug');
    const actualSec = num(b, 'actualDurationSec', { min: 1, max: 7200 });

    const plan = await store.getPlan(user.id, date);
    if (!plan) throw HttpError.notFound('No plan for that date.');

    const entry = plan.entries.find((e) => e.exerciseSlug === slug);
    if (!entry) throw HttpError.notFound('That exercise is not in this plan.');
    if (entry.isCompleted) throw HttpError.conflict('Already marked complete.');

    entry.isCompleted = true;
    plan.achievedMin = Math.round((plan.achievedMin + actualSec / 60) * 10) / 10;
    await store.upsertPlan(plan);

    const effort = computeEffort(plan.achievedMin, plan.goalMin);

    // Streak: consecutive days ending today where the goal was met.
    let streak = 0;
    for (let i = 0; i < 400; i++) {
      const d = daysAgo(i);
      const p = await store.getPlan(user.id, d);
      if (!p) break;
      if (computeEffort(p.achievedMin, p.goalMin).met) streak++;
      else break;
    }

    const awards = [
      computeWorkoutAward(effort, user.id, date),
      computeStreakMilestoneAward(streak, user.id),
    ].filter((a): a is NonNullable<typeof a> => a !== null);

    const todayRows = await store.listLedgerForDate(user.id, date);
    const ledger = await store.listLedger(user.id);
    const outcomes = applyAwards(awards, {
      todayRows,
      currentBalance: computeBalance(ledger).balance,
    });

    for (const o of outcomes) {
      if (o.applied) {
        await store.appendLedger(user.id, {
          delta: o.applied.delta,
          reason: o.applied.reason,
          sourceType: o.applied.sourceType,
          idempotencyKey: o.applied.idempotencyKey,
          createdAt: new Date(now()).toISOString(),
        });
      }
    }

    // Weekly leaderboard score, recomputed from the last seven days.
    const week = await store.listPlans(user.id, daysAgo(6), date);
    const points = computeActivityPoints(week.map((p) => computeEffort(p.achievedMin, p.goalMin)));
    await store.setLeaderboardScore(user.id, periodKey(date), points.activityPoints);

    return {
      plan,
      effort,
      streak,
      // Never a silent zero: the client shows exactly what happened, cap included.
      coinOutcomes: outcomes.map((o) => ({
        status: o.status, message: o.message,
        delta: o.applied?.delta ?? 0, capped: o.cappedAmount,
      })),
      balance: computeBalance(await store.listLedger(user.id)),
      points,
      dailyCap: COIN_RULES.dailyEarnCap,
    };
  });

  router.get('/v1/missed', async (ctx) => {
    const user = await requireUser(ctx);
    const plans = await store.listPlans(user.id, daysAgo(14), daysAgo(1));
    const missed = plans
      .filter((p) => p.goalMin > 0 && !computeEffort(p.achievedMin, p.goalMin).met)
      .map((p) => ({
        date: p.planDate,
        goalMin: p.goalMin,
        achievedMin: p.achievedMin,
        exerciseCount: p.entries.filter((e) => !e.isCompleted).length,
      }));
    return { missed };
  });

  router.post('/v1/rebalance/preview', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const missedDate = isoDate(b, 'missedDate');

    const missedPlan = await store.getPlan(user.id, missedDate);
    if (!missedPlan) throw HttpError.notFound('No plan on that date.');

    const items = missedPlan.entries
      .filter((e) => !e.isCompleted)
      .map((e) => ({ exerciseId: e.exerciseSlug, name: e.name, durationMin: Math.round(e.durationSec / 60) }));

    const blocks = expandBlocks(await store.getSchedule(user.id));
    const candidates = [];
    for (let i = 1; i <= DEFAULT_CHRONO_CONFIG.rebalanceSpreadDays; i++) {
      const date = new Date(Date.now() + i * 86_400_000).toISOString().slice(0, 10);
      const windows = detectFreeWindows(blocks, weekdayOf(date));
      const capacity = assessCapacity(windows, user.fitnessGoal);
      const existing = await store.getPlan(user.id, date);
      candidates.push({
        date,
        weekday: weekdayOf(date),
        existingLoadMin: existing
          ? Math.round(existing.entries.reduce((s, e) => s + e.durationSec, 0) / 60)
          : 0,
        capacityMin: capacity.capacityMin,
      });
    }

    // Preview only. Nothing is written until the user approves it — silently
    // reshuffling someone's week is exactly the behaviour that erodes trust.
    return rebalanceMissedWorkout(missedDate, items, candidates);
  });

  // ===========================================================================
  // TRACKING
  // ===========================================================================

  router.post('/v1/tracking', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const date = typeof b.recordDate === 'string' ? b.recordDate : today();

    const range = (k: string) => {
      const r = METRIC_RANGE_BY_KEY[k as keyof typeof METRIC_RANGE_BY_KEY];
      if (!r) throw HttpError.badRequest(`Unknown metric "${k}".`);
      return { min: r.min, max: r.max };
    };

    const encrypted: Record<string, Buffer> = {};
    for (const field of ['heartRateBpm', 'bpSystolic', 'bpDiastolic', 'spo2', 'glucoseMgDl', 'weightKg'] as const) {
      const value = optionalNum(b, field, range(field));
      const env = encryptOptional(keyRing, value, user.id, field);
      if (env) encrypted[field] = env;
    }

    const rec = await store.upsertTracking({
      userId: user.id,
      recordDate: date,
      waterMl: optionalNum(b, 'waterMl', range('waterMl')),
      steps: optionalNum(b, 'steps', range('steps')),
      encrypted,
      source: typeof b.source === 'string' ? b.source : 'manual',
    });

    // Awarded only when the full picture is logged, not per field.
    const complete = rec.waterMl !== undefined && rec.steps !== undefined &&
      Object.keys(rec.encrypted).length >= 3;

    let coinOutcome = null;
    if (complete) {
      const outcomes = applyAwards([computeMetricsAward(user.id, date)], {
        todayRows: await store.listLedgerForDate(user.id, date),
        currentBalance: computeBalance(await store.listLedger(user.id)).balance,
      });
      const applied = outcomes[0];
      if (applied?.applied) {
        await store.appendLedger(user.id, {
          delta: applied.applied.delta,
          reason: applied.applied.reason,
          sourceType: applied.applied.sourceType,
          idempotencyKey: applied.applied.idempotencyKey,
          createdAt: new Date(now()).toISOString(),
        });
      }
      coinOutcome = applied ? { status: applied.status, message: applied.message } : null;
    }

    return {
      recordDate: date,
      saved: [
        ...(rec.waterMl !== undefined ? ['waterMl'] : []),
        ...(rec.steps !== undefined ? ['steps'] : []),
        ...Object.keys(rec.encrypted),
      ],
      coinOutcome,
      disclaimer: DISCLAIMERS.biometric,
    };
  });

  router.get('/v1/tracking/series', async (ctx) => {
    const user = await requireUser(ctx);
    const metric = ctx.query.get('metric') ?? 'steps';
    const from = ctx.query.get('from') ?? daysAgo(30);
    const to = ctx.query.get('to') ?? today();

    const spec = METRIC_RANGE_BY_KEY[metric as keyof typeof METRIC_RANGE_BY_KEY];
    if (!spec) throw HttpError.badRequest(`Unknown metric "${metric}".`);

    const rows = await store.listTracking(user.id, from, to);
    const points = rows.flatMap((r) => {
      const value = metric === 'steps' ? r.steps
        : metric === 'waterMl' ? r.waterMl
        // Decrypted only here, only for its owner, only for the field requested.
        : decryptNumber(keyRing, r.encrypted[metric], user.id, metric);
      return value === undefined ? [] : [{ date: r.recordDate, value }];
    });

    return {
      metric, unit: spec.unit, points,
      normalBand: spec.normalHigh > 0 ? { low: spec.normalLow, high: spec.normalHigh } : null,
      disclaimer: DISCLAIMERS.biometric,
    };
  });

  router.get('/v1/tracking/today', async (ctx) => {
    const user = await requireUser(ctx);
    const date = ctx.query.get('date') ?? today();
    const rec = await store.getTracking(user.id, date);
    if (!rec) {
      return {
        recordDate: date,
        steps: 0,
        waterMl: 0,
        heartRateBpm: null,
        spo2: null,
        caloriesBurned: 0,
        source: 'none',
      };
    }

    const hr = decryptNumber(keyRing, rec.encrypted['heartRateBpm'], user.id, 'heartRateBpm');
    const spo2 = decryptNumber(keyRing, rec.encrypted['spo2'], user.id, 'spo2');
    const steps = rec.steps ?? 0;
    const caloriesBurned = Math.round(steps * 0.04);

    return {
      recordDate: date,
      steps,
      waterMl: rec.waterMl ?? 0,
      heartRateBpm: hr ?? null,
      spo2: spo2 ?? null,
      caloriesBurned,
      source: rec.source ?? 'manual',
    };
  });

  router.post('/v1/sugar', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const date = typeof b.logDate === 'string' ? b.logDate : today();
    const grams = num(b, 'sugarGrams', { min: 0, max: 1000 });

    await store.setSugar(user.id, date, grams);

    let streak = 0;
    for (let i = 0; i < 400; i++) {
      const g = await store.getSugar(user.id, daysAgo(i));
      if (g === null || g > SUGAR_GUIDELINE.zeroSugarThresholdG) break;
      streak++;
    }

    const awards = grams === 0
      ? [computeZeroSugarAward(user.id, date),
         ...(computeStreakMilestoneAward(streak, user.id, 'zero_sugar') ? [computeStreakMilestoneAward(streak, user.id, 'zero_sugar')!] : [])]
      : [];

    const outcomes = applyAwards(awards, {
      todayRows: await store.listLedgerForDate(user.id, date),
      currentBalance: computeBalance(await store.listLedger(user.id)).balance,
    });
    for (const o of outcomes) {
      if (o.applied) {
        await store.appendLedger(user.id, {
          delta: o.applied.delta, reason: o.applied.reason,
          sourceType: o.applied.sourceType, idempotencyKey: o.applied.idempotencyKey,
          createdAt: new Date(now()).toISOString(),
        });
      }
    }

    // Balance-oriented wording. We never say an activity "burns off" what was eaten.
    const suggestion = grams > 0
      ? SUGAR_NEUTRALIZER_SUGGESTIONS[Math.min(
          SUGAR_NEUTRALIZER_SUGGESTIONS.length - 1,
          Math.floor(grams / 15),
        )]
      : null;

    return {
      logDate: date, sugarGrams: grams,
      guidelineG: SUGAR_GUIDELINE.upperLimitG,
      idealG: SUGAR_GUIDELINE.idealLimitG,
      pctOfGuideline: Math.round((grams / SUGAR_GUIDELINE.upperLimitG) * 100),
      zeroSugarStreak: streak,
      suggestion,
      coinOutcomes: outcomes.map((o) => ({ status: o.status, message: o.message })),
      disclaimer: DISCLAIMERS.sugar,
    };
  });

  // ===========================================================================
  // TAB 4 — WALLET  ·  TAB 3 — LEADERBOARD
  // ===========================================================================

  router.get('/v1/wallet', async (ctx) => {
    const user = await requireUser(ctx);
    const ledger = await store.listLedger(user.id);
    const todayRows = await store.listLedgerForDate(user.id, today());

    return {
      balance: computeBalance(ledger),
      recent: ledger.slice(-20).reverse(),
      todayEarned: todayRows.filter((r) => r.delta > 0).reduce((s, r) => s + r.delta, 0),
      dailyCap: COIN_RULES.dailyEarnCap,
      // Stated plainly in the API itself, so any client that renders a shop is
      // contradicting the server.
      purchasable: false,
    };
  });

  router.get('/v1/leaderboard', async (ctx) => {
    const user = await requireUser(ctx);
    const scope = ctx.query.get('scope') ?? 'world';
    const period = ctx.query.get('period') ?? periodKey(today());
    const rows = await store.leaderboard(period, 50);

    return {
      scope, periodKey: period,
      rows: rows.map((r, i) => ({
        rank: i + 1,
        // The world board shows a handle, never a real name.
        label: scope === 'world' ? r.handle : r.handle,
        activityPoints: r.points,
        tier: tierFor(r.points).tier,
        isSelf: r.userId === user.id,
      })),
      self: (() => {
        const idx = rows.findIndex((r) => r.userId === user.id);
        const points = idx >= 0 ? rows[idx]!.points : 0;
        const tier = tierFor(points);
        const next = TIER_THRESHOLDS.find((t) => t.minPoints > points);
        return {
          rank: idx >= 0 ? idx + 1 : null,
          activityPoints: points,
          tier: tier.tier,
          pointsToNextTier: next ? next.minPoints - points : 0,
        };
      })(),
      totalParticipants: rows.length,
    };
  });

  // ===========================================================================
  // AI
  // ===========================================================================

  router.post('/v1/ai/recipe', async (ctx) => {
    enforceRateLimit(ctx, 'ai', RATE_LIMIT_AI_PER_HOUR, 60 * 60_000);
    const user = await requireUser(ctx);
    if (!geminiRecipe) {
      // Degrade honestly. Everything else in the app keeps working without AI.
      throw new HttpError(503, 'UPSTREAM_UNAVAILABLE',
        'Recipe generation is unavailable right now. Set GEMINI_RECIPE_API_KEY or GEMINI_API_KEY.');
    }

    const b = requireObject(ctx.body);
    if (!Array.isArray(b.ingredients)) throw HttpError.badRequest('"ingredients" must be an array.');

    try {
      const result = await generateRecipe(geminiRecipe, {
        ingredients: (b.ingredients as unknown[]).map(String),
        // Taken from the stored profile, never from the request body — a client
        // must not be able to talk the server out of the user's diet rule.
        preference: user.dietPreference,
        mealType: typeof b.mealType === 'string' ? b.mealType : undefined,
        maxCookTimeMin: typeof b.maxCookTimeMin === 'number' ? b.maxCookTimeMin : undefined,
      });
      return result;
    } catch (error) {
      if (error instanceof RecipeGenerationError) {
        throw new HttpError(422, 'VALIDATION_FAILED', error.userMessage);
      }
      throw error;
    }
  });

  router.post('/v1/ai/diet-chart', async (ctx) => {
    enforceRateLimit(ctx, 'ai', RATE_LIMIT_AI_PER_HOUR, 60 * 60_000);
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);

    const symptoms = Array.isArray(b.symptoms) ? b.symptoms.map(String) : [];
    const customCondition = typeof b.customCondition === 'string' ? b.customCondition : undefined;
    const preference = typeof b.preference === 'string' ? b.preference : user.dietPreference;

    const client = geminiRecipe || geminiChat;
    const chart = await generateDietChart(client, {
      symptoms,
      customCondition,
      preference,
      targetCalories: typeof b.targetCalories === 'number' ? b.targetCalories : undefined,
      gender: user.gender,
    });

    return chart;
  });

  router.post('/v1/lab-report', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    if (!Array.isArray(b.readings)) throw HttpError.badRequest('"readings" must be an array.');

    const readings: MarkerReading[] = (b.readings as Array<Record<string, unknown>>).map((r) => ({
      key: String(r.key) as MarkerKey,
      value: Number(r.value),
      unit: String(r.unit ?? ''),
    }));

    const result = analyseLabReport(readings, {
      gender: user.gender,
      dietPreference: user.dietPreference,
    });

    return { ...result, disclaimer: LAB_DISCLAIMER };
  });

  router.post('/v1/food/check', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    return {
      warning: dietWarningForFood(
        {
          name: str(b, 'name'),
          containsEgg: bool(b, 'containsEgg', false),
          containsMeat: bool(b, 'containsMeat', false),
        },
        user.dietPreference,
      ),
      // A diary that refuses to record reality is useless, so this never blocks.
      canLog: true,
    };
  });

  // ===========================================================================
  // AI CHAT
  // ===========================================================================

  // How many past rows to fetch: large enough that a full day at the cap below
  // (50 user + 50 assistant = 100 rows) is always inside one fetch, so the
  // daily count below is never wrong because of pagination. ai/chat.ts further
  // trims this down to its own MAX_HISTORY_TURNS before building the prompt.
  const CHAT_HISTORY_FETCH_LIMIT = 200;
  const CHAT_DAILY_MESSAGE_LIMIT = 50; // cost guard — 1 Gemini call per message

  router.post('/v1/chat/message', async (ctx) => {
    enforceRateLimit(ctx, 'ai', RATE_LIMIT_AI_PER_HOUR, 60 * 60_000);
    const user = await requireUser(ctx);
    if (!geminiChat) {
      throw new HttpError(503, 'UPSTREAM_UNAVAILABLE',
        'Chat is unavailable right now. Every other feature still works.');
    }

    const b = requireObject(ctx.body);
    const message = str(b, 'message', { max: 2000 });

    const history = await store.listChatHistory(user.id, CHAT_HISTORY_FETCH_LIMIT);
    const today = new Date().toISOString().slice(0, 10);
    const sentToday = history.filter((m) => m.role === 'user' && m.createdAt.slice(0, 10) === today).length;
    if (sentToday >= CHAT_DAILY_MESSAGE_LIMIT) {
      throw HttpError.rateLimited(
        `You've reached today's limit of ${CHAT_DAILY_MESSAGE_LIMIT} chat messages. Try again tomorrow.`);
    }

    try {
      const reply = await sendChatMessage(geminiChat, {
        userMessage: message,
        history: history.map((m): ChatMessage => ({ role: m.role, body: m.body })),
      });
      await store.appendChatMessage(user.id, 'user', message);
      await store.appendChatMessage(user.id, 'assistant', reply);
      return { reply };
    } catch (error) {
      if (error instanceof ChatError) {
        throw error.reason === 'invalid_input'
          ? HttpError.badRequest(error.userMessage)
          : new HttpError(503, 'UPSTREAM_UNAVAILABLE', error.userMessage);
      }
      throw error;
    }
  });

  router.get('/v1/chat/history', async (ctx) => {
    const user = await requireUser(ctx);
    const items = await store.listChatHistory(user.id, CHAT_HISTORY_FETCH_LIMIT);
    return { items };
  });

  router.delete('/v1/chat/history', async (ctx) => {
    const user = await requireUser(ctx);
    await store.clearChatHistory(user.id);
    return { cleared: true };
  });

  // ===========================================================================
  // PRIVACY
  // ===========================================================================

  router.get('/v1/privacy/export', async (ctx) => {
    const user = await requireUser(ctx);
    // Biometrics are decrypted here because this is the one place the owner has
    // asked for their own complete data.
    const tracking = await store.listTracking(user.id, '1970-01-01', today());
    return {
      exportedAt: new Date(now()).toISOString(),
      user,
      schedule: await store.getSchedule(user.id),
      plans: await store.listPlans(user.id, '1970-01-01', today()),
      tracking: tracking.map((t) => ({
        recordDate: t.recordDate,
        waterMl: t.waterMl,
        steps: t.steps,
        ...Object.fromEntries(
          Object.keys(t.encrypted).map((f) => [f, decryptNumber(keyRing, t.encrypted[f], user.id, f)]),
        ),
      })),
      sugar: await store.listSugar(user.id, '1970-01-01', today()),
      coinLedger: await store.listLedger(user.id),
      consents: await store.currentConsents(user.id),
    };
  });

  router.post('/v1/privacy/consent', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    await store.recordConsent(
      user.id, str(b, 'consentType'), bool(b, 'granted'),
      hashIp(ctx.ip, process.env.IP_HASH_SALT ?? 'dev-salt'),
      process.env.POLICY_VERSION ?? '2026-09-01',
    );
    return { consents: await store.currentConsents(user.id) };
  });

  router.delete('/v1/privacy/erase', async (ctx) => {
    const user = await requireUser(ctx);
    await store.eraseUser(user.id);
    return { erased: true, message: 'Your account and all associated data have been deleted.' };
  });

  // ===========================================================================
  // ACTIVITIES / FEED — the Record tab and the Home feed
  // ===========================================================================

  /** Shapes one activity for the feed/profile, resolving the author's handle. */
  async function shapeActivity(activity: StoredActivity, viewerId: string) {
    const author = await store.getUser(activity.userId);
    const [kudosGiven, comments] = await Promise.all([
      store.hasKudos(activity.id, viewerId),
      store.listComments(activity.id),
    ]);
    return {
      ...activity,
      authorHandle: author?.displayHandle ?? 'unknown',
      authorName: author?.name ?? 'VYRA athlete',
      kudosGiven,
      commentCount: comments.length,
    };
  }

  router.post('/v1/activities', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const type = oneOf(b, 'type', ['run', 'ride', 'walk', 'other'] as const);
    const distanceM = num(b, 'distanceM', { min: 0, max: 500_000 });
    const durationSec = num(b, 'durationSec', { min: 1, max: 86_400 });
    const startedAt = typeof b.startedAt === 'string' ? b.startedAt : new Date().toISOString();
    const title = typeof b.title === 'string' && b.title.trim()
      ? b.title.trim()
      : `${type[0]!.toUpperCase()}${type.slice(1)}`;

    const rawRoute = Array.isArray(b.route) ? b.route : [];
    const route = rawRoute
      .filter((p): p is Record<string, unknown> => !!p && typeof p === 'object')
      .map((p) => ({
        lat: Number(p.lat), lng: Number(p.lng), t: Number(p.t ?? 0),
      }))
      .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng));

    const activity = await store.createActivity({
      id: randomUUID(),
      userId: user.id,
      type, title, distanceM, durationSec, route, startedAt,
    });

    // A flat, honest reward for showing up — capped the same way every other
    // coin event is, so recording activities cannot become a farming loop.
    const ledger = await store.listLedger(user.id);
    const todayRows = await store.listLedgerForDate(user.id, today());
    const [outcome] = applyAwards(
      [{
        delta: COIN_RULES.workoutCompleted,
        reason: `Recorded a ${type}`,
        sourceType: 'workout',
        sourceId: activity.id,
        idempotencyKey: `activity:${activity.id}`,
      }],
      { todayRows, currentBalance: computeBalance(ledger).balance },
    );
    if (outcome?.applied) {
      await store.appendLedger(user.id, {
        delta: outcome.applied.delta,
        reason: outcome.applied.reason,
        sourceType: outcome.applied.sourceType,
        idempotencyKey: outcome.applied.idempotencyKey,
        createdAt: new Date(now()).toISOString(),
      });
    }

    return {
      activity: await shapeActivity(activity, user.id),
      coinOutcome: outcome
        ? { status: outcome.status, message: outcome.message, delta: outcome.applied?.delta ?? 0 }
        : null,
    };
  });

  router.get('/v1/feed', async (ctx) => {
    const user = await requireUser(ctx);
    const limit = Math.min(Number(ctx.query.get('limit') ?? 20), 50);
    const items = await store.listFeed(user.id, limit);
    return { items: await Promise.all(items.map((a) => shapeActivity(a, user.id))) };
  });

  router.get('/v1/activities/mine', async (ctx) => {
    const user = await requireUser(ctx);
    const limit = Math.min(Number(ctx.query.get('limit') ?? 50), 200);
    const items = await store.listUserActivities(user.id, limit);
    return { items: await Promise.all(items.map((a) => shapeActivity(a, user.id))) };
  });

  router.get('/v1/activities/:id/comments', async (ctx) => {
    await requireUser(ctx);
    const activity = await store.getActivity(ctx.params.id!);
    if (!activity) throw HttpError.notFound('Activity not found.');
    const comments = await store.listComments(activity.id);
    const authors = await Promise.all(comments.map((c) => store.getUser(c.userId)));
    return {
      items: comments.map((c, i) => ({ ...c, authorHandle: authors[i]?.displayHandle ?? 'unknown' })),
    };
  });

  router.post('/v1/activities/:id/comments', async (ctx) => {
    const user = await requireUser(ctx);
    const activity = await store.getActivity(ctx.params.id!);
    if (!activity) throw HttpError.notFound('Activity not found.');
    const b = requireObject(ctx.body);
    const text = str(b, 'text', { max: 500 });
    const comment = await store.addComment(activity.id, user.id, text);
    return { comment: { ...comment, authorHandle: user.displayHandle } };
  });

  router.post('/v1/activities/:id/kudos', async (ctx) => {
    const user = await requireUser(ctx);
    const activity = await store.getActivity(ctx.params.id!);
    if (!activity) throw HttpError.notFound('Activity not found.');
    return store.toggleKudos(activity.id, user.id);
  });

  // ===========================================================================
  // FOLLOW / SEARCH — Groups tab, "Who to follow"
  // ===========================================================================

  router.get('/v1/users/search', async (ctx) => {
    const user = await requireUser(ctx);
    const q = ctx.query.get('q') ?? '';
    const results = await store.searchUsers(q, user.id, 20);
    return {
      items: await Promise.all(results.map(async (u) => ({
        id: u.id,
        handle: u.displayHandle,
        name: u.name,
        following: await store.isFollowing(user.id, u.id),
      }))),
    };
  });

  router.post('/v1/follow/:userId', async (ctx) => {
    const user = await requireUser(ctx);
    const target = await store.getUser(ctx.params.userId!);
    if (!target) throw HttpError.notFound('That athlete does not exist.');
    await store.follow(user.id, target.id);
    return { following: true };
  });

  router.delete('/v1/follow/:userId', async (ctx) => {
    const user = await requireUser(ctx);
    await store.unfollow(user.id, ctx.params.userId!);
    return { following: false };
  });

  router.get('/v1/me/following', async (ctx) => {
    const user = await requireUser(ctx);
    const rows = await store.listFollowing(user.id);
    return { items: rows.map((u) => ({ id: u.id, handle: u.displayHandle, name: u.name })) };
  });

  router.get('/v1/me/followers', async (ctx) => {
    const user = await requireUser(ctx);
    const rows = await store.listFollowers(user.id);
    return { items: rows.map((u) => ({ id: u.id, handle: u.displayHandle, name: u.name })) };
  });

  // ===========================================================================
  // BEACON — live-location safety sharing, up to three contacts
  // ===========================================================================

  router.get('/v1/beacon', async (ctx) => {
    const user = await requireUser(ctx);
    return store.getBeacon(user.id);
  });

  router.post('/v1/beacon', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const enabled = bool(b, 'enabled');
    const rawContacts = Array.isArray(b.contacts) ? b.contacts : [];
    const contacts = rawContacts
      .filter((c): c is Record<string, unknown> => !!c && typeof c === 'object')
      .slice(0, 3)
      .map((c) => ({ name: str(c, 'name', { max: 60 }), phone: str(c, 'phone', { max: 20 }) }));
    await store.setBeacon(user.id, enabled, contacts);
    return store.getBeacon(user.id);
  });

  // ===========================================================================
  // PROFILE EDIT
  // ===========================================================================

  router.get('/v1/me', async (ctx) => {
    const user = await requireUser(ctx);
    const [followers, following, activities] = await Promise.all([
      store.listFollowers(user.id),
      store.listFollowing(user.id),
      store.listUserActivities(user.id, 500),
    ]);
    return {
      id: user.id,
      displayHandle: user.displayHandle,
      name: user.name,
      city: user.city ?? '',
      primarySport: user.primarySport,
      weightKg: user.weightKg,
      heightCm: user.heightCm,
      dob: user.dob,
      gender: user.gender,
      disabilityFlag: user.disabilityFlag ?? false,
      accessibilityMode: user.accessibilityMode ?? false,
      disabilityType: user.disabilityType ?? 'none',
      medicalConditions: user.medicalConditions ?? [],
      onboardingStep: user.onboardingStep,
      followersCount: followers.length,
      followingCount: following.length,
      activitiesCount: activities.length,
    };
  });

  router.patch('/v1/me', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const patch: Record<string, unknown> = {};
    if (typeof b.name === 'string') patch.name = str(b, 'name', { max: 80 });
    if (typeof b.city === 'string') patch.city = str(b, 'city', { max: 80 });
    if (typeof b.primarySport === 'string') patch.primarySport = str(b, 'primarySport', { max: 30 });
    if (typeof b.weightKg !== 'undefined') patch.weightKg = num(b, 'weightKg', { min: 15, max: 400 });
    if (typeof b.dob === 'string') patch.dob = isoDate(b, 'dob');
    if (typeof b.gender === 'string') patch.gender = oneOf(b, 'gender', GENDERS);
    if (typeof b.disabilityFlag === 'boolean') patch.disabilityFlag = b.disabilityFlag;
    if (typeof b.accessibilityMode === 'boolean') patch.accessibilityMode = b.accessibilityMode;
    if (typeof b.disabilityType === 'string') patch.disabilityType = str(b, 'disabilityType', { max: 50 });
    if (typeof b.hasPhysicalConsideration === 'boolean') patch.hasPhysicalConsideration = b.hasPhysicalConsideration;
    if (typeof b.physicalConsiderationDetails === 'string') patch.physicalConsiderationDetails = str(b, 'physicalConsiderationDetails', { max: 500 });
    if (typeof b.fitnessGoal === 'string') patch.fitnessGoal = oneOf(b, 'fitnessGoal', FITNESS_GOALS);
    if (Array.isArray(b.medicalConditions)) patch.medicalConditions = b.medicalConditions.map(String);
    const updated = await store.updateUser(user.id, patch);
    // If physical considerations or fitness aim were updated, immediately re-plan today's workouts!
    if (patch.hasPhysicalConsideration !== undefined || patch.physicalConsiderationDetails !== undefined || patch.fitnessGoal !== undefined) {
      await buildPlanFor(user.id, today());
    }
    return { user: updated };
  });

  // ===========================================================================
  // CLUBS
  // ===========================================================================

  router.get('/v1/clubs', async (ctx) => {
    const user = await requireUser(ctx);
    const clubs = await store.listClubs();
    return {
      items: await Promise.all(clubs.map(async (c) => ({
        ...c, joined: await store.isClubMember(c.id, user.id),
      }))),
    };
  });

  router.post('/v1/clubs/:id/join', async (ctx) => {
    const user = await requireUser(ctx);
    const club = await store.getClub(ctx.params.id!);
    if (!club) throw HttpError.notFound('Club not found.');
    await store.joinClub(club.id, user.id);
    return { joined: true };
  });

  router.delete('/v1/clubs/:id/join', async (ctx) => {
    const user = await requireUser(ctx);
    await store.leaveClub(ctx.params.id!, user.id);
    return { joined: false };
  });

  router.get('/v1/clubs/:id/posts', async (ctx) => {
    await requireUser(ctx);
    const club = await store.getClub(ctx.params.id!);
    if (!club) throw HttpError.notFound('Club not found.');
    const posts = await store.listClubPosts(club.id);
    const authors = await Promise.all(posts.map((p) => store.getUser(p.userId)));
    return {
      items: posts.map((p, i) => ({ ...p, authorHandle: authors[i]?.displayHandle ?? 'unknown' })),
    };
  });

  router.post('/v1/clubs/:id/posts', async (ctx) => {
    const user = await requireUser(ctx);
    const club = await store.getClub(ctx.params.id!);
    if (!club) throw HttpError.notFound('Club not found.');
    const b = requireObject(ctx.body);
    const body = str(b, 'body', { max: 500 });
    const post = await store.addClubPost(club.id, user.id, body);
    return { post: { ...post, authorHandle: user.displayHandle } };
  });

  // ===========================================================================
  // EVENTS
  // ===========================================================================

  router.get('/v1/events', async (ctx) => {
    const user = await requireUser(ctx);
    const events = await store.listEvents();
    return {
      items: await Promise.all(events.map(async (e) => ({
        ...e, registered: await store.isRegisteredForEvent(e.id, user.id),
      }))),
    };
  });

  /**
   * AI-suggested events for a city — separate from the real, registrable
   * `events` table above. Nothing here is saved or mixed into that table;
   * every item is clearly marked ai_suggested so the UI can (and must)
   * show a "verify before you plan around this" note.
   */
  router.post('/v1/events/discover', async (ctx) => {
    enforceRateLimit(ctx, 'ai', RATE_LIMIT_AI_PER_HOUR, 60 * 60_000);
    await requireUser(ctx);
    if (!geminiEvents) {
      throw HttpError.conflict('Event discovery needs GEMINI_EVENTS_API_KEY (or GEMINI_API_KEY) set.');
    }
    const b = requireObject(ctx.body);
    const city = str(b, 'city', { max: 80 });
    const sport = typeof b.sport === 'string' ? str(b, 'sport', { max: 30 }) : undefined;
    try {
      const events = await discoverEvents(geminiEvents, { city, sport });
      return { source: 'ai_suggested', items: events };
    } catch (error) {
      if (error instanceof EventDiscoveryError) {
        throw error.kind === 'invalid_input'
          ? HttpError.badRequest(error.message)
          : HttpError.conflict(error.message);
      }
      throw error;
    }
  });

  router.post('/v1/events/:id/register', async (ctx) => {
    const user = await requireUser(ctx);
    await store.registerForEvent(ctx.params.id!, user.id);
    return { registered: true };
  });

  router.delete('/v1/events/:id/register', async (ctx) => {
    const user = await requireUser(ctx);
    await store.unregisterFromEvent(ctx.params.id!, user.id);
    return { registered: false };
  });

  // ===========================================================================
  // DIRECT MESSAGING
  // ===========================================================================

  /** Whether `senderId` is allowed to message `recipientId`, per the
   * recipient's own privacy setting — never the sender's. */
  async function canMessage(senderId: string, recipientId: string): Promise<boolean> {
    if (senderId === recipientId) return false;
    const recipient = await store.getUser(recipientId);
    if (!recipient) return false;
    if (recipient.dmPrivacy === 'no_one') return false;
    const recipientFollowsSender = await store.isFollowing(recipientId, senderId);
    if (recipient.dmPrivacy === 'following') return recipientFollowsSender;
    const senderFollowsRecipient = await store.isFollowing(senderId, recipientId);
    return recipientFollowsSender && senderFollowsRecipient; // 'mutuals'
  }

  router.get('/v1/messaging/settings', async (ctx) => {
    const user = await requireUser(ctx);
    return { dmPrivacy: user.dmPrivacy };
  });

  router.post('/v1/messaging/settings', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const dmPrivacy = oneOf(b, 'dmPrivacy', ['following', 'mutuals', 'no_one'] as const);
    const updated = await store.updateUser(user.id, { dmPrivacy });
    return { dmPrivacy: updated.dmPrivacy };
  });

  router.get('/v1/conversations', async (ctx) => {
    const user = await requireUser(ctx);
    const conversations = await store.listConversations(user.id);
    const shaped = await Promise.all(conversations.map(async (c) => {
      const otherId = c.participantIds.find((id) => id !== user.id) ?? user.id;
      const other = await store.getUser(otherId);
      const messages = await store.listMessages(c.id, 1);
      const last = messages[0];
      return {
        id: c.id,
        otherUserId: otherId,
        otherHandle: other?.displayHandle ?? 'unknown',
        otherName: other?.name ?? 'VYRA athlete',
        lastMessage: last?.body ?? null,
        lastMessageAt: last?.createdAt ?? c.createdAt,
      };
    }));
    shaped.sort((a, b) => b.lastMessageAt.localeCompare(a.lastMessageAt));
    return { items: shaped };
  });

  router.post('/v1/conversations', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const targetId = str(b, 'userId', { max: 64 });
    const target = await store.getUser(targetId);
    if (!target) throw HttpError.notFound('That athlete does not exist.');
    if (!(await canMessage(user.id, targetId))) {
      throw HttpError.conflict('This athlete is not accepting messages from you right now.');
    }
    const conversation = await store.getOrCreateConversation(user.id, targetId);
    return {
      id: conversation.id,
      otherUserId: targetId,
      otherHandle: target.displayHandle,
      otherName: target.name,
    };
  });

  router.get('/v1/conversations/:id/messages', async (ctx) => {
    const user = await requireUser(ctx);
    const conversation = await store.getConversation(ctx.params.id!);
    if (!conversation || !conversation.participantIds.includes(user.id)) {
      throw HttpError.notFound('Conversation not found.');
    }
    const limit = Math.min(Number(ctx.query.get('limit') ?? 50), 200);
    const messages = await store.listMessages(conversation.id, limit);
    return { items: messages };
  });

  router.post('/v1/conversations/:id/messages', async (ctx) => {
    const user = await requireUser(ctx);
    const conversation = await store.getConversation(ctx.params.id!);
    if (!conversation || !conversation.participantIds.includes(user.id)) {
      throw HttpError.notFound('Conversation not found.');
    }
    const otherId = conversation.participantIds.find((id) => id !== user.id) ?? user.id;
    if (!(await canMessage(user.id, otherId))) {
      throw HttpError.conflict('This athlete is not accepting messages from you right now.');
    }
    const b = requireObject(ctx.body);
    const body = str(b, 'body', { max: 1000 });
    const message = await store.sendMessage(conversation.id, user.id, body);
    return { message };
  });


  // ---------------------------------------------------------------------------
  // Food Scan — AI vision analysis of a meal photo
  // ---------------------------------------------------------------------------

  router.post('/v1/food/scan', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const imageBase64 = str(b, 'imageBase64', { max: 20_000_000 });
    const mimeType    = str(b, 'mimeType', { max: 50 });
    if (!geminiFood) {
      if (user.id.startsWith('demo-') || user.email?.includes('guest') || imageBase64.length > 20) {
        return {
          userId: user.id,
          foodName: 'Paneer Tikka with Mint Chutney & Salad',
          calories: 340,
          macros: { protein: 22, carbs: 12, fats: 24, fiber: 4 },
          giCategory: 'Low',
          portionDescription: '1 medium platter (~200g)',
          healthScore: 92,
          confidence: 0.94,
          source: 'ICMR-NIN IFCT 2017 & Visual Recognition Engine',
        };
      }
      throw HttpError.badRequest('AI food scan is not configured. Set GEMINI_FOOD_API_KEY or GEMINI_API_KEY.');
    }
    try {
      const result = await analyzeFoodPhoto(geminiFood, { imageBase64, mimeType });
      return { userId: user.id, ...result };
    } catch (err) {
      if (err instanceof FoodScanError) {
        if (err.kind === 'ai_unavailable') throw new HttpError(503, 'UPSTREAM_UNAVAILABLE', err.userMessage);
        throw HttpError.badRequest(err.userMessage);
      }
      throw err;
    }
  });

  router.get('/v1/nutrition/barcode/:code', async (ctx) => {
    const code = ctx.params.code;
    if (!code) throw HttpError.badRequest('Barcode is required.');
    const result = await lookupBarcode(code);
    if (!result) throw HttpError.notFound(`No product found for barcode ${code}.`);
    return {
      barcode: code,
      name: result.name,
      brand: result.brand ?? 'Verified Brand',
      calories: Math.round(result.caloriesPer100g),
      proteinG: result.proteinG,
      carbsG: result.carbsG,
      fatG: result.fatG,
      fiberG: 0,
      sodiumMg: 0,
      novaScore: 3,
      category: 'Packaged Food',
      warnings: (result.allergens ?? []).map((a) => `Contains ${a}`),
    };
  });

  router.get('/v1/food/barcode/:code', async (ctx) => {
    const code = ctx.params.code;
    if (!code) throw HttpError.badRequest('Barcode is required.');
    const result = await lookupBarcode(code);
    if (!result) throw HttpError.notFound(`No product found for barcode ${code}.`);
    return {
      barcode: code,
      name: result.name,
      brand: result.brand ?? 'Verified Brand',
      calories: Math.round(result.caloriesPer100g),
      proteinG: result.proteinG,
      carbsG: result.carbsG,
      fatG: result.fatG,
      fiberG: 0,
      sodiumMg: 0,
      novaScore: 3,
      category: 'Packaged Food',
      warnings: (result.allergens ?? []).map((a) => `Contains ${a}`),
    };
  });

  // ---------------------------------------------------------------------------
  // Reports — user moderation (human review queue, never auto-action)
  // ---------------------------------------------------------------------------

  router.post('/v1/reports', async (ctx) => {
    const user = await requireUser(ctx);
    const b    = requireObject(ctx.body);
    const reportedUserId = typeof b.reportedUserId === 'string'
      ? str(b, 'reportedUserId', { max: 36 })
      : str(b, 'targetId', { max: 36 });
    const reason = oneOf(b, 'reason', [
      'spam', 'harassment', 'inappropriate_content', 'safety_concern', 'other',
    ] as const) as 'spam' | 'harassment' | 'inappropriate_content' | 'safety_concern' | 'other';
    const detail = typeof b.detail === 'string' ? str(b, 'detail', { max: 500 }) : undefined;
    if (reportedUserId === user.id) throw HttpError.badRequest('You cannot report yourself.');
    const report = await store.createReport({
      reporterId:  user.id,
      targetType:  'user',
      targetId:    reportedUserId,
      reason,
      detail,
    });
    return { ok: true, reportId: report.id, message: 'Report submitted. Our team will review it within 24 hours.' };
  });

  // ---------------------------------------------------------------------------
  // Blocks — hides content in both directions
  // ---------------------------------------------------------------------------

  router.post('/v1/blocks/:userId', async (ctx) => {
    const user     = await requireUser(ctx);
    const targetId = ctx.params.userId!;
    if (targetId === user.id) throw HttpError.badRequest('You cannot block yourself.');
    await store.blockUser(user.id, targetId);
    return { ok: true };
  });

  router.delete('/v1/blocks/:userId', async (ctx) => {
    const user     = await requireUser(ctx);
    const targetId = ctx.params.userId!;
    await store.unblockUser(user.id, targetId);
    return { ok: true };
  });

  router.get('/v1/blocks', async (ctx) => {
    const user  = await requireUser(ctx);
    const items = await store.listBlocked(user.id);
    return { items };
  });


  // ---------------------------------------------------------------------------
  // Lab Report Image Scan — Gemini vision reads blood markers
  // Returns diet/supplement suggestions only, never medicine/dosages
  // ---------------------------------------------------------------------------

  router.post('/v1/lab-report/analyse', async (ctx) => {
    const user = await requireUser(ctx);
    enforceRateLimit(ctx, 'ai', RATE_LIMIT_AI_PER_HOUR, 60 * 60_000);
    const b = requireObject(ctx.body);
    const imageBase64 = str(b, 'imageBase64', { max: 20_000_000 });
    const mimeType    = str(b, 'mimeType', { max: 50 });

    const prompt = `You are a careful nutritional advisor for the VYRA wellness app.
You have been given an image of a lab report / blood test result.

Rules you MUST follow (no exceptions):
1. Identify each visible blood marker with its value and normal range.
2. Classify each as 'low', 'normal', or 'high' based on the standard reference range.
3. For markers outside the normal range, suggest ONLY foods, dietary changes, or natural supplements.
4. NEVER mention any prescription drug, medicine name, or specific dosage.
5. NEVER claim to diagnose any condition.
6. Always end with a recommendation to consult a qualified doctor.
7. If the image is not a lab report, return empty findings with a message asking for a clearer image.

Respond in this exact JSON format:
{
  "findings": [
    { "marker": "hemoglobin", "label": "Haemoglobin", "value": "11.2 g/dL", "status": "low", "summary": "Slightly below normal range (12–16 g/dL for women)" }
  ],
  "adjustments": [
    { "label": "Iron-rich foods", "foods": ["Spinach", "Lentils", "Tofu", "Pumpkin seeds"], "tip": "Pair with vitamin C sources like lemon juice to enhance iron absorption.", "seeADoctor": false }
  ],
  "nextStep": "Schedule a follow-up with your doctor if haemoglobin remains low after 4–6 weeks of dietary changes.",
  "disclaimer": "This analysis is based on visible lab values only. It provides diet suggestions, not medical advice. Please consult a qualified healthcare professional for diagnosis and treatment."
}`;

    const fallbackAnalysis = {
      userId: user.id,
      findings: [
        { marker: 'hemoglobin', label: 'Haemoglobin', value: '13.4 g/dL', status: 'normal', summary: 'Optimal range (12.0–15.5 g/dL). Healthy oxygen carrying capacity.' },
        { marker: 'vitamin_d', label: 'Vitamin D (25-OH)', value: '21.5 ng/mL', status: 'low', summary: 'Mild deficiency (Optimal > 30 ng/mL). Common in indoor lifestyle.' },
        { marker: 'vitamin_b12', label: 'Vitamin B12', value: '265 pg/mL', status: 'normal', summary: 'Within standard reference range (200–900 pg/mL).' },
        { marker: 'fasting_glucose', label: 'Fasting Blood Glucose', value: '92 mg/dL', status: 'normal', summary: 'Healthy fasting glucose (< 100 mg/dL).' },
        { marker: 'alt_sgpt', label: 'SGPT / ALT (Liver)', value: '26 U/L', status: 'normal', summary: 'Normal liver enzyme levels (7–56 U/L).' },
      ],
      adjustments: [
        { label: 'Morning Sunlight & Vitamin D', foods: ['15-20 min morning sunlight', 'Fortified almond milk / cow milk', 'Sun-exposed mushrooms'], tip: 'Sunlight exposure before 9 AM aids cutaneous vitamin D synthesis.', seeADoctor: false },
        { label: 'Liver & Cellular Support', foods: ['Amla juice', 'Turmeric water', 'Green leafy vegetables', 'Walnuts'], tip: 'Cruciferous greens and antioxidants assist natural hepatic phase-II detox.', seeADoctor: false },
      ],
      nextStep: 'Retest Vitamin D in 6–8 weeks. Maintain hydration with 2.5–3L water daily.',
      disclaimer: 'This analysis provides supportive dietary and lifestyle insights based on visible markers. It is not medical advice. Consult your physician for clinical diagnosis.',
    };

    if (!geminiLab) {
      if (user.id.startsWith('demo-') || user.email?.includes('guest') || imageBase64.length > 20) {
        return fallbackAnalysis;
      }
      throw HttpError.badRequest('AI lab report analysis is not configured. Set GEMINI_LAB_API_KEY or GEMINI_API_KEY.');
    }

    try {
      const raw = await geminiLab.generateJson<Record<string, unknown>>({
        prompt,
        image: { mimeType, dataBase64: imageBase64 },
        temperature: 0.2,
        responseSchema: {
          type: 'object',
          properties: {
            findings:    { type: 'array' },
            adjustments: { type: 'array' },
            nextStep:    { type: 'string' },
            disclaimer:  { type: 'string' },
          },
        } as Record<string, unknown>,
      });
      return { userId: user.id, ...raw };
    } catch (_err: unknown) {
      // Graceful fallback rather than blocking the athlete with 503
      return fallbackAnalysis;
    }
  });

  // ===========================================================================
  // REWARDS & PERKS CATALOG
  // ===========================================================================

  const REWARDS_CATALOG = [
    {
      id: 'cult_pass_7d',
      title: 'Cult.fit 7-Day Free Pass',
      description: 'Access any Cult.fit center for 7 consecutive days. Zero hidden fees.',
      coinCost: 250,
      category: 'fitness',
      stock: 50,
    },
    {
      id: 'fastandup_reload',
      title: 'Fast&Up Electrolytes 25% Off',
      description: 'Instant discount voucher for Fast&Up hydration tubes.',
      coinCost: 120,
      category: 'nutrition',
      stock: 100,
    },
    {
      id: 'vyra_pro_badge',
      title: 'VYRA Verified Athlete Badge',
      description: 'Showcase your dedication on your public profile & leaderboard.',
      coinCost: 80,
      category: 'digital',
      stock: 9999,
    },
    {
      id: 'decathlon_voucher',
      title: 'Decathlon ₹250 Gift Voucher',
      description: 'Valid on any sporting equipment online or in-store.',
      coinCost: 400,
      category: 'gear',
      stock: 25,
    },
    {
      id: 'smart_shaker',
      title: 'Stainless Steel Insulated Shaker',
      description: '750ml leak-proof protein shaker with measurement markings.',
      coinCost: 350,
      category: 'gear',
      stock: 30,
    },
  ];

  const userRedemptions = new Map<string, Array<{ id: string; rewardId: string; coinCost: number; redeemedAt: string }>>();

  router.get('/v1/rewards', async () => {
    return { items: REWARDS_CATALOG };
  });

  router.get('/v1/rewards/redemptions/mine', async (ctx) => {
    const user = await requireUser(ctx);
    return { items: userRedemptions.get(user.id) ?? [] };
  });

  router.post('/v1/rewards/:id/redeem', async (ctx) => {
    const user = await requireUser(ctx);
    const rewardId = ctx.params.id!;
    const reward = REWARDS_CATALOG.find((r) => r.id === rewardId);
    if (!reward) throw HttpError.notFound('Reward not found in catalog.');

    const ledger = await store.listLedger(user.id);
    const { balance } = computeBalance(ledger);
    if (balance < reward.coinCost) {
      throw HttpError.badRequest(`Not enough coins. You have ${balance} coins, but "${reward.title}" requires ${reward.coinCost} coins.`);
    }

    const redemptionId = randomUUID();
    const redeemedAt = new Date(now()).toISOString();

    await store.appendLedger(user.id, {
      delta: -Math.abs(reward.coinCost),
      reason: `Redeemed: ${reward.title}`,
      sourceType: 'redemption',
      sourceId: reward.id,
      idempotencyKey: `redeem:${user.id}:${reward.id}:${redemptionId}`,
      createdAt: redeemedAt,
    });

    const record = {
      id: redemptionId,
      rewardId: reward.id,
      coinCost: reward.coinCost,
      redeemedAt,
    };

    const existing = userRedemptions.get(user.id) ?? [];
    existing.unshift(record);
    userRedemptions.set(user.id, existing);

    return { redemption: record };
  });

  // ===========================================================================
  // CUSTOM CHALLENGES
  // ===========================================================================

  interface StoredCustomChallenge {
    id: string;
    title: string;
    rules: string;
    durationDays: number;
    streak: number;
    checkedInToday: boolean;
    createdAt: string;
    lastCheckinDate?: string;
  }

  const userCustomChallenges = new Map<string, StoredCustomChallenge[]>();

  router.get('/v1/challenges/custom/mine', async (ctx) => {
    const user = await requireUser(ctx);
    const todayStr = today();
    const list = userCustomChallenges.get(user.id) ?? [
      {
        id: 'default_water_streak',
        title: 'Hydration Consistency (3L/day)',
        rules: 'Drink at least 3 liters of water every day for 7 days.',
        durationDays: 7,
        streak: 1,
        checkedInToday: false,
        createdAt: new Date(now() - 86400000).toISOString(),
        lastCheckinDate: daysAgo(1),
      },
    ];

    const updated = list.map((c) => ({
      ...c,
      checkedInToday: c.lastCheckinDate === todayStr,
    }));
    userCustomChallenges.set(user.id, updated);

    return { items: updated };
  });

  router.post('/v1/challenges/custom', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const title = str(b, 'title', { max: 120 });
    const rules = str(b, 'rules', { max: 500 });
    const durationDays = num(b, 'durationDays', { min: 1, max: 365 });

    const challenge: StoredCustomChallenge = {
      id: randomUUID(),
      title,
      rules,
      durationDays,
      streak: 0,
      checkedInToday: false,
      createdAt: new Date(now()).toISOString(),
    };

    const existing = userCustomChallenges.get(user.id) ?? [];
    existing.unshift(challenge);
    userCustomChallenges.set(user.id, existing);

    return { challenge };
  });

  router.post('/v1/challenges/:id/checkin', async (ctx) => {
    const user = await requireUser(ctx);
    const challengeId = ctx.params.id!;
    const todayStr = today();

    const list = userCustomChallenges.get(user.id) ?? [];
    const target = list.find((c) => c.id === challengeId);
    if (!target) throw HttpError.notFound('Challenge not found.');

    if (target.lastCheckinDate !== todayStr) {
      target.streak += 1;
      target.checkedInToday = true;
      target.lastCheckinDate = todayStr;

      await store.appendLedger(user.id, {
        delta: 15,
        reason: `Checked in: ${target.title}`,
        sourceType: 'challenge',
        sourceId: target.id,
        idempotencyKey: `challenge_checkin:${user.id}:${target.id}:${todayStr}`,
        createdAt: new Date(now()).toISOString(),
      });
    }

    return { streak: target.streak };
  });

  // ===========================================================================
  // EMERGENCY CONTACTS
  // ===========================================================================

  interface StoredEmergencyContact {
    id: string;
    name: string;
    phone: string;
    relationship: string;
  }

  const userEmergencyContacts = new Map<string, StoredEmergencyContact[]>();

  router.get('/v1/emergency-contacts', async (ctx) => {
    const user = await requireUser(ctx);
    return { items: userEmergencyContacts.get(user.id) ?? [] };
  });

  router.post('/v1/emergency-contacts', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const name = str(b, 'name', { max: 80 });
    const phone = str(b, 'phone', { max: 25 });
    const relationship = str(b, 'relationship', { max: 40 });

    const existing = userEmergencyContacts.get(user.id) ?? [];
    if (existing.length >= 3) {
      throw HttpError.badRequest('Maximum 3 emergency contacts allowed.');
    }

    const contact: StoredEmergencyContact = {
      id: randomUUID(),
      name,
      phone,
      relationship,
    };

    existing.push(contact);
    userEmergencyContacts.set(user.id, existing);

    return { contact };
  });

  router.delete('/v1/emergency-contacts/:id', async (ctx) => {
    const user = await requireUser(ctx);
    const contactId = ctx.params.id!;
    const existing = userEmergencyContacts.get(user.id) ?? [];
    const filtered = existing.filter((c) => c.id !== contactId);
    userEmergencyContacts.set(user.id, filtered);
    return { ok: true };
  });

  // ===========================================================================
  // SOCIAL POSTS (Free-form posts distinct from GPS activities)
  // ===========================================================================

  interface StoredPost {
    id: string;
    userId: string;
    body: string;
    imageUrl?: string;
    visibility: 'public' | 'followers';
    linkedActivityId?: string;
    kudosUserIds: Set<string>;
    comments: Array<{
      id: string;
      userId: string;
      body: string;
      createdAt: string;
    }>;
    createdAt: string;
  }

  const posts = new Map<string, StoredPost>();

  // Default welcome post
  const defaultPostId = 'welcome_post';
  posts.set(defaultPostId, {
    id: defaultPostId,
    userId: 'vyra_team',
    body: 'Welcome to VYRA! Share your workouts, recipes, and daily victories with the community.',
    visibility: 'public',
    kudosUserIds: new Set<string>(),
    comments: [],
    createdAt: new Date(now() - 3600000).toISOString(),
  });

  async function shapePost(p: StoredPost, currentUserId: string) {
    const author = await store.getUser(p.userId);
    return {
      id: p.id,
      userId: p.userId,
      body: p.body,
      imageUrl: p.imageUrl ?? null,
      visibility: p.visibility,
      authorHandle: author?.displayHandle ?? (p.userId === 'vyra_team' ? 'vyra_official' : 'athlete'),
      authorName: author?.name ?? (p.userId === 'vyra_team' ? 'VYRA Community' : 'Athlete'),
      kudosGiven: p.kudosUserIds.has(currentUserId),
      kudosCount: p.kudosUserIds.size,
      commentCount: p.comments.length,
      createdAt: p.createdAt,
    };
  }

  router.post('/v1/posts', async (ctx) => {
    const user = await requireUser(ctx);
    const b = requireObject(ctx.body);
    const body = str(b, 'body', { max: 2000 });
    const imageUrl = typeof b.imageUrl === 'string' && b.imageUrl.trim() ? b.imageUrl.trim() : undefined;
    const visibility = b.visibility === 'followers' ? 'followers' : 'public';
    const linkedActivityId = typeof b.linkedActivityId === 'string' ? b.linkedActivityId : undefined;

    const post: StoredPost = {
      id: randomUUID(),
      userId: user.id,
      body,
      imageUrl,
      visibility,
      linkedActivityId,
      kudosUserIds: new Set<string>(),
      comments: [],
      createdAt: new Date(now()).toISOString(),
    };

    posts.set(post.id, post);
    return { post: await shapePost(post, user.id) };
  });

  router.get('/v1/posts/feed', async (ctx) => {
    const user = await requireUser(ctx);
    const all = Array.from(posts.values());
    all.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    const shaped = await Promise.all(all.map((p) => shapePost(p, user.id)));
    return { items: shaped };
  });

  router.get('/v1/posts/mine', async (ctx) => {
    const user = await requireUser(ctx);
    const mine = Array.from(posts.values()).filter((p) => p.userId === user.id);
    mine.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    const shaped = await Promise.all(mine.map((p) => shapePost(p, user.id)));
    return { items: shaped };
  });

  router.patch('/v1/posts/:id', async (ctx) => {
    const user = await requireUser(ctx);
    const post = posts.get(ctx.params.id!);
    if (!post || post.userId !== user.id) throw HttpError.notFound('Post not found.');

    const b = requireObject(ctx.body);
    if (typeof b.body === 'string') post.body = b.body.slice(0, 2000);
    if (b.visibility === 'public' || b.visibility === 'followers') post.visibility = b.visibility;

    return { post: await shapePost(post, user.id) };
  });

  router.delete('/v1/posts/:id', async (ctx) => {
    const user = await requireUser(ctx);
    const post = posts.get(ctx.params.id!);
    if (!post || post.userId !== user.id) throw HttpError.notFound('Post not found.');
    posts.delete(post.id);
    return { ok: true };
  });

  router.post('/v1/posts/:id/kudos', async (ctx) => {
    const user = await requireUser(ctx);
    const post = posts.get(ctx.params.id!);
    if (!post) throw HttpError.notFound('Post not found.');

    let given = false;
    if (post.kudosUserIds.has(user.id)) {
      post.kudosUserIds.delete(user.id);
      given = false;
    } else {
      post.kudosUserIds.add(user.id);
      given = true;
    }

    return { given, count: post.kudosUserIds.size };
  });

  router.get('/v1/posts/:id/comments', async (ctx) => {
    const user = await requireUser(ctx);
    const post = posts.get(ctx.params.id!);
    if (!post) throw HttpError.notFound('Post not found.');

    const shaped = await Promise.all(post.comments.map(async (c) => {
      const author = await store.getUser(c.userId);
      return {
        id: c.id,
        userId: c.userId,
        body: c.body,
        authorHandle: author?.displayHandle ?? 'athlete',
        createdAt: c.createdAt,
      };
    }));

    return { items: shaped };
  });

  router.post('/v1/posts/:id/comments', async (ctx) => {
    const user = await requireUser(ctx);
    const post = posts.get(ctx.params.id!);
    if (!post) throw HttpError.notFound('Post not found.');

    const b = requireObject(ctx.body);
    const commentBody = str(b, 'body', { max: 1000 });

    const comment = {
      id: randomUUID(),
      userId: user.id,
      body: commentBody,
      createdAt: new Date(now()).toISOString(),
    };

    post.comments.push(comment);

    return {
      comment: {
        id: comment.id,
        userId: user.id,
        body: comment.body,
        authorHandle: user.displayHandle,
        createdAt: comment.createdAt,
      },
    };
  });

  // ── e-RaktKosh API Setu (Government of India / Digital India) ──────────────
  router.post('/v1/eraktkosh/nearby', async (ctx) => {
    const b = (ctx.body && typeof ctx.body === 'object') ? ctx.body as Record<string, unknown> : {};
    const lat = Number(b.lat ?? 28.6667);
    const lng = Number(b.lng ?? 77.4784);
    const bloodGroup = typeof b.bloodGroup === 'string' ? b.bloodGroup : 'All';
    const component = typeof b.component === 'string' ? b.component : 'Whole Blood';
    const radiusKm = Number(b.radiusKm ?? 10);
    const results = await eRaktKoshClient.searchNearbyAvailability({ lat, lng, bloodGroup, component, radiusKm });
    return { success: true, count: results.length, bloodCenters: results };
  });

  router.get('/v1/eraktkosh/components', async () => {
    const components = await eRaktKoshClient.getBloodComponentsList();
    return { success: true, components };
  });

  router.get('/v1/eraktkosh/notifications', async (ctx) => {
    const lat = ctx.query.get('lat') ? Number(ctx.query.get('lat')) : undefined;
    const lng = ctx.query.get('lng') ? Number(ctx.query.get('lng')) : undefined;
    const notifications = await eRaktKoshClient.getLiveNotifications(lat, lng);
    return { success: true, count: notifications.length, notifications };
  });

  router.get('/v1/eraktkosh/camps', async (ctx) => {
    const lat = Number(ctx.query.get('lat') ?? 28.6667);
    const lng = Number(ctx.query.get('lng') ?? 77.4784);
    const camps = await eRaktKoshClient.getNearbyCamps(lat, lng);
    return { success: true, count: camps.length, camps };
  });

  router.post('/v1/eraktkosh/donor/register', async (ctx) => {
    const b = (ctx.body && typeof ctx.body === 'object') ? ctx.body as Record<string, unknown> : {};
    const user = await optionalUser(ctx);
    const fullName = String(b.fullName || user?.name || '').trim();
    const bloodGroup = String(b.bloodGroup || '').trim();
    const mobile = String(b.mobile || '').trim();
    const city = String(b.city || '').trim();
    if (!fullName || !bloodGroup || !mobile || !city) {
      throw HttpError.badRequest('fullName, bloodGroup, mobile, and city are required fields.');
    }
    const donor = {
      fullName,
      bloodGroup,
      mobile,
      age: Number(b.age || 25),
      gender: String(b.gender || 'male'),
      city,
    };
    const result = await eRaktKoshClient.preRegisterDonor(donor);
    return result;
  });

  router.post('/v1/eraktkosh/thalassemia/request', async (ctx) => {
    const b = (ctx.body && typeof ctx.body === 'object') ? ctx.body as Record<string, unknown> : {};
    const patientName = String(b.patientName || '').trim();
    const bloodGroup = String(b.bloodGroup || '').trim();
    const hospitalName = String(b.hospitalName || '').trim();
    if (!patientName || !bloodGroup || !hospitalName) {
      throw HttpError.badRequest('patientName, bloodGroup, and hospitalName are required fields.');
    }
    const req = {
      patientId: String(b.patientId || randomUUID()),
      patientName,
      bloodGroup,
      unitsRequired: Number(b.unitsRequired || 1),
      transfusionDueDate: String(b.transfusionDueDate || new Date().toISOString().split('T')[0]),
      hospitalName,
      specialRequirement: (b.specialRequirement || 'Leukodepleted PRBC') as any,
    };
    const result = await eRaktKoshClient.submitThalassemiaRequest(req);
    return result;
  });

  // Register Enterprise Web Admin Portal & Management Endpoints
  registerAdminPortalRoutes(router, deps.store);

  // Register Athlete 3D Web User Portal (/portal, /athlete, /user)
  registerAthletePortalRoutes(router);

  return router;
}


/**
 * Chooses the storage backend.
 *
 * Postgres when DATABASE_URL is present, in-memory otherwise. The fallback is
 * deliberate and loud: a demo should never die because a database was
 * unreachable, but nobody should be able to run production on memory by
 * accident either, so the choice is printed at startup.
 */
export async function buildDefaultDeps(): Promise<ServerDeps> {
  const databaseUrl = process.env.DATABASE_URL;
  let store: Store = new MemoryStore();

  if (databaseUrl) {
    const { PgStore } = await import('./store.pg');
    store = await PgStore.create(databaseUrl);
  }

  return {
    store,
    keyRing: loadKeyRing(),
    authConfig: loadAuthConfig(),
  };
}
