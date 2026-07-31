import { checkSecret, secretStrength, validateSecrets, MIN_SECRET_BITS } from './secrets.validation';

const STRONG_HEX = 'a'.repeat(64); // 64 hex chars = 256 bits
const STRONG_RAW = 'x'.repeat(32); // 32 bytes = 256 bits

describe('secretStrength', () => {
  it('counts hex at 4 bits per char', () => {
    expect(secretStrength('a'.repeat(64))).toBe(256);
    expect(secretStrength('a'.repeat(32))).toBe(128);
  });

  it('counts non-hex at 8 bits per byte', () => {
    expect(secretStrength('x'.repeat(32))).toBe(256);
  });

  it('does not over-credit a hex-looking string', () => {
    // 32 hex chars is 128 bits of key material, not 256 — counting it as
    // bytes would let a half-strength secret pass.
    expect(secretStrength('abcdef0123456789'.repeat(2))).toBe(128);
  });
});

describe('checkSecret', () => {
  it('accepts a 256-bit secret', () => {
    expect(checkSecret('JWT_ACCESS_SECRET', STRONG_HEX).ok).toBe(true);
    expect(checkSecret('JWT_ACCESS_SECRET', STRONG_RAW).ok).toBe(true);
  });

  it('rejects an unset secret', () => {
    expect(checkSecret('JWT_ACCESS_SECRET', undefined)).toMatchObject({ ok: false, reason: 'not set' });
  });

  it('rejects anything below the bit floor', () => {
    const r = checkSecret('JWT_ACCESS_SECRET', 'a'.repeat(63));
    expect(r.ok).toBe(false);
    expect(r.bits).toBeLessThan(MIN_SECRET_BITS);
  });

  it('rejects known placeholders regardless of length', () => {
    expect(checkSecret('JWT_ACCESS_SECRET', 'test-secret-not-for-production').ok).toBe(false);
    expect(checkSecret('JWT_ACCESS_SECRET', 'changeme').ok).toBe(false);
  });
});

describe('validateSecrets', () => {
  const good = { JWT_ACCESS_SECRET: STRONG_HEX, JWT_REFRESH_SECRET: 'b'.repeat(64) };
  const noEnvFile = () => false;
  const hasEnvFile = () => true;

  it('passes with strong secrets injected by the platform', () => {
    expect(() =>
      validateSecrets({ ...good, NODE_ENV: 'production' } as NodeJS.ProcessEnv, noEnvFile),
    ).not.toThrow();
  });

  it('THROWS in production on a weak secret', () => {
    expect(() =>
      validateSecrets(
        { ...good, JWT_ACCESS_SECRET: 'short', NODE_ENV: 'production' } as NodeJS.ProcessEnv,
        noEnvFile,
      ),
    ).toThrow(/≥ 256 bits/);
  });

  it('THROWS in production on a missing secret', () => {
    expect(() =>
      validateSecrets(
        { JWT_REFRESH_SECRET: STRONG_HEX, NODE_ENV: 'production' } as NodeJS.ProcessEnv,
        noEnvFile,
      ),
    ).toThrow(/not set/);
  });

  it('THROWS in production when a .env file is baked into the image', () => {
    // Strong secrets are not enough: a file-resident secret means the key is
    // in the build artifact rather than the secrets manager (doc 09 §1.1).
    expect(() =>
      validateSecrets({ ...good, NODE_ENV: 'production' } as NodeJS.ProcessEnv, hasEnvFile),
    ).toThrow(/secrets manager/);
  });

  it('tolerates a .env file outside production, so local work is not blocked', () => {
    expect(() =>
      validateSecrets({ ...good, NODE_ENV: 'development' } as NodeJS.ProcessEnv, hasEnvFile),
    ).not.toThrow();
  });

  it('only warns on a weak secret in development', () => {
    expect(() =>
      validateSecrets({ JWT_ACCESS_SECRET: 'weak', NODE_ENV: 'development' } as NodeJS.ProcessEnv, noEnvFile),
    ).not.toThrow();
  });
});
