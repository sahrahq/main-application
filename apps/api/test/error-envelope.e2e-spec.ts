/**
 * The error envelope — doc 06 §1.
 *
 * WRITTEN BEFORE THE IMPLEMENTATION — nothing under src/shared/errors/ exists.
 *
 *   { "error": { "code", "message", "message_ar", "details"?, "request_id" } }
 *
 * This is a SHAPE change, not a semantics change: every status code stays
 * exactly what it is today.
 *
 * It lands before the Flutter apps because every screen that shows a failure
 * parses this. Changing it after the client exists means rewriting error
 * handling in every screen instead of in one file.
 *
 * Two things the envelope has to get right at once:
 *
 *   - The server never picks the language. Both `message` and `message_ar`
 *     travel on every error and the client chooses, because the locale lives
 *     in the app's settings, not in an Accept-Language header we half-trust.
 *
 *   - An unhandled exception tells the client nothing about our internals. No
 *     stack, no file path, no SQL, no Prisma error body. That detail is real
 *     and useful, so it goes to the server log, keyed by the same request_id
 *     the client is holding.
 */
import { INestApplication, Controller, Get, Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { Prisma } from '@prisma/client';
import { AppModule } from '../src/app.module';
import { ErrorsModule } from '../src/shared/errors/errors.module';

/** Every error body in the API must satisfy this. */
function expectEnvelope(body: unknown): Record<string, unknown> {
  expect(body).toHaveProperty('error');
  const e = (body as { error: Record<string, unknown> }).error;
  expect(typeof e.code).toBe('string');
  expect((e.code as string).length).toBeGreaterThan(0);
  expect(typeof e.message).toBe('string');
  expect(typeof e.message_ar).toBe('string');
  expect((e.message_ar as string).length).toBeGreaterThan(0);
  expect(typeof e.request_id).toBe('string');
  // Nothing from the old shape may survive at the top level.
  expect(body).not.toHaveProperty('statusCode');
  expect(body).not.toHaveProperty('code');
  expect(body).not.toHaveProperty('message');
  return e;
}

// ───────────────────────────────────────────────── against the real API ──

describe('the envelope on real endpoints', () => {
  let app: INestApplication;
  let http: any;

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    await app.init();
    http = app.getHttpServer();
  }, 120_000);

  afterAll(async () => {
    if (app) await app.close();
  }, 60_000);

  it('wraps a DOMAIN error and keeps its machine-readable code', async () => {
    const res = await request(http).get('/restaurants/search?price_band=9');
    expect(res.status).toBe(400); // unchanged
    const e = expectEnvelope(res.body);
    expect(e.code).toBe('invalid_query_param');
  }, 60_000);

  it('carries BOTH languages so the client picks, not the server', async () => {
    const res = await request(http).get(
      `/restaurants/search?available_at=${new Date().toISOString().slice(0, 10)}`,
    );
    const e = expectEnvelope(res.body);
    expect(e.code).toBe('invalid_availability_filter');
    expect(e.message).not.toBe(e.message_ar);
    // The Arabic string must actually be Arabic, not an English fallback.
    expect(e.message_ar as string).toMatch(/[؀-ۿ]/);
  }, 60_000);

  it('gives a 404 for a real resource that does not exist', async () => {
    const res = await request(http).get(
      `/restaurants/${randomUUID()}/availability?date=2030-01-01&party_size=2`,
    );
    expect(res.status).toBe(404);
    expect(expectEnvelope(res.body).code).toBe('restaurant_not_found');
  }, 60_000);

  it('wraps framework errors that carry no code of their own', async () => {
    // ParseUUIDPipe rejects this before any of our code runs. It still has to
    // come back in the envelope, with a code derived from the status.
    const res = await request(http).get('/restaurants/not-a-uuid/availability?date=2030-01-01&party_size=2');
    expect(res.status).toBe(400);
    expect(expectEnvelope(res.body).code).toBe('bad_request');
  }, 60_000);

  it('wraps an unknown route', async () => {
    const res = await request(http).get('/no-such-endpoint');
    expect(res.status).toBe(404);
    expect(expectEnvelope(res.body).code).toBe('not_found');
  }, 60_000);

  it('keeps validation structured enough to highlight the field', async () => {
    const res = await request(http)
      .post('/auth/register')
      .send({ phone: 'nonsense', fullName: 'x' });

    expect(res.status).toBe(400);
    const e = expectEnvelope(res.body);
    expect(e.code).toBe('validation_failed');

    const details = e.details as { field: string; issue: string }[];
    expect(Array.isArray(details)).toBe(true);
    expect(details.length).toBeGreaterThan(0);
    for (const d of details) {
      expect(typeof d.field).toBe('string');
      expect(typeof d.issue).toBe('string');
    }
    // Both offending fields are named: phone fails its pattern, fullName is
    // below MinLength(2). A client cannot highlight what it is not told.
    const fields = details.map((d) => d.field);
    expect(fields).toContain('phone');
    expect(fields).toContain('fullName');
  }, 60_000);

  it('rejects unknown fields and names them (forbidNonWhitelisted)', async () => {
    const res = await request(http)
      .post('/auth/register')
      .send({ phone: '+201000000000', fullName: 'Valid Name', is_admin: true });

    expect(res.status).toBe(400);
    const e = expectEnvelope(res.body);
    expect((e.details as { field: string }[]).map((d) => d.field)).toContain('is_admin');
  }, 60_000);

  it('gives every response a request_id, and echoes it in a header', async () => {
    const res = await request(http).get('/no-such-endpoint');
    const e = expectEnvelope(res.body);
    expect(e.request_id).toBe(res.headers['x-request-id']);
    expect(e.request_id as string).toMatch(/^req_/);
  }, 60_000);

  it('honours a client-supplied X-Request-Id so logs can be correlated', async () => {
    const mine = 'req_client_supplied_123';
    const res = await request(http).get('/no-such-endpoint').set('X-Request-Id', mine);
    expect(expectEnvelope(res.body).request_id).toBe(mine);
  }, 60_000);

  it('does not change status codes — this is a shape change only', async () => {
    const cases: [string, number][] = [
      ['/no-such-endpoint', 404],
      ['/restaurants/search?price_band=9', 400],
      ['/restaurants/not-a-uuid/availability?date=2030-01-01&party_size=2', 400],
      [`/restaurants/${randomUUID()}/availability?date=2030-01-01&party_size=2`, 404],
    ];
    for (const [path, status] of cases) {
      expect((await request(http).get(path)).status).toBe(status);
    }
  }, 60_000);
});

