-- =============================================================================
-- VYRA — Groups layer: club posts, events, and a Strava-style primary sport
-- on the profile. Clubs themselves already exist from 001_init.sql.
-- =============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS primary_sport TEXT NOT NULL DEFAULT 'run';

CREATE TABLE club_posts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id       UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body          TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_club_posts_club ON club_posts (club_id, created_at DESC);

CREATE TABLE events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL,
  sport         TEXT NOT NULL DEFAULT 'run',
  location      TEXT NOT NULL,
  starts_at     TIMESTAMPTZ NOT NULL,
  club_id       UUID REFERENCES clubs(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE event_registrations (
  event_id      UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, user_id)
);

-- A handful of seed clubs and events so Groups is never an empty screen on
-- a fresh install — the same reasoning as the 46-item exercise library.
INSERT INTO clubs (name, description, interest_tag, member_count) VALUES
  ('Morning Runners', 'Early risers who log a run before the day starts.', 'running', 1),
  ('Yoga Practitioners', 'Daily asana practice, all levels welcome.', 'yoga', 1),
  ('Weekend Cyclists', 'Long rides on Saturdays, easy pace on Sundays.', 'cycling', 1)
ON CONFLICT DO NOTHING;

INSERT INTO events (title, sport, location, starts_at) VALUES
  ('VYRA 5K Challenge', 'run', 'Citywide — track anywhere', now() + interval '7 days'),
  ('Sunday Long Ride', 'ride', 'Local cycling group meetup', now() + interval '3 days')
ON CONFLICT DO NOTHING;
