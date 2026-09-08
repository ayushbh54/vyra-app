-- =============================================================================
-- VYRA — 001_init.sql
-- PostgreSQL 16+. Region: ap-south-1 (Mumbai) for India data localisation.
--
-- ENCRYPTION NOTE
-- Biometric / health-adjacent values are stored as BYTEA holding an
-- AES-256-GCM envelope produced by the API layer (see services/api/src/crypto).
-- We deliberately do NOT use pgcrypto's pgp_sym_encrypt with an in-DB key,
-- because that would place the key inside the same trust boundary as the data.
-- The key lives in a managed vault (KMS/Secrets Manager) and never touches SQL.
-- Each envelope is prefixed with a key-version byte so keys can be rotated.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "citext";     -- case-insensitive email/handle

-- -----------------------------------------------------------------------------
-- ENUMS
-- -----------------------------------------------------------------------------
CREATE TYPE gender_t          AS ENUM ('male', 'female', 'other', 'prefer_not_to_say');
CREATE TYPE fitness_goal_t    AS ENUM ('lose_weight', 'gain_weight', 'maintain', 'general_wellness');
CREATE TYPE diet_pref_t       AS ENUM ('veg_no_egg', 'veg_with_egg', 'non_veg');
CREATE TYPE auth_provider_t   AS ENUM ('google', 'facebook', 'whatsapp_otp');
CREATE TYPE block_type_t      AS ENUM ('class', 'work', 'sleep', 'commute', 'free');
CREATE TYPE exercise_cat_t    AS ENUM ('exercise', 'yoga', 'special', 'breathing', 'meditation');
CREATE TYPE difficulty_t      AS ENUM ('beginner', 'intermediate', 'advanced');
CREATE TYPE plan_status_t     AS ENUM ('pending', 'partial', 'completed', 'missed', 'rest');
CREATE TYPE meal_type_t       AS ENUM ('breakfast', 'morning_snack', 'lunch', 'evening_snack', 'dinner');
CREATE TYPE challenge_type_t  AS ENUM ('daily', 'weekly', 'special');
CREATE TYPE user_challenge_t  AS ENUM ('joined', 'in_progress', 'completed', 'expired', 'abandoned');
CREATE TYPE tier_t            AS ENUM ('bronze', 'silver', 'gold', 'platinum', 'diamond');
CREATE TYPE consent_t         AS ENUM (
  'health_data_storage', 'camera_food_scan', 'location_city_mode',
  'facebook_social_graph', 'push_notifications', 'wearable_sync',
  'physique_projection'
);
CREATE TYPE admin_role_t      AS ENUM ('super_admin', 'content_manager', 'support_agent', 'compliance_auditor');
CREATE TYPE erasure_status_t  AS ENUM ('received', 'verifying', 'processing', 'completed', 'rejected');
CREATE TYPE account_status_t  AS ENUM ('active', 'flagged', 'suspended', 'banned', 'deleted');

