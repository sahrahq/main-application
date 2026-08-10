import Redis from 'ioredis';

/**
 * Reset ALL shared OTP state before a suite that touches it: send counters,
 * live challenges, and verify locks.
 *
 * THE PROBLEM THIS SOLVES, because it is not obvious and it cost a debugging
 * session:
 *
 * `OtpService` enforces two limits — 3 sends per phone per 10 minutes, and
 * **10 sends per IP per 10 minutes** (doc 06 §1). Every e2e test runs over
 * loopback, so every suite in the repo shares ONE per-IP budget. Worse, it
 * lives in Redis, which survives between runs: a suite that passes on a cold
 * Redis fails ten minutes later against the same code.
 *
 * The symptom is deceptive. `register` deliberately swallows a send failure —
 * "a send failure must not orphan the account" — so an exhausted budget looks
 * like an account that was created and simply never received a code. The test
 * then fails on a missing code, pointing at the wrong thing entirely.
 *
 * This resets the counters. It does NOT weaken the limiter: the limiter is
 * still the real one, still Redis-backed, and `phone-otp-login.e2e-spec.ts`
 * asserts the per-phone limit fires. What is reset is the state SHARED WITH
 * OTHER SUITES, which is a property of the harness rather than of the code.
 *
 * Every suite that issues or verifies a code must call this. Running the whole
 * e2e suite proved why: `otp-store-parity` passed alone and failed in the full
 * run, because earlier suites had spent the per-IP budget it assumed was
 * fresh.
 */
export async function resetOtpState(): Promise<void> {
  const url = process.env.REDIS_URL;
  // No Redis means the in-memory limiter, which is per-process and therefore
  // already clean at the start of every suite.
  if (!url) return;

  const client = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 1 });
  try {
    await client.connect();
    // `scanStream` rather than KEYS: KEYS blocks the server, and this runs
    // against whatever Redis a developer happens to have, including a shared
    // one.
    // `otp:*`, not `otp:send:*`. The send counters were only half of it: the
    // 15-minute verify LOCK also lives in Redis and also outlives a suite, so
    // a run that left a user locked would fail the next suite to use that id
    // with an error about attempts rather than about whatever it was testing.
    const stream = client.scanStream({ match: 'otp:*', count: 100 });
    for await (const batch of stream) {
      const keys = batch as string[];
      if (keys.length > 0) await client.del(...keys);
    }
  } catch {
    // A suite that cannot reach Redis is running on the in-memory limiter, or
    // is about to fail for a better-reported reason than this.
  } finally {
    await client.quit().catch(() => client.disconnect());
  }
}
