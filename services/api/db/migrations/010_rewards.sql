-- =============================================================================
-- VYRA — Redemption catalog.
--
-- DESIGN DECISION: the task draft asked for new `rewards` + `reward_redemptions`
-- tables, but 001_init.sql already ships a `redemption_catalog` table that is
-- the same concept (id, title, description, coin_cost, stock, is_active) —
-- creating a second, parallel catalog table would fork "what a reward is" in
-- two places. This migration extends the existing table instead:
--   - adds `category` (the draft's grouping field; defaults to 'voucher')
--   - adds `created_at` (for sorting/display; the table didn't have one)
-- A separate `reward_redemptions` history table is also skipped: every coin
-- spend already lands in the existing append-only `coin_ledger` (source_type
-- = 'redemption', source_id = the catalog item id — see store.ts / store.pg.ts
-- for the LedgerRow.sourceId plumbing added alongside this migration). Adding
-- a second ledger for the same events would let the two disagree after a
-- partial failure; deriving redemption history from coin_ledger means there
-- is exactly one source of truth for "what did this user spend coins on".
-- =============================================================================

ALTER TABLE redemption_catalog ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'voucher';
ALTER TABLE redemption_catalog ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Guarded with WHERE NOT EXISTS (title) rather than this table's ON CONFLICT
-- DO NOTHING convention (redemption_catalog has no unique constraint to
-- target), so re-running this migration never creates duplicate rewards.
INSERT INTO redemption_catalog (title, description, coin_cost, category, stock, partner, is_active)
SELECT * FROM (VALUES
  ('VYRA 5K Event Pass', 'Free entry to any VYRA-hosted 5K event this quarter.', 400, 'event', 200::int, 'VYRA Events', true),
  ('VYRA Merch Voucher — T-Shirt', 'Redeem for one VYRA training tee, any size.', 250, 'merch', NULL::int, 'VYRA Store', true),
  ('1-on-1 Coaching Session', '30-minute video call with a VYRA-partnered coach.', 600, 'service', 50::int, 'VYRA Coaching', true),
  ('Protein Sample Pack', 'A 5-serving sample pack from a partner nutrition brand.', 150, 'nutrition', 300::int, 'Partner Nutrition Co.', true),
  ('Early Access Badge', 'Unlocks the "Early Access" profile badge — cosmetic only.', 80, 'cosmetic', NULL::int, NULL, true)
) AS seed(title, description, coin_cost, category, stock, partner, is_active)
WHERE NOT EXISTS (SELECT 1 FROM redemption_catalog rc WHERE rc.title = seed.title);