-- -----------------------------------------------------------------------------
-- USERS
-- -----------------------------------------------------------------------------
CREATE TABLE users (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  display_handle      CITEXT UNIQUE NOT NULL,          -- shown on the WORLD leaderboard (never real name)
  name                TEXT NOT NULL,
  email               CITEXT UNIQUE,
  phone_e164          TEXT UNIQUE,                     -- WhatsApp OTP identity
  dob                 DATE NOT NULL,
  gender              gender_t NOT NULL,
  height_cm           NUMERIC(5,2) NOT NULL CHECK (height_cm BETWEEN 50 AND 260),
  weight_kg           NUMERIC(5,2) NOT NULL CHECK (weight_kg BETWEEN 15 AND 400),
  disability_flag     BOOLEAN NOT NULL DEFAULT FALSE,
  disability_detail   TEXT,
  accessibility_mode  BOOLEAN NOT NULL DEFAULT FALSE,  -- swaps content set to seated/low-impact
  fitness_goal        fitness_goal_t NOT NULL,
  diet_toggle         BOOLEAN NOT NULL DEFAULT TRUE,
  diet_preference     diet_pref_t NOT NULL,
  locale              TEXT NOT NULL DEFAULT 'en-IN',
  timezone            TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  city                TEXT,
  campus              TEXT,
  onboarding_step     SMALLINT NOT NULL DEFAULT 0,     -- 0..9, 9 = complete (resume-state)
  account_status      account_status_t NOT NULL DEFAULT 'active',
  signup_date         TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active         TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at          TIMESTAMPTZ,
  CONSTRAINT dob_sane CHECK (dob > '1900-01-01' AND dob < CURRENT_DATE)
);
CREATE INDEX idx_users_last_active ON users (last_active DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_city        ON users (city) WHERE city IS NOT NULL;
CREATE INDEX idx_users_status      ON users (account_status) WHERE account_status <> 'active';

COMMENT ON COLUMN users.display_handle IS
  'Pseudonymous handle used on public/world leaderboards. Real name is never exposed publicly.';

-- Auth identities: one user may link Google + Facebook + phone.
CREATE TABLE auth_identities (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider       auth_provider_t NOT NULL,
  provider_uid   TEXT NOT NULL,
  linked_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_uid)
);
CREATE INDEX idx_auth_identities_user ON auth_identities (user_id);

-- Device registry — powers anti-fraud device-consistency checks + push delivery.
CREATE TABLE user_devices (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id      TEXT NOT NULL,
  platform       TEXT NOT NULL,
  push_token     TEXT,
  first_seen     TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen      TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_flagged     BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (user_id, device_id)
);
CREATE INDEX idx_devices_device_id ON user_devices (device_id);

-- -----------------------------------------------------------------------------
-- CONSENT & AUDIT  (DPDP Act 2023)
-- -----------------------------------------------------------------------------
-- Append-only. A withdrawal is a NEW row with granted = FALSE, never an UPDATE,
-- so the full consent history is reconstructable for an audit.
CREATE TABLE consent_records (
  id            BIGSERIAL PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type  consent_t NOT NULL,
  granted       BOOLEAN NOT NULL,
  policy_version TEXT NOT NULL,
  locale        TEXT NOT NULL,
  ip_hash       TEXT,                                  -- salted SHA-256, never a raw IP
  user_agent    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_consent_user_type ON consent_records (user_id, consent_type, created_at DESC);

-- Fast lookup of "what is true right now" without scanning history.
CREATE VIEW current_consents AS
SELECT DISTINCT ON (user_id, consent_type)
       user_id, consent_type, granted, policy_version, created_at
FROM consent_records
ORDER BY user_id, consent_type, created_at DESC;

-- Admin action trail. Retained 7 years, WORM-style (no UPDATE/DELETE grants in prod).
CREATE TABLE audit_log (
  id            BIGSERIAL PRIMARY KEY,
  actor_id      UUID,
  actor_role    admin_role_t,
  action        TEXT NOT NULL,
  target_type   TEXT,
  target_id     TEXT,
  reason        TEXT,
  metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_actor  ON audit_log (actor_id, created_at DESC);
CREATE INDEX idx_audit_target ON audit_log (target_type, target_id, created_at DESC);

CREATE TABLE erasure_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status        erasure_status_t NOT NULL DEFAULT 'received',
  requested_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  sla_due_at    TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 days'),
  completed_at  TIMESTAMPTZ,
  handled_by    UUID,
  notes         TEXT
);
CREATE INDEX idx_erasure_open ON erasure_requests (sla_due_at) WHERE status <> 'completed';

-- -----------------------------------------------------------------------------
-- SCHEDULE  (input to dead-time detection)
-- -----------------------------------------------------------------------------
CREATE TABLE schedule_blocks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  weekday      SMALLINT NOT NULL CHECK (weekday BETWEEN 0 AND 6),   -- 0 = Monday
  block_start  TIME NOT NULL,
  block_end    TIME NOT NULL,
  block_type   block_type_t NOT NULL,
  label        TEXT,
  CONSTRAINT block_order CHECK (block_end > block_start)
);
CREATE INDEX idx_schedule_user_day ON schedule_blocks (user_id, weekday);

