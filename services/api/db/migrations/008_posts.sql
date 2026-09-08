-- =============================================================================
-- VYRA — Social posts (text/photo updates, separate from GPS activities).
-- An activity is a recorded run/ride; a post is a free-form update that can
-- optionally reference one of the user's own activities via linked_activity_id.
-- =============================================================================

CREATE TYPE post_visibility_t AS ENUM ('public', 'followers');

CREATE TABLE posts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body              TEXT NOT NULL,
  image_url         TEXT,
  visibility        post_visibility_t NOT NULL DEFAULT 'public',
  linked_activity_id UUID REFERENCES activities(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  edited_at         TIMESTAMPTZ
);
CREATE INDEX idx_posts_user_created ON posts (user_id, created_at DESC);

CREATE TABLE post_kudos (
  post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE post_comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_post_comments_post ON post_comments (post_id, created_at);
