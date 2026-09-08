-- =============================================================================
-- VYRA — Trust & safety primitives, modeled on how Strava's own reporting
-- actually works (researched from their Help Center): a report always goes
-- into a human review queue — never a silent automated takedown — and
-- blocking is separate from unfollowing.
-- =============================================================================

CREATE TYPE report_target_t AS ENUM ('activity', 'club_post', 'message', 'user', 'comment');
CREATE TYPE report_status_t AS ENUM ('pending', 'reviewing', 'resolved', 'dismissed');
CREATE TYPE report_reason_t AS ENUM (
  'spam', 'harassment', 'inappropriate_content', 'unwanted_contact',
  'impersonation', 'safety_concern', 'other'
);

CREATE TABLE reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_type   report_target_t NOT NULL,
  target_id     TEXT NOT NULL,
  reason        report_reason_t NOT NULL,
  detail        TEXT,
  status        report_status_t NOT NULL DEFAULT 'pending',
  resolved_by   UUID REFERENCES admin_users(id),
  resolution    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at   TIMESTAMPTZ
);
CREATE INDEX idx_reports_pending ON reports (created_at) WHERE status = 'pending';
CREATE INDEX idx_reports_target ON reports (target_type, target_id);

CREATE TABLE blocks (
  blocker_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);
