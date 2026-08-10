-- ═══════════════════════════════════════════════════════════════════════════
--  Group G — the notifications READ half.
--
--  Stage 1 (20260802020000) built the record and the address. Nothing has ever
--  read `read_at`: there was no list, no unread count and no way for a diner to
--  see a notification at all. This migration is what the read half needs.
--
--  Two things, and they are unrelated to each other except in timing:
--
--    1. `idx_notif_user_unread` — the index doc 04 names, deliberately deferred
--       until something filtered on `read_at`. Something now does.
--    2. `dedupe_key` — "we already told them this", as a database fact.
--
--  Split of what is and is not in Group G:
--  `docs/decisions/2026-08-09-group-g-split.md`.
-- ═══════════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────────
--  1. THE INDEX DOC 04 NAMES. Deferred on 2026-08-09, built on 2026-08-09.
-- ───────────────────────────────────────────────────────────────────────────
--
-- The silent-lapse sweep found that stage 1 created
-- `idx_notifications_user (user_id, created_at DESC)` — a different name from
-- doc 04's, and NOT partial. CLAUDE.md rule 3 makes index names part of the
-- contract, so that was a real deviation; it was left because building a
-- partial index on `read_at` when nothing read `read_at` would have been an
-- index Postgres maintained on every insert to serve a query nobody made.
--
-- `GET /notifications` returns `unread_count`, and the notification centre
-- marks-on-open. Both filter on `read_at IS NULL`. So it goes in now, under
-- doc 04's name, and the exemption comes out of
-- `apps/api/test/schema-invariants.e2e-spec.ts` in the same commit — that test
-- fails if the index exists while the exemption is still listed, so the two
-- physically cannot drift.
--
-- `idx_notifications_user` STAYS. It serves "all my notifications, newest
-- first", which is the list itself and a different read.
CREATE INDEX idx_notif_user_unread
  ON notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

COMMENT ON INDEX idx_notif_user_unread IS
  'doc 04 §notifications. Partial: the unread set is a small, hot subset of a '
  'table that grows forever. Serves the unread badge and the centre''s '
  'mark-on-open. Built in Group G, when read_at was first read.';


-- ───────────────────────────────────────────────────────────────────────────
--  2. dedupe_key — "WE ALREADY TOLD THEM THIS", ENFORCED
-- ───────────────────────────────────────────────────────────────────────────
--
-- Group G introduces the first notifications produced by a SWEEPER rather than
-- by a request: the 24h/2h reminders, and the waitlist offer-expiry pass. Both
-- are at-least-once by construction — a sweeper that runs every 60s, an
-- interval that overlaps a slow tick, two API instances in a rolling deploy —
-- and a diner who is told three times that their table is tomorrow learns to
-- ignore us.
--
-- The alternative was a `SELECT ... WHERE NOT EXISTS` before each insert, which
-- is a check-then-act across two statements: two workers both find nothing and
-- both insert. This is the same lesson as the reservation engine's layer 3.
-- Make the database refuse it.
--
-- NULLABLE, and the index is PARTIAL, so ordinary event-driven notifications
-- (a venue cancelling a table twice in a night, legitimately) are unaffected.
-- Only a notification that CLAIMS uniqueness gets it.
ALTER TABLE notifications ADD COLUMN dedupe_key text;

CREATE UNIQUE INDEX idx_notifications_dedupe
  ON notifications (dedupe_key)
  WHERE dedupe_key IS NOT NULL;

COMMENT ON COLUMN notifications.dedupe_key IS
  'At most one notification per key, ever. For notifications emitted by a '
  'sweeper or a retryable job, where at-least-once delivery would otherwise '
  'mean a diner is told the same thing twice. Format: "<purpose>:<uuid>", e.g. '
  '"reminder_24h:<reservation_id>". NULL for event-driven notifications, which '
  'may legitimately repeat.';

COMMENT ON INDEX idx_notifications_dedupe IS
  'Partial UNIQUE. This is the enforcement, not the convention: a duplicate '
  'insert raises 23505 and NotificationsService treats that as "already told '
  'them" rather than as an error.';


-- ───────────────────────────────────────────────────────────────────────────
--  3. RLS — the layer that is NOT carried forward automatically
-- ───────────────────────────────────────────────────────────────────────────
--
-- `notifications` already has RLS enabled: the backfill in
-- 20260809010000_menus_and_reviews turned it on for the five tables the sweep
-- found without it. Nothing here creates a table, so there is nothing new to
-- enable — noted explicitly because `rls-coverage.e2e-spec.ts` asks pg_class
-- rather than reading these files, and a reader of this migration should not
-- have to wonder whether a step was skipped.
--
-- Same for `sahra_touch_updated_at`: `notifications` has no `updated_at`
-- column, by design. A notification is not edited. `schema-invariants` checks
-- the trigger in BOTH directions — every table with the column has it, and no
-- table without the column has it — so this absence is asserted, not assumed.
