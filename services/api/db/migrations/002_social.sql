-- =============================================================================
-- VYRA — Social / Record layer
-- Adds: GPS-recorded activities (the Record tab), kudos, comments, and a
-- Beacon on/off flag on the user row. Follow uses the existing friend_edges
-- table; safety contacts reuse the existing emergency_contacts table.
-- =============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS beacon_enabled BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE activities (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type          TEXT NOT NULL DEFAULT 'run',       -- 'run'|'ride'|'walk'|'other'
  title         TEXT NOT NULL,
  distance_m    NUMERIC(10,1) NOT NULL DEFAULT 0,
  duration_sec  INTEGER NOT NULL DEFAULT 0,
  route         JSONB NOT NULL DEFAULT '[]',        -- [{lat,lng,t}, ...]
  started_at    TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_activities_user_created ON activities (user_id, created_at DESC);

CREATE TABLE activity_kudos (
  activity_id   UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (activity_id, user_id)
);

CREATE TABLE activity_comments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id   UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body          TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_activity_comments_activity ON activity_comments (activity_id, created_at);
