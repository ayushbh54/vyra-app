-- =============================================================================
-- VYRA — Movement definitions for the code-driven 3D exercise avatar.
--
-- One exercise can have at most one movement definition. The definition is
-- pure data (phases, joint-target angles, tempo, coaching cues) — the 3D
-- rig that renders it is shared code, not duplicated per exercise. This is
-- what lets "add a new animated exercise" mean "insert a row here", not
-- "write new rendering code".
--
-- No foreign key to the `exercises` table: that table is never actually
-- seeded (the real exercise library lives in code, in
-- services/api/src/content/exercises.ts, and is served from there
-- regardless of store backend) — `exercise_slug` here just needs to match
-- a slug from that file, checked in application code, not by the database.
-- =============================================================================

CREATE TABLE movement_definitions (
  exercise_slug   TEXT PRIMARY KEY,
  rig_id          TEXT NOT NULL DEFAULT 'humanoid_v1',
  tempo           TEXT NOT NULL,             -- e.g. '2-1-3-0' (eccentric-pause-concentric-pause)
  target_muscle   TEXT NOT NULL,
  phases          JSONB NOT NULL,            -- MovementPhase[] — see store.ts for the shape
  correct_mechanics JSONB NOT NULL DEFAULT '[]',
  avoid_cheats    JSONB NOT NULL DEFAULT '[]',
  camera_views    JSONB NOT NULL DEFAULT '["front"]',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
