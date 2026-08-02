import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

/**
 * Browser access policy.
 *
 * Needed because the customer app runs in Chrome during development
 * (`flutter run -d chrome`) on an ephemeral localhost port, and a browser will
 * not let it reach `http://localhost:3000` without this. Native builds never
 * hit CORS at all — this exists for the dev loop and for the admin web surface
 * in doc 07 §3.
 *
 * The policy is a pure function of the environment rather than a block inside
 * `bootstrap()` so it can be asserted. "Allow anything in dev" is one typo
 * away from "allow anything", and that typo is invisible in a function nobody
 * can call.
 */
export function corsOptionsFor(
  nodeEnv: string | undefined,
  allowlist: string | undefined,
): CorsOptions {
  const origins = (allowlist ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  const isProd = nodeEnv === 'production';

  if (isProd && origins.length === 0) {
    // No allowlist in production means no browser origin is trusted. Not `*`:
    // an empty CORS_ORIGINS is far more likely to be "nobody configured it"
    // than "we intend to be open to the entire web".
    return { origin: false, ...SHARED };
  }

  if (origins.length > 0) return { origin: origins, ...SHARED };

  // Development: any loopback port, because `flutter run -d chrome` picks a
  // new one on every launch. Still a predicate, not `true` — a page on a real
  // site must not be able to drive a developer's local API.
  return {
    origin: (origin, cb) => cb(null, origin === undefined || LOOPBACK.test(origin)),
    ...SHARED,
  };
}

const LOOPBACK = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/;

const SHARED: Omit<CorsOptions, 'origin'> = {
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  // Idempotency-Key is required on every mutation (doc 06 §1). Omitting it
  // here means the browser strips it and every booking 400s on
  // `missing_idempotency_key` — with a CORS error in the console pointing
  // somewhere else entirely.
  allowedHeaders: ['Content-Type', 'Authorization', 'Idempotency-Key', 'Accept-Language', 'X-Request-Id', 'X-App-Version'],
  exposedHeaders: ['X-Request-Id', 'Retry-After'],
  credentials: false,
  maxAge: 600,
};