// ───────────────────────────────────────── what must NEVER reach a client ──

/**
 * Failures that are not HttpExceptions, exercised against a minimal module.
 * A real endpoint cannot be made to throw a raw Prisma error on demand without
 * breaking it for everyone else, and these are exactly the cases where a leak
 * would happen.
 */
@Injectable()
class Boom {
  raw(): never {
    throw new Error('connect ECONNREFUSED 10.0.0.7:5432 at /srv/sahra/apps/api/src/secret-path.ts:42');
  }
}

@Controller('boom')
class BoomController {
  constructor(private readonly boom: Boom) {}

  @Get('raw')
  raw(): never {
    return this.boom.raw();
  }

  @Get('prisma')
  prisma(): never {
    throw new Prisma.PrismaClientKnownRequestError(
      'Unique constraint failed on the fields: (`phone`)\n  at /srv/sahra/node_modules/@prisma/client/runtime/library.js:121:5',
      { code: 'P2002', clientVersion: '6.2.1', meta: { target: ['users_phone_key'] } },
    );
  }

  @Get('sql')
  sql(): never {
    throw new Error(
      'db error: ERROR: duplicate key value violates unique constraint "idx_resv_active" DETAIL: Key (table_id)=(3f2a) already exists.',
    );
  }

  @Get('string')
  string(): never {
    throw 'a bare string, thrown by something careless';
  }

