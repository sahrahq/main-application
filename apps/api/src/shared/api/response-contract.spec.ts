import { readFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

/**
 * THE GUARD ON THE CONTRACT.
 *
 * `@ApiOkResponse({ type: X })` tells the OpenAPI document — and therefore the
 * generated Dart client — what an endpoint returns. Nothing was checking that
 * the handler actually returned an `X`, because TypeScript does not read
 * decorators. Five endpoints were lying:
 *
 *   POST /reservations/holds            no `restaurantId`, no `source`
 *   POST /reservations/holds/:id/confirm  same
 *   POST /auth/login | verify-otp | refresh   no `user` at all
 *   GET  /auth/me                       3 of 7 declared fields
 *   POST /owner/.../reservations        Date where the DTO says string
 *
 * Every one of them would have thrown a null cast in the client on the FIRST
 * REAL CALL — and the e2e suite was green throughout, because those tests
 * assert on named fields rather than on shape.
 *
 * The fix is an annotated return type, which puts `tsc` on the same contract
 * the decorator advertises. This test is what stops the annotation from being
 * dropped again: it is a source scan, because the thing being checked is the
 * PRESENCE of the type annotation, which does not survive to runtime.
 */
describe('every declared response type is enforced by the compiler', () => {
  const controllers = collectControllers(join(__dirname, '..', '..'));

  it('found the controllers — census', () => {
    // Everything below iterates this list. An empty one would pass silently
    // while checking nothing, which is how a census fails.
    expect(controllers.length).toBeGreaterThanOrEqual(7);
  });

  it('every @ApiOkResponse handler declares its return type', () => {
    const unenforced: string[] = [];

    for (const file of controllers) {
      const source = readFileSync(file, 'utf8');
      const lines = source.split('\n');

      for (let i = 0; i < lines.length; i++) {
        if (!/@ApiOkResponse\(\{\s*type:/.test(lines[i])) continue;

        // A generous window: `search.controller.ts` puts fourteen @ApiQuery
        // lines and a fourteen-parameter signature between the decorator and
        // its return type. Too tight a window reports a false positive, and a
        // guard that cries wolf is a guard somebody deletes.
        const window = lines.slice(i, i + 60).join('\n');
        // The handler signature is the first `)` that is followed by `{` —
        // optionally with a return type annotation in between.
        const closing = window.match(/\)\s*(:[^{;]*)?\{/);
        const annotated = closing?.[1]?.includes('Promise<') ?? false;

        if (!annotated) {
          unenforced.push(`${short(file)}:${i + 1}`);
        }
      }
    }

    expect(unenforced).toEqual([]);
  });
});

function collectControllers(root: string): string[] {
  const out: string[] = [];
  const walk = (dir: string): void => {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) walk(full);
      else if (entry.endsWith('.controller.ts')) out.push(full);
    }
  };
  walk(root);
  return out;
}

function short(file: string): string {
  const i = file.replace(/\\/g, '/').indexOf('/src/');
  return i === -1 ? file : file.replace(/\\/g, '/').slice(i + 1);
}