COMMENT ON TABLE schedule_blocks IS
  'Declared commitments. Gaps between blocks are candidate windows for micro-workouts. '
  'Notifications must never be scheduled inside a sleep or class block.';

-- -----------------------------------------------------------------------------
-- CONTENT LIBRARY
-- -----------------------------------------------------------------------------
CREATE TABLE exercises (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              TEXT UNIQUE NOT NULL,
  name              TEXT NOT NULL,
  category          exercise_cat_t NOT NULL,
  subcategory       TEXT NOT NULL,          -- 'abs' | 'face_yoga' | 'hiit' | 'box_breathing' ...
  body_parts        TEXT[] NOT NULL DEFAULT '{}',
  muscles           TEXT[] NOT NULL DEFAULT '{}',
  difficulty        difficulty_t NOT NULL DEFAULT 'beginner',
  video_url         TEXT,
  gif_url           TEXT,
  thumbnail_url     TEXT,
  instructions      TEXT[] NOT NULL DEFAULT '{}',
  audio_script      TEXT,                   -- trainer voice-over script (TTS or recorded)
  audio_url         TEXT,
  transcript        TEXT,                   -- accessibility: full text of audio-led sessions
  default_duration_sec INTEGER NOT NULL DEFAULT 45 CHECK (default_duration_sec > 0),
  default_reps      INTEGER,
  met_value         NUMERIC(4,2) NOT NULL DEFAULT 3.5,  -- calories computed, never hardcoded
  equipment         TEXT[] NOT NULL DEFAULT '{}',
  contraindications TEXT[] NOT NULL DEFAULT '{}',
  is_seated_friendly     BOOLEAN NOT NULL DEFAULT FALSE,  -- Accessibility Mode content set
  is_low_impact          BOOLEAN NOT NULL DEFAULT FALSE,
  is_recovery_for        TEXT[] NOT NULL DEFAULT '{}',    -- 'knee' | 'lower_back' | 'shoulder' ...
  unlock_level      SMALLINT NOT NULL DEFAULT 0,          -- 0 = always free. Safety content stays 0.
  is_published      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_exercises_cat      ON exercises (category, subcategory) WHERE is_published;
CREATE INDEX idx_exercises_recovery ON exercises USING GIN (is_recovery_for);
CREATE INDEX idx_exercises_body     ON exercises USING GIN (body_parts);

-- Guardrail: recovery and accessibility content can never sit behind a grind wall.
ALTER TABLE exercises ADD CONSTRAINT safety_content_never_locked
  CHECK (unlock_level = 0 OR (cardinality(is_recovery_for) = 0 AND is_seated_friendly = FALSE));

-- -----------------------------------------------------------------------------
-- WORKOUT PLANS
-- -----------------------------------------------------------------------------
CREATE TABLE workout_plans (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_date     DATE NOT NULL,
  status        plan_status_t NOT NULL DEFAULT 'pending',
  scheduled_at  TIMESTAMPTZ,                -- the dead-time window the engine picked
  is_rebalanced BOOLEAN NOT NULL DEFAULT FALSE,
  generated_by  TEXT NOT NULL DEFAULT 'rule_engine_v1',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at  TIMESTAMPTZ,
  UNIQUE (user_id, plan_date)
);
CREATE INDEX idx_plans_user_date ON workout_plans (user_id, plan_date DESC);

CREATE TABLE workout_plan_entries (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id       UUID NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
  exercise_id   UUID NOT NULL REFERENCES exercises(id),
  position      SMALLINT NOT NULL,
  duration_sec  INTEGER NOT NULL CHECK (duration_sec > 0),
  reps          INTEGER,
  sets          SMALLINT NOT NULL DEFAULT 1,
  is_completed  BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at  TIMESTAMPTZ,
  moved_from_date DATE,                     -- set when rebalanced out of a missed day
  UNIQUE (plan_id, position)
);
CREATE INDEX idx_plan_entries_plan ON workout_plan_entries (plan_id);

-- -----------------------------------------------------------------------------
-- FOOD & DIET
-- -----------------------------------------------------------------------------
CREATE TABLE food_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  barcode       TEXT UNIQUE,
  source        TEXT NOT NULL DEFAULT 'internal',   -- 'internal'|'openfoodfacts'|'fatsecret'|'ai_estimate'
  serving_size  NUMERIC(8,2) NOT NULL,
  unit          TEXT NOT NULL DEFAULT 'g',
  calories      NUMERIC(8,2) NOT NULL,
  protein_g     NUMERIC(7,2) NOT NULL DEFAULT 0,
  fat_g         NUMERIC(7,2) NOT NULL DEFAULT 0,
  carbs_g       NUMERIC(7,2) NOT NULL DEFAULT 0,
  fiber_g       NUMERIC(7,2) NOT NULL DEFAULT 0,
  sugar_g       NUMERIC(7,2) NOT NULL DEFAULT 0,
  micronutrients JSONB NOT NULL DEFAULT '{}'::jsonb,
  allergens     TEXT[] NOT NULL DEFAULT '{}',
  contains_egg  BOOLEAN NOT NULL DEFAULT FALSE,
  contains_meat BOOLEAN NOT NULL DEFAULT FALSE,
  is_verified   BOOLEAN NOT NULL DEFAULT FALSE,      -- FALSE for AI estimates until user confirms
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_food_name    ON food_items USING GIN (to_tsvector('simple', name));
CREATE INDEX idx_food_barcode ON food_items (barcode) WHERE barcode IS NOT NULL;

CREATE TABLE diet_plans (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_date     DATE NOT NULL,
  target_calories  INTEGER NOT NULL,
  target_protein_g INTEGER NOT NULL,
  target_fat_g     INTEGER NOT NULL,
  target_carbs_g   INTEGER NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, plan_date)
);

