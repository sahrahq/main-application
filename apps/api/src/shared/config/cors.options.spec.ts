import { corsOptionsFor } from './cors.options';

/** Resolve the `origin` predicate the way the Nest cors middleware does. */
function allows(options: ReturnType<typeof corsOptionsFor>, origin: string | undefined): boolean {
  const o = options.origin;
  if (typeof o === 'function') {
    let allowed = false;
    o(origin as string, (_e, ok) => {
      allowed = ok === true;
    });
    return allowed;
  }
  if (Array.isArray(o)) return origin !== undefined && o.includes(origin);
  return o === true;
}

describe('corsOptionsFor', () => {
  describe('development (no allowlist)', () => {
    const dev = corsOptionsFor('development', undefined);

    it('allows any loopback port — flutter run -d chrome picks a new one each launch', () => {
      expect(allows(dev, 'http://localhost:54321')).toBe(true);
      expect(allows(dev, 'http://localhost:8080')).toBe(true);
      expect(allows(dev, 'http://127.0.0.1:3001')).toBe(true);
    });

    it('allows a request with no Origin at all (curl, the Flutter native client)', () => {
      expect(allows(dev, undefined)).toBe(true);
    });

    it('does NOT allow a real site to drive a developer local API', () => {
      expect(allows(dev, 'https://evil.example')).toBe(false);
      // The prefix trick: a host that merely STARTS with localhost.
      expect(allows(dev, 'http://localhost.evil.example')).toBe(false);
      // And the suffix trick.
      expect(allows(dev, 'https://evil.example/localhost')).toBe(false);
    });
  });

  describe('production', () => {
    it('trusts nobody when CORS_ORIGINS is unset — never falls back to *', () => {
      const prod = corsOptionsFor('production', undefined);
      expect(prod.origin).toBe(false);
      expect(allows(prod, 'https://app.sahra.app')).toBe(false);
      expect(allows(prod, 'http://localhost:54321')).toBe(false);
    });

    it('trusts exactly the configured origins', () => {
      const prod = corsOptionsFor('production', 'https://app.sahra.app, https://admin.sahra.app');
      expect(allows(prod, 'https://app.sahra.app')).toBe(true);
      expect(allows(prod, 'https://admin.sahra.app')).toBe(true);
      expect(allows(prod, 'https://evil.example')).toBe(false);
      expect(allows(prod, 'http://localhost:54321')).toBe(false);
    });
  });

  it('lets Idempotency-Key through — without it every booking 400s from the browser', () => {
    // The failure this prevents is deceptive: the browser silently strips the
    // header, the API answers `missing_idempotency_key`, and the console shows
    // a CORS message that points at the wrong thing entirely.
    const headers = corsOptionsFor('development', undefined).allowedHeaders as readonly string[];
    expect(headers.map((h) => h.toLowerCase())).toContain('idempotency-key');
  });
});
