import Redis from 'ioredis';

/**
 * Reset the OTP send budget before a suite that sends codes.
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
 * asserts the per-phone limit fires. What is reset is the budget SHARED WITH
 * OTHER SUITES, which is a property of the harness rather than of the code.
 */
export async function resetOtpSendBudget(): Promise<void> {
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
    const stream = client.scanStream({ match: 'otp:send:*', count: 100 });
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