CREATE TABLE meal_entries (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  diet_plan_id  UUID NOT NULL REFERENCES diet_plans(id) ON DELETE CASCADE,
  meal_type     meal_type_t NOT NULL,
  is_logged     BOOLEAN NOT NULL DEFAULT FALSE,
  logged_at     TIMESTAMPTZ,
  source        TEXT NOT NULL DEFAULT 'plan'          -- 'plan'|'food_scan'|'barcode'|'manual'
);
CREATE INDEX idx_meal_entries_plan ON meal_entries (diet_plan_id);

CREATE TABLE meal_entry_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_entry_id UUID NOT NULL REFERENCES meal_entries(id) ON DELETE CASCADE,
  food_item_id  UUID NOT NULL REFERENCES food_items(id),
  quantity      NUMERIC(8,2) NOT NULL DEFAULT 1,
  user_corrected BOOLEAN NOT NULL DEFAULT FALSE       -- TRUE when the user fixed an AI guess
);

CREATE TABLE recipes (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES users(id) ON DELETE CASCADE,  -- NULL = curated/global
  title          TEXT NOT NULL,
  ingredients    JSONB NOT NULL,
  steps          TEXT[] NOT NULL,
  cook_time_min  SMALLINT,
  diet_preference diet_pref_t NOT NULL,
  contains_egg   BOOLEAN NOT NULL DEFAULT FALSE,
  contains_meat  BOOLEAN NOT NULL DEFAULT FALSE,
  nutrition      JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_ai_generated BOOLEAN NOT NULL DEFAULT FALSE,
  region_tag     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Server-side enforcement of the diet filter — the prompt alone is not trusted.
ALTER TABLE recipes ADD CONSTRAINT recipe_diet_consistency CHECK (
  (diet_preference = 'veg_no_egg'   AND contains_egg = FALSE AND contains_meat = FALSE) OR
  (diet_preference = 'veg_with_egg' AND contains_meat = FALSE) OR
  (diet_preference = 'non_veg')
);

-- -----------------------------------------------------------------------------
-- HEALTH TRACKING  (encrypted at column level)
-- -----------------------------------------------------------------------------
CREATE TABLE tracking_records (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  record_date   DATE NOT NULL,
  -- Non-sensitive aggregates stay in plaintext so we can index/aggregate them.
  water_ml      INTEGER CHECK (water_ml BETWEEN 0 AND 20000),
  steps         INTEGER CHECK (steps BETWEEN 0 AND 200000),
  -- Biometric values: AES-256-GCM envelopes written by the API layer.
  heart_rate_enc   BYTEA,
  bp_systolic_enc  BYTEA,
  bp_diastolic_enc BYTEA,
  spo2_enc         BYTEA,
  glucose_enc      BYTEA,
  weight_enc       BYTEA,
  key_version   SMALLINT NOT NULL DEFAULT 1,
  source        TEXT NOT NULL DEFAULT 'manual',   -- 'manual'|'google_fit'|'healthkit'
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, record_date)
);
CREATE INDEX idx_tracking_user_date ON tracking_records (user_id, record_date DESC);

