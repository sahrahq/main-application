import { readdirSync, readFileSync, statSync } from 'fs';
import { join } from 'path';

/**
 * EVERY TEST FILE A COMMENT POINTS AT MUST EXIST.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHY THIS IS WORTH A TEST
 * ─────────────────────────────────────────────────────────────────────────
 *
 * This codebase leans hard on comments that say *"asserted in
 * `x.e2e-spec.ts`"*. That sentence is load-bearing: it is how a reader decides
 * a claim is checked rather than hoped for, and it is the difference between a
 * docblock that documents a guarantee and one that describes an intention.
 *
 * **A pointer to a file that does not exist is decoration** — the same class of
 * thing as the `REVOKE … FROM anon` line that reported success and did nothing.
 * Worse, actually: the REVOKE only bought false confidence in a security
 * review, while these buy it every time somebody reads the code.
 *
 * SIX were found on 2026-08-10 — five by hand, and a sixth by this test on
 * its very first run. Two of the five were written the same day:
 *
 *   - `firebase-credentials.spec.ts` → the file is `firebase.config.spec.ts`
 *   - `notification-payload.spec.ts` → never existed; the pinning is in
 *     `notifications.e2e-spec.ts`
 *   - `menus.e2e-spec.ts` → `menus-reviews.e2e-spec.ts`
 *   - `reviews-eligibility.spec.ts` → `review-eligibility.spec.ts`
 *   - `reviews.e2e-spec.ts` → `menus-reviews.e2e-spec.ts` (twice; the second
 *     occurrence, in `reviews.service.ts`, is the one the test found)
 *
 * Every one is a near-miss on a real filename, which is exactly why none was
 * noticed: they all read as correct.
 *
 * Scoped to the API's own TypeScript. The Dart side has the same habit and is
 * not covered here — noted rather than silently omitted.
 */
describe('every test file named in a comment exists', () => {
  const root = join(__dirname, '..', '..');
  const testRoot = join(__dirname, '..', '..', '..', 'test');

  function walk(dir: string, out: string[] = []): string[] {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) walk(full, out);
      else if (entry.endsWith('.ts')) out.push(full);
    }
    return out;
  }

  // THIS FILE IS EXCLUDED FROM ITS OWN SCAN. Its docblock lists the dead names
  // it was written to catch, as the record of what was found — and a guard that
  // reported its own examples as defects would be permanently red, which is the
  // same as being deleted.
  const sources = walk(root).filter((f) => !f.endsWith('doc-pointers.spec.ts'));
  const existing = new Set([
    ...walk(root).map((f) => f.split(/[\\/]/).pop()!),
    ...walk(testRoot).map((f) => f.split(/[\\/]/).pop()!),
  ]);

  /** Any `something.spec.ts` / `something.e2e-spec.ts` mentioned in a comment. */
  const referenced = new Map<string, string[]>();
  for (const file of sources) {
    for (const m of readFileSync(file, 'utf8').matchAll(
      /[A-Za-z0-9_.-]+\.(?:e2e-spec|spec)\.ts/g,
    )) {
      const name = m[0];
      // A file naming itself in its own header is not a pointer.
      if (file.endsWith(name)) continue;
      referenced.set(name, [...(referenced.get(name) ?? []), file.replace(root, '')]);
    }
  }

  it('the scan read the tree and found pointers — census', () => {
    // Both halves. An empty `existing` would make every name "missing"; an
    // empty `referenced` would make the assertion below pass while checking
    // nothing, which is how a census fails.
    expect(existing.size).toBeGreaterThan(30);
    expect(referenced.size).toBeGreaterThan(10);
  });

  it('and every one of them resolves to a real file', () => {
    const dangling = [...referenced.entries()]
      .filter(([name]) => !existing.has(name))
      .map(([name, from]) => `${name} — referenced by ${from.join(', ')}`);

    expect(dangling).toEqual([]);
  });

  it('AND THE SCAN CATCHES A FAKE ONE — guards the guard', () => {
    // If the regex silently stopped matching, the assertion above would report
    // a clean bill of health for a tree it never read.
    const invented = 'this-file-does-not-exist.e2e-spec.ts';
    expect(/[A-Za-z0-9_.-]+\.(?:e2e-spec|spec)\.ts/.test(invented)).toBe(true);
    expect(existing.has(invented)).toBe(false);
  });
});
