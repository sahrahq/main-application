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

/**
 * IN CI, UNREACHABLE IS A FAILURE — NOT A SKIP.
 *
 * The skip below is right for a laptop: a developer without `docker compose up`
 * should get a truthful "not run", not a wall of red. It is wrong for CI, where
 * both services are DECLARED in `.github/workflows/ci.yml` — so unreachable
 * there does not mean "absent by choice", it means the job is broken.
 *
 * And the job would not notice. Nothing in the workflow reads `MEILI_AVAILABLE`;
 * Jest exits 0 with the suites marked skipped, and the tick is green. That is
 * precisely the outcome this file's own docblock says is "worse than a skip,
 * because it reads as 'the adapters are verified'" — the reasoning was right and
 * it stopped one level too early.
 *
 * It is not hypothetical. Postgres and Redis get `--health-cmd` in ci.yml;
 * Meilisearch is the one service with none, and the probe here is a 1.5s TCP
 * connect fired at the very start of the run. A cold `getmeili/meilisearch`
 * container that has not finished binding its port loses that race and the
 * search suites vanish silently.
 *
 * `CI` is set to "true" by GitHub Actions on every runner.
 */
function required(service: string, url: string): never {
  throw new Error(
    `[${service}] unreachable at ${url}, and CI is set.\n` +
      `  ci.yml declares this service, so "not running" is a broken job, not a\n` +
      `  local convenience. Skipping here would pass the build with the ${service}\n` +
      `  suites never executed — a green tick over tests that did not run.\n` +
      `  Check the service container started and is health-gated before this step.`,
  );
}

export default async function globalSetup(): Promise<void> {
  config({ path: resolve(__dirname, "..", ".env") });
  const inCi = process.env.CI === "true" || process.env.CI === "1";

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
  if (!up && inCi) required("redis", `${host}:${port}`);
  process.env.REDIS_AVAILABLE = up ? "1" : "0";

  // Same treatment for Meilisearch: decide before describes register, so an
  // absent server yields `skipped`, never a green tick.
  const meili = process.env.MEILISEARCH_HOST ?? "http://localhost:7700";
  let mHost = "localhost";
  let mPort = 7700;
  try {
    const mu = new URL(meili);
    mHost = mu.hostname || mHost;
    mPort = Number(mu.port || 7700);
  } catch {
    /* keep defaults */
  }
  const meiliUp = await probe(mHost, mPort);
  if (!meiliUp && inCi) required("meili", `${mHost}:${mPort}`);
  process.env.MEILI_AVAILABLE = meiliUp ? "1" : "0";
  // eslint-disable-next-line no-console
  console.log(
    meiliUp
      ? `[meili] reachable at ${mHost}:${mPort} — search suites WILL run.`
      : `[meili] unreachable at ${mHost}:${mPort} — search suites will be SKIPPED (not passed).`,
  );

  // eslint-disable-next-line no-console
  console.log(
    up
      ? `\n[redis] reachable at ${host}:${port} — Redis adapter suites WILL run.`
      : `\n[redis] unreachable at ${host}:${port} — Redis adapter suites will be SKIPPED (not passed).\n` +
        `        Start it with: docker compose up -d\n`,
  );
}