COMMENT ON TABLE tracking_records IS
  'Reference data only — not medical-grade. Biometric columns are app-encrypted; '
  'plaintext steps/water are retained for leaderboard scoring and are not diagnostic.';

CREATE TABLE sugar_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  log_date      DATE NOT NULL,
  sugar_grams   NUMERIC(6,2) NOT NULL DEFAULT 0 CHECK (sugar_grams >= 0),
  note          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, log_date)
);

CREATE TABLE streaks (
  user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  workout_current SMALLINT NOT NULL DEFAULT 0,
  workout_best    SMALLINT NOT NULL DEFAULT 0,
  zero_sugar_current SMALLINT NOT NULL DEFAULT 0,
  zero_sugar_best    SMALLINT NOT NULL DEFAULT 0,
  last_workout_date  DATE,
  last_zero_sugar_date DATE
);

-- -----------------------------------------------------------------------------
-- CHALLENGES & COIN ECONOMY  (earned only — there is no purchase path anywhere)
-- -----------------------------------------------------------------------------
CREATE TABLE challenges (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  description   TEXT NOT NULL,
  type          challenge_type_t NOT NULL,
  criteria      JSONB NOT NULL,             -- {"metric":"steps","target":8000,"window":"day"}
  coin_reward   INTEGER NOT NULL CHECK (coin_reward BETWEEN 0 AND 1000),
  starts_at     TIMESTAMPTZ NOT NULL,
  ends_at       TIMESTAMPTZ NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_by    UUID,
  CONSTRAINT challenge_window CHECK (ends_at > starts_at)
);
CREATE INDEX idx_challenges_active ON challenges (type, starts_at) WHERE is_active;

CREATE TABLE user_challenges (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  challenge_id  UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  status        user_challenge_t NOT NULL DEFAULT 'joined',
  progress      NUMERIC(10,2) NOT NULL DEFAULT 0,
  joined_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at  TIMESTAMPTZ,
  UNIQUE (user_id, challenge_id)
);