  /** The shape reservations.service.ts throws under lock contention. */
  @Get('busy')
  busy(): never {
    throw new HttpException(
      {
        code: 'service_busy',
        message: 'That restaurant is busy right now. Please try again in a moment.',
        message_ar: 'المطعم مزحوم دلوقتي. حاول تاني بعد لحظات.',
        retry_after: 3,
      },
      HttpStatus.SERVICE_UNAVAILABLE,
    );
  }
}

describe('an unhandled failure leaks nothing', () => {
  let app: INestApplication;
  let http: any;
  let logged: string[];

  beforeAll(async () => {
    const mod = await Test.createTestingModule({
      imports: [ErrorsModule],
      controllers: [BoomController],
      providers: [Boom],
    }).compile();
    app = mod.createNestApplication();
    // Silence the expected error logs, and capture them for the assertion that
    // the detail is kept SERVER-side rather than simply discarded.
    logged = [];
    jest.spyOn(require('@nestjs/common').Logger.prototype, 'error')
      .mockImplementation((...args: unknown[]) => {
        logged.push(args.map((a) => String(a)).join(' '));
      });
    await app.init();
    http = app.getHttpServer();
  }, 120_000);

  afterAll(async () => {
    jest.restoreAllMocks();
    if (app) await app.close();
  }, 60_000);

  const FORBIDDEN = [
    /ECONNREFUSED/i, /\/srv\//, /\.ts:\d+/, /\.js:\d+/, /node_modules/,
    /at [A-Za-z.]+ \(/, /prisma/i, /P2002/, /duplicate key/i, /constraint/i,
    /10\.0\.0\.7/, /5432/,
  ];

  it.each([['raw'], ['prisma'], ['sql'], ['string']])(
    '/boom/%s returns a generic 500 with no internal detail',
    async (path) => {
      const res = await request(http).get(`/boom/${path}`);

      expect(res.status).toBe(500);
      const e = expectEnvelope(res.body);
      expect(e.code).toBe('internal_error');
      expect(e.details).toBeUndefined();

      const serialised = JSON.stringify(res.body);
      for (const pattern of FORBIDDEN) {
        expect(serialised).not.toMatch(pattern);
      }
    },
    60_000,
  );

  it('logs the real detail server-side, keyed by the same request_id', async () => {
    logged.length = 0;
    const res = await request(http).get('/boom/raw');
    const requestId = (res.body as { error: { request_id: string } }).error.request_id;

    const joined = logged.join('\n');
    // The operator needs what the client must not get, and needs to be able to
    // tie it to the id the diner can read off their screen.
    expect(joined).toContain(requestId);
    expect(joined).toMatch(/ECONNREFUSED/);
  }, 60_000);

  it('promotes retry_after to the Retry-After header, and keeps it in the body', async () => {
    // doc 06 §1 lists Retry-After for 429; doc 05 §3 for the 503 under lock
    // contention. A client obeying standard HTTP semantics should not have to
    // parse our body to learn how long to wait — but the body keeps it too,
    // because the existing reservation contract carries it there.
    const res = await request(http).get('/boom/busy');

    expect(res.status).toBe(503); // unchanged
    const e = expectEnvelope(res.body);
    expect(e.code).toBe('service_busy');
    expect(e.retry_after).toBe(3);
    expect(res.headers['retry-after']).toBe('3');
  }, 60_000);

  it('a deliberate HttpException keeps its own wording — only raw errors are scrubbed', async () => {
    const e = expectEnvelope((await request(http).get('/boom/busy')).body);
    expect(e.message).toContain('busy right now');
    expect(e.message_ar).toContain('مزحوم');
  }, 60_000);

  it('a thrown non-Error does not produce a broken envelope', async () => {
    const res = await request(http).get('/boom/string');
    const e = expectEnvelope(res.body);
    expect(e.message).not.toBe('');
    expect(e.message_ar).not.toBe('');
  }, 60_000);
});
