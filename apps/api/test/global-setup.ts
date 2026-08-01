/**
 * Decide ONCE, before any suite is registered, whether Redis is reachable.
 *
 * This has to happen at global-setup time rather than in a beforeAll: Jest
 * registers describe blocks synchronously at module load, so a later async
 * probe cannot turn a suite into a skip. Without this the Redis suites would
 * report a green tick while never having run — which is worse than a skip,
 * because it reads as "the Redis adapters are verified".
 *
 * A plain TCP connect, not an ioredis client: no retry loops, no lingering
 * handles keeping Jest alive after the run.
 */
import { config } from "dotenv";
import { resolve } from "path";
import { Socket } from "net";

function probe(host: string, port: number, timeoutMs = 1500): Promise<boolean> {
  return new Promise((res) => {
    const s = new Socket();
    const done = (ok: boolean) => {
      s.removeAllListeners();
      s.destroy();
      res(ok);
    };
    s.setTimeout(timeoutMs);
    s.once("connect", () => done(true));
    s.once("timeout", () => done(false));
    s.once("error", () => done(false));
    s.connect(port, host);
  });
}

export default async function globalSetup(): Promise<void> {
  config({ path: resolve(__dirname, "..", ".env") });

  const url = process.env.REDIS_URL ?? "redis://localhost:6379";
  let host = "localhost";
  let port = 6379;
  try {
    const u = new URL(url);
    host = u.hostname || host;
    port = Number(u.port || 6379);
  } catch {
    /* keep defaults */
  }

  const up = await probe(host, port);
  process.env.REDIS_AVAILABLE = up ? "1" : "0";

  // eslint-disable-next-line no-console
  console.log(
    up
      ? `\n[redis] reachable at ${host}:${port} — Redis adapter suites WILL run.`
      : `\n[redis] unreachable at ${host}:${port} — Redis adapter suites will be SKIPPED (not passed).\n` +
        `        Start it with: docker compose up -d\n`,
  );
}