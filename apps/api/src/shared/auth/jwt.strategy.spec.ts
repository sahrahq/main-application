import { ConfigService } from '@nestjs/config';
import { JwtStrategy } from './jwt.strategy';
import type { PrismaService } from '../prisma/prisma.service';

/**
 * THE ABSENCE OF A DEFAULT IS THE SECURITY PROPERTY. PIN IT.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHY THIS EXISTS
 * ─────────────────────────────────────────────────────────────────────────
 *
 * On 2026-08-10 CI ran against this branch for the first time and the API
 * refused to boot:
 *
 *     Configuration key "JWT_ACCESS_SECRET" does not exist
 *       at ConfigService.getOrThrow
 *       at new JwtStrategy (jwt.strategy.ts:23)
 *
 * **That is correct behaviour, which is why this is a test and not a fix.**
 * The workflow was missing the variable; the code was right to stop.
 *
 * JWT_ACCESS_SECRET is an HS256 key — symmetric, so the secret IS the ability
 * to mint a valid access token for any user, including an admin (doc 09 §1.1).
 * A fallback default would not be a convenience, it would be a published
 * signing key: every environment that forgot to set the variable would issue
 * forgeable tokens and look perfectly healthy doing it, because they verify.
 *
 * `validateSecrets()` is NOT this guard. It only WARNS outside production
 * (deliberately — local work must not require a secrets manager), so a
 * defaulted secret would pass it with a log line nobody reads. `getOrThrow` is
 * what actually stops the process, and nothing was pinning it.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHY THE ENV IS SCRUBBED BELOW, WHICH IS THE REAL TRAP
 * ─────────────────────────────────────────────────────────────────────────
 *
 * The first version of this test PASSED in a container and FAILED on a
 * developer's laptop — the same code, opposite results. The cause:
 *
 *     require('@prisma/client')   →   loads .env into process.env
 *
 * Prisma reads `.env` on import to find `DATABASE_URL`, and in doing so it
 * puts **every** variable in that file into `process.env` — JWT secrets
 * included — purely as a side effect of importing an ORM. `ConfigService`
 * falls back to `process.env`, so `getOrThrow` finds a secret nobody passed
 * it. Importing `jwt.strategy.ts` at all is enough: it pulls in
 * `PrismaService`, which pulls in `@prisma/client`.
 *
 * Measured, not deduced: `'JWT_ACCESS_SECRET' in process.env` is `false`
 * before `require('@prisma/client')` and `true` after.
 *
 * So on any machine with a `.env`, "the secret is absent" cannot be expressed
 * by simply not passing it. The variable has to be removed from the process
 * explicitly, or this test asserts nothing on exactly the machines where
 * people run it.
 */
describe('JwtStrategy refuses to exist without a signing secret', () => {
  // Never touched: construction throws before any field of it is read.
  const prisma = {} as PrismaService;

  let saved: string | undefined;
  beforeEach(() => {
    saved = process.env.JWT_ACCESS_SECRET;
    delete process.env.JWT_ACCESS_SECRET;
  });
  afterEach(() => {
    if (saved === undefined) delete process.env.JWT_ACCESS_SECRET;
    else process.env.JWT_ACCESS_SECRET = saved;
  });

  it('the scrub worked — guards the guard', () => {
    // Without this, a future change to beforeEach could leave the variable in
    // place and every assertion below would pass for the wrong reason.
    expect('JWT_ACCESS_SECRET' in process.env).toBe(false);
  });

  it('THROWS when JWT_ACCESS_SECRET is absent — no default, no fallback', () => {
    expect(() => new JwtStrategy(new ConfigService({}), prisma)).toThrow(/JWT_ACCESS_SECRET/);
  });

  it('and when it is present but empty, which is how a blank `.env` line arrives', () => {
    // `FOO=` parses to '', which truthy-checking code treats as unset but
    // `getOrThrow` treats as set. passport-jwt must reject it.
    expect(() => new JwtStrategy(new ConfigService({ JWT_ACCESS_SECRET: '' }), prisma)).toThrow();
  });

  it('constructs when a secret IS supplied — so the above is about the secret, not the constructor', () => {
    expect(
      () => new JwtStrategy(new ConfigService({ JWT_ACCESS_SECRET: 'a'.repeat(64) }), prisma),
    ).not.toThrow();
  });
});
