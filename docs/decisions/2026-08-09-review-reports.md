# `review_reports` — recording with no reader

**Date:** 2026-08-09
**Covers:** C-4.4's report flow. The queue is A-3 and is **not built.**
**Estimate given:** half a batch, not migration-heavy. That held.

---

## 1. The terms it was accepted under

> `review_reports` without a queue is accepted on the same terms as the
> waitlist's join-without-notify: **recording with no reader, deliberately**,
> with the reader arriving in A-3.

That sentence is now in three places a developer will actually hit:
`ReviewReportsService`'s docblock, the migration header, and the endpoint's own
doc comment. `WaitlistService` carries the equivalent — *"nothing here offers
anybody a table"* — and it is why nobody has since mistaken that missing half
for a bug.

**Why record before there is a reader.** Reviews are `published` by default,
because a moderation queue with no moderator does not moderate reviews — it
silently never publishes any. Published-by-default with no way to flag anything
is the combination that hurts. A report recorded today is one the moderator
reads on their first day; a report that was never offered is a diner who gave
up on us.

**And it is a checkable decision, not a promise.** `review-reports.e2e-spec.ts`
asserts that **exactly one** path in the committed spec mentions a report, and
it is the one that files one. A reader added later fails that test, and whoever
adds it has to come and read this page first.

---

## 2. A CORRECTION — a report does not change the review

The Group D schema doc said:

> `pending_moderation` therefore means what its name says — a state a REPORT
> moves a review into — rather than the front door.

**That was wrong, and building it is what showed it.**

The venue page reads `status = 'published'`. The rating trigger averages the
same set. So a report that moved a review to `pending_moderation` would remove
it from the venue's page *and* from its rating — meaning **one account could
silence any review**, with no moderator to release it. That is precisely the
brigading `idx_review_reports_unique` exists to prevent, achieved through the
front door instead.

So a report is a row and nothing else. The review stays published until a human
looks.

That is a **negative property**, which is the shape that normally ends up as
prose. It is asserted directly instead, because all three consequences are
observable — the review's status, its presence on the public list, and the
venue's `rating_count` are read before and after a real report. Plus a fourth
assertion that the report was actually written, without which the other three
pass on a report that never happened.

Verified by making a report set `pending_moderation` for one run: **three tests
failed**, not one, because hiding a review breaks the list and the rating too.

---

## 3. The design is one index

```sql
CREATE UNIQUE INDEX idx_review_reports_unique
  ON review_reports (review_id, reporter_user_id);
```

One person cannot brigade a review alone. Without it a single account could
file fifty reports and make it look like fifty people objected — which is
exactly what an automated triage rule would key on, and exactly the abuse a
report queue attracts.

The endpoint answers **201 then 200**: a second press means the same thing as
the first, and the first response may simply have been lost. No
`Idempotency-Key` — the index makes a replay structurally unable to create a
second row, which is what a key would have protected against. Pinned in
`idempotency-contract.spec.ts`.

**Reporting your own review is a 400**, not because it would break anything but
because it means the diner wanted something else. Somebody trying to retract
what they wrote needs a delete, which does not exist; letting them file a
report would take the action they meant and turn it into one that does nothing
they wanted.

**A review that is not published is a 404, byte-identical to one that never
existed.** A different answer for "hidden" and "no such thing" tells a prober
which ids are real.

---

## 4. The client, and the one line that makes it honest

> "Reporting doesn't hide the review. A person reads it and decides."

Above the button, not after it, and the most important thing on the sheet. A
report has **no visible effect** — the review stays, the rating does not move,
nobody reads it until A-3. A diner who expects the review to disappear and
watches it stay concludes the control is broken, and they are not wrong to
unless we said so first.

The control lives in the **all-reviews sheet**, not on the venue page's
three-review preview. A diner scanning reviews under a booking button is
deciding where to eat; a diner who opened the full list and read one is the one
who might have a reason to flag it.

`not_my_visit` is a reason of its own rather than folded into "something else",
because it is the one that is about **us**: a review attached to the wrong
reservation is a bug in the verified-diner guarantee, not a moderation
question, and a moderator cannot triage it if it arrives as "other".

`report_reason_test.dart` reads the Postgres enum out of the migration on disk
and fails if the Dart enum drifts — same shape as the dietary vocabulary. It
also pins that `wire` is `snake_case`: `ReportReason.notMyVisit.name` is
`notMyVisit`, which the API refuses, and the failure would be a chip that looks
right and 400s on submit.

---

## 5. A general finding about `textContrastGuideline`

The report sheet's "Pick a reason first" line failed the contrast guideline at
**2.10:1 — in Arabic only.** Investigating it produced something worth keeping:

- `textFaint` on `surfaceCard` is **5.82:1**. The colour is fine.
- The guideline sampled **#B0ACA3**, which is a ~50% blend of the text colour
  and the background — an anti-aliased edge, not a glyph.
- **Once the sampler picks a 50% edge, no colour can pass.** Pure black on
  `surfaceCard`, sampled at a 50% blend, scores **3.92**. AA needs 4.5.

So a failure there is not always a colour problem, and it is **length- and
script-sensitive**: the same pattern in the write-review sheet passed only
because its string is a different length. Arabic at 13pt in a thin weight has
more anti-aliased edge than glyph core.

That last part is a legibility fact rather than an artefact, so the fix is more
ink — `textSoft` at `w600` — which is also the right call for the one line that
explains why the primary button is dead. It should not be the faintest text on
the screen.

**This has now bitten twice.** The first time (Group D, the venue description)
it was worked around by moving a layout block. Recorded here so the third time
starts from the measurement rather than from the layout.
