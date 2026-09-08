-- =============================================================================
-- VYRA — General-purpose emergency contacts, distinguished from Beacon's
-- live-location contacts. Both reuse the existing `emergency_contacts` table
-- (001_init.sql); `purpose` tells them apart so a Beacon update can no longer
-- overwrite a user's general emergency contacts and vice versa.
--
-- IMPORTANT: this migration also requires PgStore.setBeacon/getBeacon to be
-- scoped to purpose = 'beacon' (see the store.pg.ts patch) — otherwise
-- Beacon's existing "delete all, reinsert up to 3" behaviour would wipe out
-- general contacts the very first time a user touches Beacon. That store.pg.ts
-- change ships together with this migration, not as a separate step.
-- =============================================================================

ALTER TABLE emergency_contacts ADD COLUMN IF NOT EXISTS purpose TEXT NOT NULL DEFAULT 'general';
ALTER TABLE emergency_contacts ADD CONSTRAINT emergency_contacts_purpose_check
  CHECK (purpose IN ('general', 'beacon'));

-- The original UNIQUE (user_id, phone_e164) would block saving the same
-- number for both purposes (e.g. a spouse as both a Beacon contact and a
-- general emergency contact). Widen it to include purpose.
ALTER TABLE emergency_contacts DROP CONSTRAINT IF EXISTS emergency_contacts_user_id_phone_e164_key;
ALTER TABLE emergency_contacts ADD CONSTRAINT emergency_contacts_user_phone_purpose_key
  UNIQUE (user_id, phone_e164, purpose);
