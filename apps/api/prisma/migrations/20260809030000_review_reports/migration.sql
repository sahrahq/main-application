-- ═══════════════════════════════════════════════════════════════════════════
--  review_reports — C-4.4's report flow. RECORDING WITH NO READER.
--
--  Accepted on these terms, in the product owner's words:
--
--    > `review_reports` without a queue is accepted on the same terms as the
--    > waitlist's join-without-notify: **recording with no reader,
--    > deliberately**, with the reader arriving in A-3.
--
--  The queue is A-3 (admin content moderation, P1) and is not built. Nothing in
--  this migration or the service above it reads a report. That is a decision,
--  not an unfinished edge — the same shape as `WaitlistService`, whose docblock
--  says "nothing here offers anybody a table" and has stopped anyone since
--  mistaking the missing half for a bug.
--
--  Why record before there is a reader: the alternative is a published review
--  with no way to flag it. Reviews are `published` by default (there is no
--  moderator to queue them behind), and published-by-default with no report
--  path is the combination that hurts. A report recorded today is a report the
--  moderator reads on their first day; a report that was never offered is a
--  diner who gave up.
-- ═══════════════════════════════════════════════════════════════════════════


-- doc 04 has no table for this — C-4.4 and A-3 both assume one. The name and
-- the shape are ours, recorded in
-- `docs/decisions/2026-08-09-group-d-schema-proposal.md` §2.8 and §5.4.
CREATE TYPE report_reason AS ENUM (
  -- Deliberately short, and deliberately not a free-text-only field. A reason
  -- picked from five is a reason a moderator can sort a queue by; a paragraph
  -- is one they have to read first.
  'spam',
  'abusive',
  -- "This is not my visit" — the one that is about US rather than about the
  -- reviewer. A review attached to the wrong reservation is a bug in our
  -- verified-diner guarantee and needs finding, not moderating.
  'not_my_visit',
  'wrong_venue',
  'other'
);

CREATE TYPE report_status AS ENUM ('open', 'upheld', 'rejected');

CREATE TABLE review_reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  review_id        UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  reporter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  reason           report_reason NOT NULL,

  -- Optional, and capped. A moderator reading a queue needs the reason; the
  -- note is for the case the five values do not cover.
  note             TEXT,

  status           report_status NOT NULL DEFAULT 'open',

  -- Set together by A-3, when there is somebody to set them. Both NULL until
  -- then, which is the honest representation of "nobody has looked".
  resolved_by      UUID REFERENCES users(id) ON DELETE SET NULL,
  resolved_at      TIMESTAMPTZ(6),

  created_at       TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

-- ══ THE WHOLE DESIGN IS THIS INDEX ══
--
-- One person cannot brigade a review alone. Without it, a single account could
-- file fifty reports against one review and make it look like fifty people
-- objected — which is exactly what an automated triage rule would key on, and
-- exactly the shape of abuse a report queue attracts.
--
-- One report per person per review. A second press is the same report.
CREATE UNIQUE INDEX idx_review_reports_unique
  ON review_reports (review_id, reporter_user_id);

-- The queue read A-3 will make: open reports, oldest first. PARTIAL, because a
-- resolved report is history and the queue is a working list — and because the
-- resolved rows will eventually outnumber the open ones by a wide margin.
CREATE INDEX idx_review_reports_open
  ON review_reports (created_at)
  WHERE status = 'open';

-- "How many people reported this review" without reading the table. The venue
-- page does not use it; A-3's triage will.
CREATE INDEX idx_review_reports_review
  ON review_reports (review_id, status);

ALTER TABLE review_reports ADD CONSTRAINT review_reports_note_length
  CHECK (note IS NULL OR char_length(btrim(note)) BETWEEN 1 AND 1000);

-- Same tie-the-pair shape as `reviews_reply_has_timestamp` and
-- `waitlists_offer_has_expiry`. A resolution with no resolver is a decision
-- nobody made; a resolver with no timestamp is one that happened at no time.
ALTER TABLE review_reports ADD CONSTRAINT review_reports_resolution_paired
  CHECK ((resolved_by IS NULL) = (resolved_at IS NULL));

-- AND AN OPEN REPORT IS NOT RESOLVED. Without this, `status = 'open'` with a
-- `resolved_at` would satisfy the constraint above and sit in the queue index
-- forever looking unhandled.
ALTER TABLE review_reports ADD CONSTRAINT review_reports_open_is_unresolved
  CHECK ((status = 'open') = (resolved_at IS NULL));


-- ═══════════════════════════════════════════════════════════════════════════
--  The two things a new table has to be given, because nothing gives them
--  automatically
-- ═══════════════════════════════════════════════════════════════════════════

-- RLS. There is no `ALTER DEFAULT PRIVILEGES` equivalent for this — that is the
-- lapse the sweep found, and this is the first table created since. If it were
-- forgotten, `rls-coverage.e2e-spec.ts` would fail rather than three batches
-- passing.
ALTER TABLE public.review_reports ENABLE ROW LEVEL SECURITY;

-- The updated_at trigger. The DO block in `20260809020000_no_silent_lapses`
-- looped over the tables that existed WHEN IT RAN; a table created afterwards
-- has to be attached by hand. Postgres event triggers would do it
-- automatically but need superuser, which `postgres` is not on Supabase.
--
-- `schema-invariants.e2e-spec.ts` is what makes that residue survivable: it
-- asks whether every table with an `updated_at` column has this trigger, so
-- forgetting this line is a failing test rather than a column that quietly
-- stops moving.
CREATE TRIGGER trg_touch_updated_at
  BEFORE UPDATE ON public.review_reports
  FOR EACH ROW EXECUTE FUNCTION public.sahra_touch_updated_at();


-- ═══════════════════════════════════════════════════════════════════════════
--  A CORRECTION TO THE GROUP D SCHEMA DOC
--
--  `docs/decisions/2026-08-09-group-d-schema-proposal.md` §2.4 said:
--
--    > 'pending_moderation' therefore means what its name says — a state a
--    > REPORT moves a review into — rather than the front door.
--
--  **That is wrong, and building this is what showed it.** A report does NOT
--  change `reviews.status`, and must not.
--
--  The venue page reads `status = 'published'` and the rating trigger averages
--  the same set. So a single report moving a review to `pending_moderation`
--  would remove it from the venue's page and from its rating — meaning ONE
--  account could silence any review, with no moderator to release it. That is
--  the brigading the UNIQUE index above exists to prevent, achieved through
--  the front door instead.
--
--  So a report is a record and nothing else. The review stays published until
--  a human looks at it, which is A-3's job. Asserted by
--  `review-reports.e2e-spec.ts`, which reports a review and then checks its
--  status, its presence on the venue page, and the venue's rating are all
--  unchanged.
-- ═══════════════════════════════════════════════════════════════════════════
