-- =============================================================================
-- VYRA — AI Fitness Chat message log.
--
-- Deliberately NOT the same schema as conversations/messages (004_messaging.sql).
-- Those model user<->user DMs, where a conversation has multiple participants
-- and needs its own row. AI chat is always exactly one user talking to the
-- assistant, so there is no conversation/participant indirection — just an
-- append-only, per-user log, closer in shape to a single-user timeline.
-- =============================================================================

CREATE TABLE ai_chat_messages (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role          TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  body          TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ai_chat_user_created ON ai_chat_messages (user_id, created_at);
