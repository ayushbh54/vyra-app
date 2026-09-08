-- =============================================================================
-- VYRA — Challenge sub-types: daily check-in habit challenges (Zero Sugar,
-- Keto, Intermittent Fasting, 24hr Water, No Junk Food Week) plus
-- create-your-own challenges. Reuses the existing `challenges` and
-- `user_challenges` tables from 001_init.sql — only one new table is added,
-- to record which calendar day a user checked in for a given challenge
-- (needed for streak math and to make a check-in idempotent per day).
-- =============================================================================

CREATE TABLE challenge_checkins (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_challenge_id UUID NOT NULL REFERENCES user_challenges(id) ON DELETE CASCADE,
  check_date      DATE NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_challenge_id, check_date)
);
CREATE INDEX idx_challenge_checkins_uc ON challenge_checkins (user_challenge_id, check_date);

-- Preset habit challenges. criteria.metric = 'zero_sugar' is verified against
-- the user's actual sugar_logs (via the existing /v1/sugar system) rather
-- than a self-reported tap; every other preset here is a self-reported daily
-- check-in. target = number of days required (consecutive) to complete.
-- Guarded with WHERE NOT EXISTS instead of this table's existing
-- (unindexed) ON CONFLICT DO NOTHING convention, so re-running this
-- migration never creates duplicate presets.
INSERT INTO challenges (title, description, type, criteria, coin_reward, starts_at, ends_at, is_active)
SELECT * FROM (VALUES
  ('Zero Sugar Challenge',
   'Log a zero-added-sugar day, 7 days running.',
   'special'::challenge_type_t,
   '{"metric":"zero_sugar","target":7,"window":"streak"}'::jsonb,
   100, now(), now() + interval '90 days', true),
  ('Keto Diet Challenge',
   'Check in daily for 14 days while following a keto diet.',
   'special'::challenge_type_t,
   '{"metric":"daily_checkin","target":14,"window":"streak"}'::jsonb,
   140, now(), now() + interval '90 days', true),
  ('Intermittent Fasting Challenge',
   'Check in daily for 14 days of your fasting window.',
   'special'::challenge_type_t,
   '{"metric":"daily_checkin","target":14,"window":"streak"}'::jsonb,
   140, now(), now() + interval '90 days', true),
  ('24hr Water Challenge',
   'Check in once after a full 24-hour water-only water goal day.',
   'special'::challenge_type_t,
   '{"metric":"daily_checkin","target":1,"window":"streak"}'::jsonb,
   30, now(), now() + interval '90 days', true),
  ('No Junk Food Week',
   'Check in daily for 7 days with zero junk food.',
   'special'::challenge_type_t,
   '{"metric":"daily_checkin","target":7,"window":"streak"}'::jsonb,
   100, now(), now() + interval '90 days', true)
) AS seed(title, description, type, criteria, coin_reward, starts_at, ends_at, is_active)
WHERE NOT EXISTS (SELECT 1 FROM challenges c WHERE c.title = seed.title);
