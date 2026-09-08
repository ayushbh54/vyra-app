-- =============================================================================
-- VYRA — Email+password signup, as a reliable path that doesn't depend on
-- external OAuth credentials. Google/Facebook/WhatsApp OTP (auth_identities,
-- already in 001_init.sql) remain available once those provider keys are
-- added to .env — this is additive, not a replacement.
-- =============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;
