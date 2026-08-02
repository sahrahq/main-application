/**
 * How many reverse proxies sit in front of this process.
 *
 * WHY THIS IS NOT `true`, AND WHY A WRONG VALUE IS WORSE THAN NO VALUE.
 *
 * Express derives `req.ip` from `X-Forwarded-For`, a header any client can
 * send. `trust proxy: true` means "believe the whole chain", so a request
 * carrying `X-Forwarded-For: 1.2.3.4` is credited to 1.2.3.4 — and every
 * per-IP control in the system becomes an illusion:
 *
 *   - the 10-sends-per-IP OTP limit (doc 06 §1) is bypassed by rotating a
 *     header, which is free, unlimited, and leaves no trace
 *   - `X-Forwarded-For` is also what lands in `refresh_tokens.ip`, so the
 *     audit trail for a stolen-token investigation records whatever the
 *     attacker typed
 *
 * A control that can be stepped around by editing a header is worse than the
 * current state, where the limit is merely too strict: too strict is visible
 * and annoying; bypassable is invisible and reassuring.
 *
 * The correct value is a COUNT OF HOPS. Express takes the Nth address from
 * the right of `X-Forwarded-For` — the right-hand end being what the nearest
 * proxy observed, which is the part a client cannot forge. With `n` hops,
 * anything a client prepends is discarded.
 *
 * doc 08 §5 puts Cloudflare in front of ECS Fargate behind an ALB, so the
 * production chain is Cloudflare → ALB → app = **2**. That is documented
 * rather than hardcoded because the topology is not committed yet, and a
 * number baked into the source is a number nobody revisits when it changes.
 */
export const TRUST_PROXY_ENV = 'TRUST_PROXY_HOPS';

/** Local and CI: nothing in front, so `req.ip` is the socket and is honest. */
export const DEFAULT_HOPS = 0;

export interface TrustProxyDecision {
  /** What to hand to `app.set('trust proxy', …)`. */
  readonly hops: number;
  /** Explanation, for the boot log. Silent security config is unreviewable. */
  readonly reason: string;
}

/**
 * Resolve the setting, or refuse to start.
 *
 * In production the value is REQUIRED. Leaving it to a default means the
 * correct value depends on somebody remembering, and the failure mode of
 * forgetting is silent: the app runs, the limits appear to work, and every one
 * of them is counting the load balancer's address.
 */
export function resolveTrustProxy(
  env: NodeJS.ProcessEnv = process.env,
): TrustProxyDecision {
  const raw = env[TRUST_PROXY_ENV];
  const isProd = env.NODE_ENV === 'production';

  if (raw === undefined || raw.trim() === '') {
    if (isProd) {
      throw new Error(
        `${TRUST_PROXY_ENV} is required in production.\n` +
          'It is the NUMBER OF PROXY HOPS in front of this process — 2 for the\n' +
          'doc 08 §5 topology (Cloudflare -> ALB -> app), 0 when nothing is in\n' +
          'front. Without it, per-IP rate limits count the load balancer and\n' +
          'every caller shares one budget; set it wrong the other way (or to\n' +
          '`true`) and any client can forge X-Forwarded-For and step around\n' +
          'them entirely.\n' +
          'This is not defaulted on purpose: the correct value must not depend\n' +
          'on someone remembering.',
      );
    }
    return {
      hops: DEFAULT_HOPS,
      reason: `${TRUST_PROXY_ENV} unset — trusting no proxy, req.ip is the socket address`,
    };
  }

  const hops = Number(raw);
  if (!Number.isInteger(hops) || hops < 0 || hops > 10) {
    throw new Error(
      `${TRUST_PROXY_ENV}="${raw}" is not a hop count. Give a small integer ` +
        '(0 for no proxy, 2 for Cloudflare -> ALB -> app). `true`, `*` and a ' +
        'subnet list are all rejected: they trust the whole X-Forwarded-For ' +
        'chain, which the client controls.',
    );
  }

  return {
    hops,
    reason:
      hops === 0
        ? `${TRUST_PROXY_ENV}=0 — trusting no proxy, req.ip is the socket address`
        : `${TRUST_PROXY_ENV}=${hops} — taking the ${ordinal(hops)} address from the ` +
          'right of X-Forwarded-For; anything a client prepends is discarded',
  };
}

function ordinal(n: number): string {
  const suffix = n === 1 ? 'st' : n === 2 ? 'nd' : n === 3 ? 'rd' : 'th';
  return `${n}${suffix}`;
}
