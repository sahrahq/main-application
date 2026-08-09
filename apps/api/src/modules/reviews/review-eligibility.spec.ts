import { isReviewable, reviewIneligibility, REVIEWABLE_STATUSES } from './review-eligibility';

/**
 * THE RULE WITH NO SCHEMA BEHIND IT.
 *
 * Everything else in Group D is held by the database: `reservation_id` is
 * UNIQUE, ratings are CHECKed, the reply pair is tied together. This one is a
 * function, because a CHECK cannot read another table — and a rule enforced by
 * a function is only as good as the test that attacks it.
 *
 * `menus-reviews.e2e-spec.ts` attacks it over HTTP, once per status. This is
 * the same rule at the unit level, where the TIME half is checkable without a
 * database: an e2e test cannot easily produce "seated, ends in one minute"
 * without waiting a minute.
 */
describe('review eligibility', () => {
  const past = (): Date => new Date(Date.now() - 3_600_000);
  const future = (): Date => new Date(Date.now() + 3_600_000);

  /**
   * Every value of `reservation_status`, copied from the enum in the init
   * migration. Written out rather than derived, and that is the one place in
   * this repo where writing a list out is right: if somebody ADDS a status, the
   * census below fails and they have to decide whether a diner may review it.
   * Deriving it from the enum would silently classify the new one as
   * ineligible, which is the safe answer but not a decided one.
   */
  const ALL_STATUSES = [
    'held',
    'pending',
    'confirmed',
    'seated',
    'completed',
    'no_show',
    'cancelled_by_user',
    'cancelled_by_restaurant',
    'expired',
  ];

  it('the census still matches the enum — nine statuses', () => {
    expect(ALL_STATUSES).toHaveLength(9);
    for (const s of REVIEWABLE_STATUSES) expect(ALL_STATUSES).toContain(s);
  });

  it('exactly two statuses are reviewable, and they are the ones argued for', () => {
    const eligible = ALL_STATUSES.filter((s) => isReviewable(s, past()));
    expect(eligible.sort()).toEqual(['completed', 'seated']);
  });

  it.each(ALL_STATUSES.filter((s) => !['seated', 'completed'].includes(s)))(
    '%s is not_eligible even long after the table time',
    (status) => {
      expect(reviewIneligibility(status, past())).toBe('not_eligible');
    },
  );

  it('a seated diner still at the table is too_early, not not_eligible', () => {
    // Two different refusals on purpose: one says "this will never be
    // reviewable", the other says "come back later". A diner shown the first
    // when the second is true stops waiting.
    expect(reviewIneligibility('seated', future())).toBe('too_early');
    expect(reviewIneligibility('completed', future())).toBe('too_early');
  });

  it('status is checked BEFORE time, so a no-show is never told to come back later', () => {
    // Order matters for the message. A no-show whose slot has not ended yet
    // must not be told "you can review once your table time is over" — there
    // is no table time coming.
    expect(reviewIneligibility('no_show', future())).toBe('not_eligible');
  });

  it('the boundary is the END of the meal, not the start', () => {
    const justEnded = new Date(Date.now() - 1_000);
    const endsInAMoment = new Date(Date.now() + 60_000);
    expect(isReviewable('seated', justEnded)).toBe(true);
    expect(isReviewable('seated', endsInAMoment)).toBe(false);
  });
});
