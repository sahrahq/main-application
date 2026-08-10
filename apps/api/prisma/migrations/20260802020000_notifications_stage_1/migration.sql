-- NOTIFY-1 Stage 1 — a notification exists whether or not delivery works.
--
-- Two tables, and the split between them is the point.
--
-- `notifications` is the RECORD: we owed this diner this message. It is
-- written in the same breath as the event that caused it, and it survives
-- every delivery failure — a push that never arrives, a token that went stale,
-- an FCM outage. It is what the in-app centre reads (C-4.7) and what answers
-- "did we tell them?" six weeks later.
--
-- `devices` is the ADDRESS: where a push could be sent right now. Addresses
-- rot. A phone is wiped, an app is reinstalled, a handset is sold. Storing the
-- address inside the record would mean the record rotted with it.

CREATE TABLE devices (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- The FCM registration token. UNIQUE, so a reinstall or a handset passed to
  -- a new owner MOVES the token rather than duplicating it — see the note on
  -- the partial index below for why that matters so much.
  token        text NOT NULL UNIQUE,
  platform     varchar(16) NOT NULL,
  locale       varchar(5)  NOT NULL DEFAULT 'ar',
  last_seen_at timestamptz(6) NOT NULL DEFAULT now(),
  -- Set on sign-out. A push token left attached to a signed-out user sends
  -- that person's reservation to whoever holds the handset next, which on a
  -- shared or resold phone is a privacy incident and not an annoyance.
  revoked_at   timestamptz(6),
  created_at   timestamptz(6) NOT NULL DEFAULT now(),
  updated_at   timestamptz(6) NOT NULL DEFAULT now()
);

-- Only LIVE devices are ever sent to, and they are a small subset of the rows
-- that accumulate over a user's lifetime.
CREATE INDEX idx_devices_live ON devices (user_id) WHERE revoked_at IS NULL;

COMMENT ON COLUMN devices.token IS
  'FCM registration token. UNIQUE so a reinstall moves it between users '
  'rather than leaving two rows, one of which would push a stranger''s '
  'reservation to a handset its previous owner no longer has.';

CREATE TABLE notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- Machine-readable, like the doc 06 §1 error codes and for the same reason:
  -- the CLIENT owns its copy and its tone. `data` carries the substitutions.
  type        varchar(60) NOT NULL,
  data        jsonb NOT NULL DEFAULT '{}'::jsonb,

  -- The three timestamps answer three different questions, and collapsing any
  -- two of them loses one of the answers:
  created_at  timestamptz(6) NOT NULL DEFAULT now(),  -- we owed them this
  sent_at     timestamptz(6),                          -- a push left the building
  read_at     timestamptz(6),                          -- they saw it

  -- Why a send failed, kept for the operator rather than the diner. Delivery
  -- is the part that breaks; the fact that we owed someone a message is not
  -- allowed to break with it.
  delivery_error text
);

CREATE INDEX idx_notifications_user ON notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_unsent ON notifications (created_at)
  WHERE sent_at IS NULL;

COMMENT ON TABLE notifications IS
  'NOTIFY-1. The record that a diner was owed a message, independent of '
  'whether delivery succeeded. Written in the same breath as the event.';
