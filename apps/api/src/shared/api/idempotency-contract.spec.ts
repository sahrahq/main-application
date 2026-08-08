import { readFileSync } from 'fs';
import { join } from 'path';

/**
 * WHICH MUTATIONS ACTUALLY REQUIRE AN IDEMPOTENCY KEY.
 *
 * CLAUDE.md rule 2 and doc 06 §1 both say "every API mutation is idempotent
 * (`Idempotency-Key` header)". Until this test was written, that sentence was
 * enforced by three hand-written `if` blocks inside three handlers, and by
 * nothing else. The real number was **3 of 25**.
 *
 * Nobody noticed because there was no guard that could count. The Flutter
 * side had one — `FakeTransport` rejected any non-GET without a key — but it
 * only ever saw the two reservation mutations, so it passed for four weeks
 * while agreeing with a rule the other twenty-two endpoints broke. A guard
 * that is only ever pointed at the compliant cases is not a guard.
 *
 * So this test OBSERVES the committed spec rather than asserting a belief
 * about it. It reports the actual list and compares it to one pinned below.
 * The pinned list is not an approval — it is a census with a date on it. Its
 * value is that adding a twenty-sixth mutation without a key now fails here
 * and forces someone to decide, instead of quietly making the doc a little
 * more false.
 */
describe('Idempotency-Key coverage across mutations', () => {
  const spec = JSON.parse(
    readFileSync(join(__dirname, '..', '..', '..', 'openapi.json'), 'utf8'),
  ) as {
    paths: Record<string, Record<string, { parameters?: { name: string; in: string }[] }>>;
  };

  const mutations: string[] = [];
  const withKey: string[] = [];
  const withoutKey: string[] = [];

  for (const [path, item] of Object.entries(spec.paths)) {
    for (const [method, op] of Object.entries(item)) {
      if (method === 'get') continue;
      const id = `${method.toUpperCase()} ${path}`;
      mutations.push(id);
      const declared = (op.parameters ?? []).some(
        (p) => p.in === 'header' && p.name.toLowerCase() === 'idempotency-key',
      );
      (declared ? withKey : withoutKey).push(id);
    }
  }

  it('found the mutations — census', () => {
    // Without this the two assertions below both pass on an empty spec, which
    // is exactly how a contract test comes to guard nothing.
    expect(mutations.length).toBeGreaterThanOrEqual(20);
  });

  /**
   * The three that DO carry a key are the three where a replay creates a
   * duplicate table booking. That is not a coincidence — it is where the
   * requirement was actually felt, which is why it is the only place it got
   * built.
   */
  it('every reservation-creating mutation requires a key', () => {
    expect(withKey.sort()).toEqual([
      'POST /v1/owner/restaurants/{restaurantId}/reservations',
      'POST /v1/reservations/holds',
      'POST /v1/reservations/holds/{id}/confirm',
    ]);
  });

  /**
   * Everything else, pinned as of 2026-08-02, extended 2026-08-08.
   *
   * Read this as an open gap, not a design. Several entries are naturally
   * idempotent and would gain nothing (`acknowledge-cancellation` is a
   * conditional UPDATE; `DELETE /devices` is a delete). Several are not:
   * `POST /owner/restaurants` creates a row, and a retried request over a bad
   * connection creates two restaurants.
   *
   * ── THE THREE ADDED IN GROUP A, AND WHY EACH IS HERE ────────────────────
   *
   * These are not "not done yet". Each was decided, and the reasoning has to
   * survive in a place someone will read before adding a fourth:
   *
   * `PATCH /v1/reservations/{id}` — the only one that gave pause, because it
   *   releases a table and takes another, which is a booking write. It carries
   *   no key because the BODY NAMES ABSOLUTE VALUES: replaying it lands on the
   *   same window with the same party, and no retry can produce a second row.
   *   That is idempotency by construction rather than by bookkeeping, and it
   *   is why no third key column was added to `reservations`.
   *   **The argument is contingent on the shape.** If this ever accepts a
   *   relative change ("move by 30 minutes", "add one guest") a replay stops
   *   being a no-op and the key becomes mandatory — with the column that
   *   implies. Proved rather than asserted: `diner-actions.e2e-spec.ts` sends
   *   the identical PATCH twice and compares the reservation either side.
   *
   * `POST /v1/reservations/{id}/cancel` — a conditional UPDATE guarded on
   *   `status IN ('pending','confirmed')`, so the second write finds nothing
   *   to do. Same shape as the venue's cancel, which is already on this list.
   *   The residue is cosmetic and known: a diner whose 200 was lost sees a 409
   *   on retry for a cancellation that in fact succeeded.
   *
   * `PATCH /v1/auth/me` — absolute values again, and no row is created.
   *
   * ── AND THE TWO ADDED IN GROUP B ───────────────────────────────────────
   *
   * `POST   /v1/admin/restaurants/{restaurantId}/images`
   * `DELETE /v1/admin/restaurants/{restaurantId}/images/{imageId}`
   *
   * The upload genuinely is not idempotent: a replay stores a second copy and
   * inserts a second row. It carries no key anyway, and the reasoning is about
   * WHO USES IT rather than about the shape.
   *
   * It is an ADMIN endpoint driven by a person watching the response
   * (doc 10 §3b — venue photos come through us until `management_app` ships).
   * A duplicate is a visible extra row in a gallery they are already looking
   * at, deletable in one call. The alternative is a key column on `images` and
   * a lookup on every upload, to protect a manual operation from a failure
   * mode its operator can see and undo.
   *
   * **If this ever becomes owner-facing or scripted, that argument expires.**
   * A bulk importer retrying over a bad connection would silently double a
   * venue's gallery, and at that point the key stops being optional.
   *
   * The DELETE is idempotent by nature — the second one 404s.
   */
  it('the mutations WITHOUT a key are the known list, and no more', () => {
    expect(withoutKey.sort()).toEqual([
      'DELETE /v1/admin/restaurants/{restaurantId}/images/{imageId}',
      'DELETE /v1/devices',
      'DELETE /v1/owner/restaurants/{restaurantId}/shifts/{shiftId}',
      'DELETE /v1/owner/restaurants/{restaurantId}/tables/{tableId}',
      'PATCH /v1/auth/me',
      'PATCH /v1/owner/restaurants/{id}',
      'PATCH /v1/owner/restaurants/{restaurantId}/shifts/{shiftId}',
      'PATCH /v1/owner/restaurants/{restaurantId}/tables/{tableId}',
      'PATCH /v1/reservations/{id}',
      'POST /v1/admin/restaurants/{id}/approve',
      'POST /v1/admin/restaurants/{id}/reject',
      'POST /v1/admin/restaurants/{restaurantId}/images',
      'POST /v1/auth/complete-registration',
      'POST /v1/auth/login',
      'POST /v1/auth/logout',
      'POST /v1/auth/refresh',
      'POST /v1/auth/register',
      'POST /v1/auth/request-otp',
      'POST /v1/auth/resend-otp',
      'POST /v1/auth/verify-otp',
      'POST /v1/devices',
      'POST /v1/owner/reservations/{id}/cancel',
      'POST /v1/owner/restaurants',
      'POST /v1/owner/restaurants/{id}/submit',
      'POST /v1/owner/restaurants/{restaurantId}/shifts',
      'POST /v1/owner/restaurants/{restaurantId}/tables',
      'POST /v1/reservations/{id}/acknowledge-cancellation',
      'POST /v1/reservations/{id}/cancel',
    ]);
  });
});
