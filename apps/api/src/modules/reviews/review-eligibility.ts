/**
 * WHO MAY REVIEW A VISIT — one definition, in one pure function.
 *
 * This is the invariant the database cannot hold. `reviews.reservation_id` is
 * NOT NULL and UNIQUE, so the schema guarantees "no review without a visit,
 * one review per visit"; it cannot reach into `reservations` to check the
 * status, and every mechanism that could makes an unrelated later write fail.
 *
 * So it lives in code — and the moment it lives in code, the risk is that it
 * lives in code TWICE. `POST /reviews` enforces it; the bookings list has to
 * predict it, so the app knows whether to draw a "write a review" control. Two
 * copies would drift, and the one that drifted would be the client's, because
 * nobody tests a client against a real `no_show`.
 *
 * One function, no Nest dependencies, imported by both. `menus-reviews.e2e-spec.ts`
 * attempts a review from every non-eligible status, and
 * `review-eligibility.spec.ts` asserts this function and that endpoint agree.
 *
 * ── THE TWO CONDITIONS ───────────────────────────────────────────────────
 *
 * 1. **The status.** C-4.4 says "seated"; doc 06 §Reviews says "completed".
 *    Taken as written, doc 06 is currently UNREACHABLE — `completed` is set by
 *    the venue's `complete` action, and of the six owner actions in doc 06 §4
 *    only `cancel` is built. Requiring it would ship a feature nobody can use,
 *    so both are accepted and the disagreement is recorded here rather than
 *    quietly resolved.
 *
 * 2. **The meal is over.** `seated` means "at the table right now", so on
 *    status alone a diner could review the starter. `ends_at` already exists on
 *    every reservation, so this costs nothing and is what makes accepting
 *    `seated` safe.
 */
export const REVIEWABLE_STATUSES = ['seated', 'completed'] as const;

export type ReviewIneligibility = 'not_eligible' | 'too_early' | null;

/** Why this reservation cannot be reviewed, or null if it can. */
export function reviewIneligibility(status: string, endsAt: Date): ReviewIneligibility {
  if (!(REVIEWABLE_STATUSES as readonly string[]).includes(status)) return 'not_eligible';
  if (endsAt.getTime() > Date.now()) return 'too_early';
  return null;
}

export function isReviewable(status: string, endsAt: Date): boolean {
  return reviewIneligibility(status, endsAt) === null;
}
