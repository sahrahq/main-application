import { readFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

/**
 * WHO IS ALLOWED TO CALL THE HAND-ROLLED MULTIPART PARSER.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THE RULE THIS ENFORCES
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `read-upload.ts` was written instead of adding `multer`, and the argument
 * for that was proportionality: ONE admin endpoint, one field, sixty lines,
 * behind `JwtAuthGuard` + `RolesGuard` with `@Roles('admin', 'support')`.
 *
 * **The proportionality is entirely a function of the caller.** A hand-written
 * parser for a binary wire format reachable by an anonymous request is a
 * different object with the same source code. Diner review photos (C-4.4) and
 * owner uploads (R-2.2) are both coming, and either one calling this would
 * quietly convert an accepted small risk into an unaccepted large one — with
 * no diff to review, because the parser itself would not change.
 *
 * So the caller list is pinned rather than described. A second `readUpload`
 * import fails here and forces the conversation the comment asks for: add
 * `multer`, which is maintained and fuzzed and read by thousands, rather than
 * widening this.
 *
 * Same shape as `idempotency-contract.spec.ts` — a census with a date on it,
 * not an approval.
 */
describe('the hand-rolled multipart parser has exactly one caller', () => {
  const root = join(__dirname, '..', '..');

  function everyTsFile(dir: string, out: string[] = []): string[] {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) {
        everyTsFile(full, out);
      } else if (entry.endsWith('.ts')) {
        out.push(full);
      }
    }
    return out;
  }

  const files = everyTsFile(root);

  const importers = files
    .filter((f) => !f.endsWith('read-upload.ts'))
    .filter((f) => !f.endsWith('admin-upload-parser.contract.spec.ts'))
    // A `.spec.ts` importing the parser is a TEST of it, not a caller that
    // ships. `read-upload.spec.ts` feeds it malformed bodies on purpose and
    // must keep being able to; excluding specs is safe because nothing in one
    // is reachable from a request.
    .filter((f) => !f.endsWith('.spec.ts'))
    .filter((f) => /from '[^']*read-upload'/.test(readFileSync(f, 'utf8')))
    .map((f) => f.replace(/\\/g, '/').split('/src/')[1])
    .sort();

  it('the scan looked at a plausible number of files', () => {
    // Guards the guard. A path bug makes the assertion below pass on an empty
    // list, which is exactly the answer it is trying to earn.
    expect(files.length).toBeGreaterThanOrEqual(40);
  });

  it('ONLY the admin images controller imports it', () => {
    expect(importers).toEqual(['modules/images/admin-images.controller.ts']);
  });

  it('and that controller is role-gated, not merely authenticated', () => {
    // The guard list is the whole mitigation. A controller that kept
    // `JwtAuthGuard` and lost `RolesGuard` would let any signed-in DINER reach
    // the parser — which is precisely the population the boundary excludes.
    const source = readFileSync(
      join(root, 'modules', 'images', 'admin-images.controller.ts'),
      'utf8',
    );

    expect(source).toContain('UseGuards(JwtAuthGuard, RolesGuard)');
    // BOTH guards, and the parser is called in this file. Proximity is not
    // asserted — the decorators between them run to hundreds of characters and
    // a brittle distance check would fail on a docstring edit. What the route
    // may be reached BY is pinned exhaustively in the next test.
    expect(source).toContain('readUpload(req)');
  });

  it('and no role beyond admin/support can reach the upload route', () => {
    const source = readFileSync(
      join(root, 'modules', 'images', 'admin-images.controller.ts'),
      'utf8',
    );

    // Every `@Roles(...)` in the file, so a widened list on ANY route here is
    // visible — the parser is one handler away from all of them.
    const declared = [...source.matchAll(/@Roles\(([^)]*)\)/g)].map((m) =>
      m[1].replace(/['\s]/g, ''),
    );

    expect(declared.sort()).toEqual([
      'admin,support',
      'admin,support',
      'admin,support,moderator',
    ]);
  });
});
