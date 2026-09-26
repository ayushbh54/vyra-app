-- =============================================================================
-- VYRA — 013_datasets_and_ai_engine.sql
-- PostgreSQL 16+
--
-- This migration sets up all backend tables needed for:
--   • Indian food composition dataset (NIN)
--   • Biomarker reference ranges (NHANES/ICMR adapted for India)
--   • Exercise biomechanics dataset (joint angle thresholds per exercise)
--   • Disease-exercise contraindications (pathology combat engine)
--   • Blood donation eligibility + bank + request matching
--   • Nearby doctors (POI cache from NHA/OSM)
--   • Health report uploads + AI extracted biomarkers
--   • Motivational slogans (multilingual, categorised)
--   • Social contact hash registry (for WhatsApp-style friend discovery)
--   • Admin control panel (feature flags, subscriptions, vouchers, tickets)
--   • Ad impression tracking (AdMob revenue)
--   • Transformation photo records (before/after AI)
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- ENUMS (new ones only)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TYPE biomarker_status_t AS ENUM ('normal', 'borderline_low', 'low', 'borderline_high', 'high', 'critical');
CREATE TYPE blood_group_t      AS ENUM ('A+','A-','B+','B-','AB+','AB-','O+','O-');
CREATE TYPE doctor_specialty_t AS ENUM (
  'general', 'cardiologist', 'orthopedic', 'dermatologist', 'nutritionist',
  'gynecologist', 'endocrinologist', 'dentist', 'hematologist',
  'hepatologist', 'psychiatrist', 'physiotherapist', 'ophthalmologist',
  'nephrologist', 'pulmonologist'
);
CREATE TYPE slogan_category_t AS ENUM (
  'morning_fire', 'midday_push', 'afternoon_grind', 'evening_warrior',
  'night_champion', 'rest_day_recharge', 'streak_milestone',
  'goal_achieved', 'comeback', 'blood_donation', 'challenge_win'
);
CREATE TYPE ticket_status_t   AS ENUM ('open','in_progress','waiting_user','resolved','closed','escalated');
CREATE TYPE ticket_priority_t AS ENUM ('low','medium','high','critical');
CREATE TYPE feature_flag_t    AS ENUM ('global','platform','region','user','percentage');
CREATE TYPE ad_type_t         AS ENUM ('banner','interstitial','rewarded','native');
CREATE TYPE subscription_tier_t AS ENUM ('free','pro','elite','lifetime');

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. INDIAN FOOD COMPOSITION DATASET (NIN-based)
--    Source: National Institute of Nutrition, Hyderabad + Open Food Facts India
--    Load via: backend seed script (see scripts/seed_food_db.ts)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE food_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_en          TEXT NOT NULL,
  name_hi          TEXT,
  name_local       JSONB,                      -- {"ta":"...", "te":"...", "ml":"..."}
  category         TEXT NOT NULL,              -- 'cereal','dal','vegetable','fruit','dairy','meat','snack'
  barcode          TEXT UNIQUE,                -- EAN-13 for packaged items
  per_100g_kcal    NUMERIC(7,2) NOT NULL,
  per_100g_protein NUMERIC(7,2) NOT NULL,
  per_100g_carbs   NUMERIC(7,2) NOT NULL,
  per_100g_fat     NUMERIC(7,2) NOT NULL,
  per_100g_fiber   NUMERIC(7,2),
  per_100g_iron    NUMERIC(7,2),
  per_100g_calcium NUMERIC(7,2),
  per_100g_vit_d   NUMERIC(7,2),
  per_100g_vit_b12 NUMERIC(7,2),
  allergens        TEXT[],                     -- ['gluten','dairy','nuts','eggs','soy','seafood']
  is_veg           BOOLEAN NOT NULL DEFAULT TRUE,
  is_vegan         BOOLEAN NOT NULL DEFAULT FALSE,
  glycemic_index   SMALLINT,                   -- 0-100
  data_source      TEXT NOT NULL DEFAULT 'NIN',
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_food_category    ON food_items (category);
CREATE INDEX idx_food_barcode     ON food_items (barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_food_name_search ON food_items USING gin(to_tsvector('english', name_en));

COMMENT ON TABLE food_items IS
  'Primary food composition database. Seed from NIN (National Institute of Nutrition) '
  'Indian Food Composition Tables 2017 + Open Food Facts India subset. '
  'Download: https://www.nin.res.in/ifct2017.html';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. BIOMARKER REFERENCE RANGES
--    Indian population norms (adapted from ICMR + WHO for Indian physiology)
--    These ARE different from Western norms (lower Vit D normal range, etc.)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE biomarker_reference (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT NOT NULL,               -- 'HGB','WBC','PLT','GLU','HBA1C','CHOL'...
  name_en         TEXT NOT NULL,
  unit            TEXT NOT NULL,               -- 'g/dL','mg/dL','10^3/uL'...
  normal_min      NUMERIC(10,3),
  normal_max      NUMERIC(10,3),
  borderline_low  NUMERIC(10,3),               -- below normal but not critical
  borderline_high NUMERIC(10,3),
  critical_low    NUMERIC(10,3),
  critical_high   NUMERIC(10,3),
  gender_specific BOOLEAN NOT NULL DEFAULT FALSE,
  gender          TEXT,                        -- 'male'|'female'|NULL
  age_min         SMALLINT,                    -- NULL = all ages
  age_max         SMALLINT,
  population      TEXT NOT NULL DEFAULT 'india',
  clinical_note   TEXT,                        -- what high/low means clinically
  diet_note       TEXT,                        -- dietary intervention
  exercise_note   TEXT,                        -- exercise contraindication
  UNIQUE (code, gender, age_min, age_max, population)
);

COMMENT ON TABLE biomarker_reference IS
  'Reference ranges calibrated for Indian population. '
  'Key differences from Western norms: '
  '  Vit D: Indians often <20 ng/mL (vs Western 30+ = normal) '
  '  Hb: Indian women normal = 11.5 g/dL (WHO), but ICMR uses 12 '
  '  Fasting glucose: Indian T2D threshold = 110 mg/dL (stricter) '
  'Source: ICMR National Nutrient Requirements 2020, WHO South-East Asia norms.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. EXERCISE BIOMECHANICS DATASET
--    Joint angle thresholds for correct form per exercise
--    Powers the on-device pose tracking rep counter
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE exercise_biomechanics (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exercise_key    TEXT NOT NULL UNIQUE,        -- 'bicep_curl','squat','pushup','deadlift'
  name_en         TEXT NOT NULL,
  joint           TEXT NOT NULL,               -- 'elbow','knee','hip','shoulder'
  landmark_a      SMALLINT NOT NULL,           -- MediaPipe landmark index (0-32)
  landmark_b      SMALLINT NOT NULL,           -- vertex of the angle
  landmark_c      SMALLINT NOT NULL,
  rep_start_deg   NUMERIC(5,1) NOT NULL,       -- angle at start position (extended)
  rep_end_deg     NUMERIC(5,1) NOT NULL,       -- angle at peak (flexed)
  form_tolerance  NUMERIC(4,1) NOT NULL DEFAULT 15.0, -- degrees allowed deviation
  feedback_bad    TEXT NOT NULL,               -- "Lower your hips more"
  feedback_good   TEXT NOT NULL,               -- "Perfect! Keep going"
  muscle_group    TEXT[],                      -- ['biceps','brachialis']
  kcal_per_rep    NUMERIC(5,3),                -- avg calories per rep (varies by weight)
  met_value       NUMERIC(4,2),                -- MET for calorie calculation
  contraindicated TEXT[]                       -- conditions where this is dangerous
);

COMMENT ON TABLE exercise_biomechanics IS
  'Drives the on-device AI rep counter. landmark_a/b/c are MediaPipe Pose '
  'landmark indices (0-32). Angle = angle at landmark_b between a-b-c. '
  'Rep counted when angle crosses from rep_start_deg to rep_end_deg and back. '
  'If deviation from ideal form > form_tolerance → rep NOT counted + voice feedback.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. DISEASE-EXERCISE PATHOLOGY TABLE
--    Powers the "Combat Specific Disease" mode
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE pathology_protocols (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  condition_key       TEXT NOT NULL UNIQUE,    -- 'fatty_liver','pcos','pre_diabetes','hypertension'
  condition_name_en   TEXT NOT NULL,
  condition_name_hi   TEXT,
  condition_names     JSONB,                   -- multilingual
  recommended_types   TEXT[],                  -- ['yoga','walking','resistance','hiit']
  avoided_types       TEXT[],                  -- ['high_impact','heavy_lifting']
  weekly_min_minutes  SMALLINT,                -- minimum weekly exercise
  weekly_max_minutes  SMALLINT,               -- cap to avoid overtraining
  diet_restrictions   TEXT[],                  -- ['refined_sugar','saturated_fat']
  diet_encouraged     TEXT[],                  -- ['fiber','omega3','antioxidants']
  biomarkers_to_watch TEXT[],                  -- ['HBA1C','GLU','CHOL','TG']
  plan_duration_days  SMALLINT DEFAULT 90,
  gemini_system_prompt TEXT,                   -- Specialized prompt for this condition's plan
  evidence_links      TEXT[],                  -- PubMed / WHO guideline URLs
  updated_at          TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE pathology_protocols IS
  'Evidence-based exercise + diet protocols for specific medical conditions. '
  'Used by Gemini to generate personalised 90-day combat plans. '
  'Seed from AIIMS guidelines, WHO SEARO, and ICMR disease burden data.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. HEALTH REPORT UPLOADS + AI EXTRACTED BIOMARKERS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE health_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  report_date   DATE NOT NULL,
  lab_name      TEXT,
  file_url      TEXT,                          -- S3/R2 signed URL
  upload_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  ai_processed  BOOLEAN NOT NULL DEFAULT FALSE,
  ai_summary    TEXT,                          -- Gemini narrative summary
  ai_insights   JSONB,                         -- [{insight, severity, action}]
  raw_text      TEXT                           -- OCR extracted text (for re-analysis)
);

CREATE TABLE health_report_biomarkers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id     UUID NOT NULL REFERENCES health_reports(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  biomarker_code TEXT NOT NULL,               -- matches biomarker_reference.code
  value         NUMERIC(10,3) NOT NULL,
  unit          TEXT NOT NULL,
  status        biomarker_status_t NOT NULL,
  lab_ref_min   NUMERIC(10,3),               -- lab's own printed range
  lab_ref_max   NUMERIC(10,3),
  recorded_at   DATE NOT NULL
);
CREATE INDEX idx_hrb_user_code ON health_report_biomarkers (user_id, biomarker_code, recorded_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. USER ALLERGY + CONDITION PROFILE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE user_health_profile (
  user_id             UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  blood_group         blood_group_t,
  allergies           TEXT[],                 -- ['nuts','dairy','gluten','eggs','soy','seafood']
  medical_conditions  TEXT[],                 -- ['diabetes','hypertension','thyroid','pcos','asthma']
  current_medications TEXT[],
  last_donation_date  DATE,
  is_donation_eligible BOOLEAN,
  donation_check_at   TIMESTAMPTZ,
  body_fat_pct        NUMERIC(4,1),
  resting_hr          SMALLINT,               -- beats/min
  vo2_max             NUMERIC(5,2),           -- ml/kg/min
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. BLOOD DONATION ENGINE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE blood_banks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  address       TEXT NOT NULL,
  city          TEXT NOT NULL,
  state         TEXT NOT NULL,
  phone         TEXT,
  lat           NUMERIC(9,6) NOT NULL,
  lng           NUMERIC(9,6) NOT NULL,
  hours         TEXT,                          -- "Mon-Sat 8am-6pm"
  is_verified   BOOLEAN NOT NULL DEFAULT FALSE,
  last_synced   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_blood_banks_geo ON blood_banks USING gist(
  ll_to_earth(lat::float8, lng::float8)
);

CREATE TABLE blood_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blood_group     blood_group_t NOT NULL,
  units_needed    SMALLINT NOT NULL DEFAULT 1,
  hospital_name   TEXT NOT NULL,
  contact_phone   TEXT NOT NULL,
  lat             NUMERIC(9,6) NOT NULL,
  lng             NUMERIC(9,6) NOT NULL,
  city            TEXT NOT NULL,
  is_urgent       BOOLEAN NOT NULL DEFAULT FALSE,
  is_fulfilled    BOOLEAN NOT NULL DEFAULT FALSE,
  posted_by       UUID REFERENCES users(id),  -- NULL = admin/hospital
  expires_at      TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_blood_requests_geo ON blood_requests USING gist(
  ll_to_earth(lat::float8, lng::float8)
);
CREATE INDEX idx_blood_requests_active ON blood_requests (blood_group, is_fulfilled)
  WHERE is_fulfilled = FALSE AND expires_at > now();

CREATE TABLE blood_donation_raised_hands (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  request_id  UUID NOT NULL REFERENCES blood_requests(id) ON DELETE CASCADE,
  raised_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  connected   BOOLEAN NOT NULL DEFAULT FALSE,  -- hospital confirmed contact
  UNIQUE (user_id, request_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. NEARBY DOCTORS POI CACHE
--    Refreshed daily from NHA registry + Google Places API
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE doctors (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  specialty     doctor_specialty_t NOT NULL,
  clinic_name   TEXT,
  address       TEXT NOT NULL,
  city          TEXT NOT NULL,
  phone         TEXT,
  lat           NUMERIC(9,6) NOT NULL,
  lng           NUMERIC(9,6) NOT NULL,
  rating        NUMERIC(3,2),                 -- 0.00-5.00
  review_count  INTEGER NOT NULL DEFAULT 0,
  available_today BOOLEAN NOT NULL DEFAULT FALSE,
  consultation_fee_inr INTEGER,
  accepts_online BOOLEAN NOT NULL DEFAULT FALSE,
  photo_url     TEXT,
  external_id   TEXT,                         -- Google Place ID or NHA reg no
  data_source   TEXT NOT NULL DEFAULT 'nha', -- 'nha','google_places','manual'
  last_synced   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_doctors_geo       ON doctors USING gist(ll_to_earth(lat::float8, lng::float8));
CREATE INDEX idx_doctors_specialty ON doctors (specialty, city);
CREATE INDEX idx_doctors_rating    ON doctors (rating DESC NULLS LAST);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. SOCIAL CONTACT HASH REGISTRY
--    WhatsApp-style friend discovery — never stores raw phone numbers
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE contact_hashes (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  phone_hash  TEXT NOT NULL,                  -- SHA256(normalised_e164_phone)
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, phone_hash)
);
CREATE INDEX idx_contact_hash_lookup ON contact_hashes (phone_hash);

COMMENT ON TABLE contact_hashes IS
  'Never stores raw phone numbers. Client hashes numbers with SHA256 before '
  'sending. Server only does hash-to-hash lookup. GDPR/PDPB compliant.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. MOTIVATIONAL SLOGANS (multilingual seed data)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE motivational_slogans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category    slogan_category_t NOT NULL,
  language    TEXT NOT NULL,                  -- 'hi','en','ta','te' etc.
  text        TEXT NOT NULL,
  emoji       TEXT,                           -- '🔥','💪','⚡','🌟'
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_slogans_cat_lang ON motivational_slogans (category, language) WHERE is_active = TRUE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. TRANSFORMATION PHOTOS (Before / After AI)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE transformation_photos (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  before_url    TEXT NOT NULL,                -- user's actual selfie (encrypted at rest)
  after_url     TEXT,                         -- AI-generated future projection
  taken_at      DATE NOT NULL DEFAULT CURRENT_DATE,
  week_number   SMALLINT NOT NULL DEFAULT 0,  -- 0=initial, 4=month1, 8=month2...
  ai_body_type  TEXT,                         -- 'ectomorph','mesomorph','endomorph'
  ai_estimate   JSONB,                        -- {body_fat_pct_est, muscle_mass_est}
  is_public     BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_transform_user ON transformation_photos (user_id, taken_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. ADMIN CONTROL PANEL — FEATURE FLAGS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE feature_flags (
  key           TEXT PRIMARY KEY,             -- 'pose_tracking','blood_donation','ads_enabled'
  enabled       BOOLEAN NOT NULL DEFAULT TRUE,
  flag_type     feature_flag_t NOT NULL DEFAULT 'global',
  platforms     TEXT[],                       -- ['ios','android'] — NULL = all
  regions       TEXT[],                       -- ['IN','US'] — NULL = all
  rollout_pct   SMALLINT DEFAULT 100 CHECK (rollout_pct BETWEEN 0 AND 100),
  description   TEXT,
  updated_by    TEXT,                         -- admin username
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Per-user feature overrides (for support agents)
CREATE TABLE user_feature_overrides (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  flag_key    TEXT NOT NULL REFERENCES feature_flags(key) ON DELETE CASCADE,
  enabled     BOOLEAN NOT NULL,
  reason      TEXT,                           -- "support ticket #1234"
  set_by      TEXT NOT NULL,                  -- admin username
  expires_at  TIMESTAMPTZ,                    -- NULL = permanent
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, flag_key)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. SUBSCRIPTIONS + OFFERS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE subscription_plans (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL UNIQUE,       -- 'pro_monthly','elite_yearly','lifetime'
  tier            subscription_tier_t NOT NULL,
  price_inr       INTEGER NOT NULL,           -- in paise (100 = ₹1)
  duration_days   INTEGER,                    -- NULL = lifetime
  trial_days      SMALLINT NOT NULL DEFAULT 7,
  features        TEXT[],                     -- feature flag keys included
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_subscriptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id         UUID NOT NULL REFERENCES subscription_plans(id),
  tier            subscription_tier_t NOT NULL,
  started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at      TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  payment_ref     TEXT,                       -- Razorpay/Google Pay order ID
  granted_by      TEXT,                       -- 'payment'|'promo'|admin_username
  note            TEXT                        -- support override reason
);
CREATE INDEX idx_subscriptions_user ON user_subscriptions (user_id, is_active) WHERE is_active = TRUE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. VOUCHERS + COUPONS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE vouchers (
  code            TEXT PRIMARY KEY,           -- 'VYRA50','BLOOD2024'
  description     TEXT NOT NULL,
  discount_type   TEXT NOT NULL,              -- 'percent'|'fixed_inr'|'free_days'
  discount_value  INTEGER NOT NULL,           -- percent / paise / days
  max_uses        INTEGER,                    -- NULL = unlimited
  used_count      INTEGER NOT NULL DEFAULT 0,
  plan_ids        UUID[],                     -- NULL = all plans
  valid_from      TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until     TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_by      TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE voucher_redemptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_code TEXT NOT NULL REFERENCES vouchers(code),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  redeemed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (voucher_code, user_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. SUPPORT TICKETS (Customer Care)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE support_tickets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number   SERIAL UNIQUE,              -- human-readable: #1001, #1002...
  user_id         UUID REFERENCES users(id),
  subject         TEXT NOT NULL,
  description     TEXT NOT NULL,
  category        TEXT NOT NULL,              -- 'subscription','bug','account','feature'
  status          ticket_status_t NOT NULL DEFAULT 'open',
  priority        ticket_priority_t NOT NULL DEFAULT 'medium',
  assigned_to     TEXT,                       -- admin username
  resolution      TEXT,
  tags            TEXT[],
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at     TIMESTAMPTZ
);
CREATE INDEX idx_tickets_status   ON support_tickets (status, priority, created_at DESC);
CREATE INDEX idx_tickets_user     ON support_tickets (user_id, created_at DESC);
CREATE INDEX idx_tickets_assigned ON support_tickets (assigned_to) WHERE status NOT IN ('closed','resolved');

CREATE TABLE support_ticket_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id   UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL,                  -- 'user'|'agent'|'system'
  sender_id   TEXT NOT NULL,                  -- user_id or admin_username
  body        TEXT NOT NULL,
  attachments JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. AD IMPRESSION TRACKING
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE ad_impressions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  ad_type       ad_type_t NOT NULL,
  placement     TEXT NOT NULL,                -- 'post_workout','rest_timer','feed'
  ad_unit_id    TEXT,                         -- AdMob unit ID
  revenue_usd   NUMERIC(10,6),               -- filled post-event by webhook
  shown_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed     BOOLEAN NOT NULL DEFAULT FALSE -- rewarded: did user watch fully?
);
CREATE INDEX idx_ad_user_day ON ad_impressions (user_id, shown_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. MAINTENANCE + SYSTEM STATUS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE system_status (
  key         TEXT PRIMARY KEY,               -- 'maintenance_mode','api_status','ios_min_version'
  value       TEXT NOT NULL,
  description TEXT,
  updated_by  TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed essential system status keys
INSERT INTO system_status (key, value, description) VALUES
  ('maintenance_mode', 'false', 'When true: all API calls return 503 with maintenance message'),
  ('maintenance_message', 'VYRA is under maintenance. We will be back shortly!', 'Shown to users during maintenance'),
  ('ios_min_version', '1.0.0', 'Minimum iOS app version — below this, force update screen shown'),
  ('android_min_version', '1.0.0', 'Minimum Android version'),
  ('ads_enabled', 'true', 'Global ad kill switch'),
  ('blood_donation_enabled', 'true', 'Blood donation feature toggle'),
  ('pose_tracking_enabled', 'true', 'AI pose tracking feature toggle'),
  ('registration_open', 'true', 'Can new users sign up');

-- ─────────────────────────────────────────────────────────────────────────────
-- SEED: Exercise Biomechanics (MediaPipe Pose landmark indices)
-- Reference: https://developers.google.com/mediapipe/solutions/vision/pose_landmarker
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO exercise_biomechanics
  (exercise_key, name_en, joint, landmark_a, landmark_b, landmark_c,
   rep_start_deg, rep_end_deg, form_tolerance, feedback_bad, feedback_good,
   muscle_group, kcal_per_rep, met_value) VALUES
('bicep_curl',     'Bicep Curl',      'elbow',    12, 14, 16, 160, 30,  15, 'Keep your elbow tucked — don''t swing!',        'Great curl! Full range of motion.',       ARRAY['biceps','brachialis'],             0.085, 3.5),
('squat',          'Squat',           'knee',     24, 26, 28, 170, 70,  12, 'Go lower — hips below knee level.',             'Perfect squat depth! Chest up.',          ARRAY['quadriceps','glutes','hamstrings'], 0.32,  5.0),
('pushup',         'Push-up',         'elbow',    12, 14, 16, 170, 90,  15, 'Lower your chest closer to the floor.',        'Great push-up! Full range.',              ARRAY['pectorals','triceps','shoulders'],  0.29,  3.8),
('deadlift',       'Deadlift',        'hip',      12, 24, 26, 170, 60,  10, 'Keep your back straight — don''t round!',       'Perfect form! Hinge at the hips.',        ARRAY['hamstrings','glutes','lower_back'], 0.55,  6.0),
('shoulder_press', 'Shoulder Press',  'elbow',    12, 14, 16, 90,  170, 12, 'Full lockout — extend arms completely.',       'Excellent! Arms fully extended.',         ARRAY['deltoids','triceps'],              0.18,  4.0),
('lunge',          'Lunge',           'knee',     24, 26, 28, 170, 90,  12, 'Front knee shouldn''t pass your toes.',        'Good lunge! Back knee close to floor.',   ARRAY['quadriceps','glutes'],             0.28,  4.5),
('plank',          'Plank (timed)',   'hip',      12, 24, 26, 175, 170, 8,  'Keep your hips level — don''t sag or pike!', 'Solid plank! Core engaged.',              ARRAY['core','transverse_abdominis'],     0.06,  3.5),
('jumping_jack',   'Jumping Jack',    'shoulder', 24, 12, 14, 20,  160, 20, 'Full arm extension overhead.',                'Great jack! Arms all the way up.',        ARRAY['full_body','cardio'],              0.15,  8.0),
('tricep_dip',     'Tricep Dip',      'elbow',    12, 14, 16, 90,  170, 15, 'Lower until arms are at 90° before pushing.', 'Full dip! Triceps fully engaged.',        ARRAY['triceps','chest'],                0.22,  3.5),
('lat_raise',      'Lateral Raise',   'shoulder', 24, 12, 16, 10,  90,  12, 'Don''t swing — slow controlled raise.',       'Perfect raise! Arms parallel to floor.',  ARRAY['lateral_deltoids'],               0.08,  3.0);

-- ─────────────────────────────────────────────────────────────────────────────
-- SEED: Pathology Protocols
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO pathology_protocols
  (condition_key, condition_name_en, condition_name_hi,
   recommended_types, avoided_types,
   weekly_min_minutes, weekly_max_minutes,
   diet_restrictions, diet_encouraged,
   biomarkers_to_watch, plan_duration_days) VALUES
('fatty_liver',   'Fatty Liver Disease',   'फैटी लिवर',
  ARRAY['walking','yoga','light_resistance','cycling'],
  ARRAY['heavy_lifting','alcohol_related'],
  150, 300,
  ARRAY['refined_sugar','saturated_fat','fried_food','alcohol'],
  ARRAY['fiber','omega3','green_vegetables','antioxidants'],
  ARRAY['ALT','AST','TG','LDL'], 90),

('pcos',          'Polycystic Ovary Syndrome', 'पीसीओएस',
  ARRAY['resistance_training','hiit','yoga','pilates'],
  ARRAY['extreme_caloric_restriction'],
  150, 270,
  ARRAY['refined_carbs','sugar','dairy_excess'],
  ARRAY['low_gi_foods','fiber','protein','anti_inflammatory'],
  ARRAY['LH','FSH','INSULIN','TESTOSTERONE'], 90),

('pre_diabetes',  'Pre-Diabetes',          'प्री-डायबिटीज',
  ARRAY['walking','resistance','yoga','swimming'],
  ARRAY['intense_fasting_exercise'],
  150, 300,
  ARRAY['refined_sugar','white_rice','maida','sugary_drinks'],
  ARRAY['fiber','complex_carbs','lean_protein','cinnamon'],
  ARRAY['GLU','HBA1C','INSULIN'], 90),

('hypertension',  'Hypertension',          'हाई ब्लड प्रेशर',
  ARRAY['walking','yoga','swimming','light_cycling'],
  ARRAY['heavy_lifting','breath_holding_exercises','hot_yoga'],
  150, 240,
  ARRAY['salt','processed_food','alcohol','caffeine_excess'],
  ARRAY['potassium','magnesium','fiber','omega3'],
  ARRAY['SYST_BP','DIAST_BP','SODIUM'], 90),

('hypothyroid',   'Hypothyroidism',        'हाइपोथायरॉइडिज्म',
  ARRAY['resistance_training','hiit','yoga'],
  ARRAY['extreme_endurance'],
  200, 350,
  ARRAY['goitrogens_raw','soy_excess','gluten_if_hashimotos'],
  ARRAY['selenium','iodine','zinc','vitamin_d'],
  ARRAY['TSH','T3','T4','SELENIUM'], 90),

('anemia',        'Iron Deficiency Anemia','एनीमिया',
  ARRAY['light_yoga','walking','breathing_exercises'],
  ARRAY['hiit','heavy_resistance','breath_holding'],
  90, 200,
  ARRAY['tea_with_meals','calcium_with_iron'],
  ARRAY['iron_rich','vitamin_c_with_iron','folate','b12'],
  ARRAY['HGB','MCH','FERRITIN','SERUM_IRON'], 60);

-- ─────────────────────────────────────────────────────────────────────────────
-- SEED: Feature Flags
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO feature_flags (key, enabled, description) VALUES
  ('pose_tracking',         TRUE,  'AI camera-based rep counter + form validation'),
  ('blood_donation',        TRUE,  'Blood donation eligibility + nearby matching'),
  ('nearby_doctors',        TRUE,  'Nearby doctor suggestions by specialty'),
  ('health_report_ai',      TRUE,  'Blood report upload + Gemini AI analysis'),
  ('transformation_photos', TRUE,  'Before/After AI physique projection'),
  ('social_leaderboard',    TRUE,  'Friends leaderboard with contact sync'),
  ('multilingual',          TRUE,  'Multi-language support (17 languages)'),
  ('admob_ads',             TRUE,  'In-app AdMob advertisements'),
  ('rewarded_ads',          TRUE,  'Rewarded video ads between exercises'),
  ('subscription_pro',      TRUE,  'VYRA Pro subscription tier'),
  ('subscription_elite',    TRUE,  'VYRA Elite subscription tier'),
  ('motivational_slogans',  TRUE,  'Daily motivational push notifications'),
  ('pathology_combat',      TRUE,  'Disease-specific 90-day workout plans'),
  ('custom_diet_framework', TRUE,  'User-chosen diet framework (Keto/IF etc.)'),
  ('fantasy_physique',      TRUE,  '3D avatar with 180° interactive viewport'),
  ('elevation_tracking',    TRUE,  'Barometric altitude sensor for terrain detection');

COMMIT;
