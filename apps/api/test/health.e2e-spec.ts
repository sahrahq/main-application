/**
 * `/health`, and the 503 that makes a half-configured push impossible to miss.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THE SHAPE OF THE FAILURE THIS EXISTS FOR
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Firebase project `sahra-4881d` has an Android app and no APNs key. In that
 * state FCM accepts an iOS send and answers with a message id; the iPhone never
 * rings; nothing anywhere reports a problem. Android works, so a manual test
 * passes and the whole suite is green.
 *
 * A field in a 200 body would not have fixed that — a degraded state reported
 * inside a successful response is a degraded state nobody notices, because
 * every uptime check ever written looks at the status code. So it is the code.
 *
 * ── AND `/health` HAD BEEN 404 FOR WEEKS ────────────────────────────────
 *
 * `main.ts` has excluded `health` from the `/v1` prefix since the first commit
 * and no controller ever existed behind it. Nothing failed, because nothing
 * asked. Worth recording as its own small instance of the same lesson.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PUSH_READINESS, pushReadiness } from '../src/modules/notifications/push-readiness';

let app: INestApplication;
let http: unknown;

/** Boot with a given readiness, so both branches are reachable in a test. */
async function boot(projectId: string | null, env: NodeJS.ProcessEnv): Promise<void> {
  const mod = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(PUSH_READINESS)
    .useValue(pushReadiness(projectId, env))
    .compile();

  app = mod.createNestApplication();
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  await app.init();
  http = app.getHttpServer();
}

afterEach(async () => {
  if (app) await app.close();
});

describe('GET /health', () => {
  it('is NOT behind the /v1 prefix — an uptime check should not need to know', async () => {
    await boot('sahra-4881d', { FIREBASE_IOS_CONFIGURED: '1' } as NodeJS.ProcessEnv);
    await request(http as never).get('/v1/health').expect(404);
    await request(http as never).get('/health').expect(200);
  });

  it('needs no token — it is read by machines with no account', async () => {
    await boot('sahra-4881d', { FIREBASE_IOS_CONFIGURED: '1' } as NodeJS.ProcessEnv);
    const res = await request(http as never).get('/health').expect(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.reasons).toEqual([]);
  });

  // ══════════════════════════════════════════════════════════════════════
  //  THE ONE THAT MATTERS.
  // ══════════════════════════════════════════════════════════════════════
  describe('Android configured, iOS not — the state shipped on 2026-08-10', () => {
    beforeEach(() => boot('sahra-4881d', {} as NodeJS.ProcessEnv));

    it('answers 503, not a 200 with a sad field in it', async () => {
      const res = await request(http as never).get('/health').expect(503);
      expect(res.body.status).toBe('degraded');
    });

    it('names iOS, and says why', async () => {
      const res = await request(http as never).get('/health').expect(503);
      expect(res.body.push.unreachable).toContain('ios');
      expect(res.body.reasons.join(' ')).toMatch(/APNs/);
    });

    it('and still reports that ANDROID works — half-configured is not broken', async () => {
      // A health check that only said "degraded" would send somebody hunting
      // for a total outage. The useful answer is which half works.
      const res = await request(http as never).get('/health').expect(503);
      expect(res.body.push.deliverable).toEqual(['android']);
      expect(res.body.push.configured).toBe(true);
      expect(res.body.push.project_id).toBe('sahra-4881d');
    });

    it('the body has the SAME SHAPE as the healthy one', async () => {
      // It answers through `@Res({passthrough})` rather than by throwing,
      // specifically so the doc 06 §1 error filter does not reshape it into an
      // error envelope. A health check whose payload changes shape when it is
      // unhealthy is one nothing can parse.
      const bad = await request(http as never).get('/health').expect(503);
      await app.close();
      await boot('sahra-4881d', { FIREBASE_IOS_CONFIGURED: '1' } as NodeJS.ProcessEnv);
      const good = await request(http as never).get('/health').expect(200);

      expect(Object.keys(bad.body).sort()).toEqual(Object.keys(good.body).sort());
      expect(Object.keys(bad.body.push).sort()).toEqual(Object.keys(good.body.push).sort());
      // And it is NOT the error envelope.
      expect(bad.body.error).toBeUndefined();
    });
  });

  it('reports degraded when push is not configured at all', async () => {
    // Local development and CI. Still 503 — "we cannot reach anybody" is not a
    // healthy state to report as ok, even when it is the expected one.
    await boot(null, {} as NodeJS.ProcessEnv);
    const res = await request(http as never).get('/health').expect(503);
    expect(res.body.push.configured).toBe(false);
    expect(res.body.push.deliverable).toEqual([]);
  });

  it('web alone never degrades it', async () => {
    // Out of scope (doc 02 — iOS and Android only), not broken. An alarm that
    // is permanently on is the same as one that is off.
    await boot('sahra-4881d', { FIREBASE_IOS_CONFIGURED: '1' } as NodeJS.ProcessEnv);
    const res = await request(http as never).get('/health').expect(200);
    expect(res.body.push.unreachable).toEqual(['web']);
    expect(res.body.status).toBe('ok');
  });
});