-- Append-only ledger. Balance is a SUM, never a stored mutable number.
-- There is no 'purchase' reason and no code path that writes one.
CREATE TABLE coin_ledger (
  id            BIGSERIAL PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delta         INTEGER NOT NULL CHECK (delta <> 0),
  reason        TEXT NOT NULL,
  source_type   TEXT NOT NULL,              -- 'workout'|'streak'|'challenge'|'zero_sugar'|'redemption'
  source_id     TEXT,
  idempotency_key TEXT UNIQUE,              -- stops double-award on retry
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_coin_ledger_user ON coin_ledger (user_id, created_at DESC);

ALTER TABLE coin_ledger ADD CONSTRAINT no_purchase_source
  CHECK (source_type IN ('workout','streak','challenge','zero_sugar','redemption','admin_adjustment'));

CREATE TABLE redemption_catalog (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  description   TEXT NOT NULL,
  coin_cost     INTEGER NOT NULL CHECK (coin_cost > 0),
  stock         INTEGER,
  partner       TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_by    UUID
);

CREATE TABLE unlockables (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind          TEXT NOT NULL,              -- 'program'|'masterclass'|'avatar'|'theme'
  title         TEXT NOT NULL,
  required_level SMALLINT NOT NULL DEFAULT 1,
  required_coins INTEGER NOT NULL DEFAULT 0,
  payload       JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- -----------------------------------------------------------------------------
-- SOCIAL & LEADERBOARD
-- -----------------------------------------------------------------------------
-- Postgres holds the durable truth; Redis sorted sets serve the reads.
CREATE TABLE leaderboard_scores (
  id             BIGSERIAL PRIMARY KEY,
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  period_key     TEXT NOT NULL,             -- '2026-W36' | '2026-09'
  activity_points INTEGER NOT NULL DEFAULT 0,
  consistency_factor NUMERIC(4,3) NOT NULL DEFAULT 1.000,  -- rewards daily > binge
  tier           tier_t NOT NULL DEFAULT 'bronze',
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, period_key)
);
CREATE INDEX idx_leaderboard_period ON leaderboard_scores (period_key, activity_points DESC);

CREATE TABLE friend_edges (
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source         TEXT NOT NULL DEFAULT 'facebook',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, friend_user_id),
  CONSTRAINT no_self_friend CHECK (user_id <> friend_user_id)
);

CREATE TABLE clubs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  description   TEXT,
  interest_tag  TEXT NOT NULL,
  member_count  INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE club_members (
  club_id       UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (club_id, user_id)
);

-- Group challenges expose ONLY aggregate progress to members.
CREATE TABLE group_challenges (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_type    TEXT NOT NULL,              -- 'city'|'campus'
  scope_value   TEXT NOT NULL,
  title         TEXT NOT NULL,
  metric        TEXT NOT NULL,              -- 'steps'|'workouts'
  target_value  BIGINT NOT NULL,
  current_value BIGINT NOT NULL DEFAULT 0,
  starts_at     TIMESTAMPTZ NOT NULL,
  ends_at       TIMESTAMPTZ NOT NULL
);

-- -----------------------------------------------------------------------------
-- EMERGENCY
-- -----------------------------------------------------------------------------
CREATE TABLE emergency_contacts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  phone_e164    TEXT NOT NULL,
  relationship  TEXT,
  priority      SMALLINT NOT NULL DEFAULT 1,
  UNIQUE (user_id, phone_e164)
);

CREATE TABLE sos_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lat           NUMERIC(9,6),
  lng           NUMERIC(9,6),
  accuracy_m    NUMERIC(7,2),
  confirmed     BOOLEAN NOT NULL DEFAULT FALSE,   -- false = user cancelled during countdown
  contacts_notified SMALLINT NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- ADMIN / RBAC
-- -----------------------------------------------------------------------------
CREATE TABLE admin_users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         CITEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  password_hash TEXT NOT NULL,              -- argon2id
  role          admin_role_t NOT NULL,
  totp_secret_enc BYTEA,                    -- MFA mandatory for every admin role
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_by    UUID REFERENCES admin_users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_login    TIMESTAMPTZ
);

CREATE TABLE fraud_flags (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rule          TEXT NOT NULL,              -- 'steps_rate_of_change'|'device_shared'|'impossible_pace'
  severity      SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
  evidence      JSONB NOT NULL DEFAULT '{}'::jsonb,
  reviewed_by   UUID REFERENCES admin_users(id),   -- human-in-the-loop, never a silent auto-ban
  review_outcome TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at   TIMESTAMPTZ
);
CREATE INDEX idx_fraud_unreviewed ON fraud_flags (created_at DESC) WHERE reviewed_by IS NULL;

CREATE TABLE system_flags (
  key           TEXT PRIMARY KEY,           -- 'maintenance_mode'
  value         JSONB NOT NULL,
  updated_by    UUID REFERENCES admin_users(id),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO system_flags (key, value) VALUES ('maintenance_mode', 'false'::jsonb);

COMMIT;
