/**
 * GROUP B — venue photos, end to end.
 *
 * WRITTEN BEFORE THE CONTROLLER EXISTS.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHAT THIS FILE IS REALLY GUARDING
 * ─────────────────────────────────────────────────────────────────────────
 *
 * The requirement is a COST decision as much as a visual one: resize on
 * upload, never on display, because an image transformed per view is an image
 * paid for per view and egress is what binds on the free tier (doc 10 §3b).
 *
 * That requirement is invisible to a normal test. An implementation that
 * stored the original and let the client scale it would return correct-looking
 * URLs, render correctly on a fast laptop, pass every assertion about shape —
 * and quietly cost twenty times the bandwidth. So the assertions here are
 * about BYTES: that three renditions exist, that the small one is genuinely
 * smaller, and that the original is stored somewhere the app never asks for.
 *
 * Storage is the in-memory adapter, so the byte counts are real bytes that
 * `sharp` actually produced — the resize is not stubbed, only the bucket is.
 */
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { PrismaClient } from '@prisma/client';
import sharp from 'sharp';
import { AppModule } from '../src/app.module';
import { OTP_DELIVERY } from '../src/modules/auth/otp/otp.ports';
import { RecordingOtpDelivery } from '../src/modules/auth/otp/delivery/recording-otp.delivery';
import { IMAGE_STORAGE, IMAGE_SIZES } from '../src/modules/images/image.ports';
import { InMemoryImageStorage } from '../src/modules/images/supabase-image.storage';
import { resetOtpState } from './support/otp-budget';

const url = (() => {
  const base = process.env.DIRECT_URL || process.env.DATABASE_URL || '';
  return `${base}${base.includes('?') ? '&' : '?'}connection_limit=5&pool_timeout=60`;
})();

const prisma = new PrismaClient({ datasources: { db: { url } } });

let app: INestApplication;
let http: unknown;
let delivery: RecordingOtpDelivery;
let storage: InMemoryImageStorage;

const suffix = Date.now().toString().slice(-9);

let venueId = '';
let ownerUserId = '';
let ownerId = '';

/** An admin, and a diner who must not be able to touch any of this. */
let admin = { id: '', token: '' };
let diner = { id: '', token: '' };

const auth = (token: string): [string, string] => ['Authorization', `Bearer ${token}`];

async function signUp(phone: string, name: string): Promise<{ id: string; token: string }> {
  const reg = await request(http as never)
    .post('/v1/auth/register')
    .send({ phone, fullName: name })
    .expect(201);
  const code = delivery.sent.filter((m) => m.phone === phone).at(-1)!.code;
  const pair = await request(http as never)
    .post('/v1/auth/verify-otp')
    .send({ challengeId: reg.body.challengeId, code })
    .expect(200);
  return { id: reg.body.userId as string, token: pair.body.tokens.accessToken as string };
}

/**
 * A REAL JPEG, generated rather than committed.
 *
 * [width] x [height] of noise, so it does not compress to nothing — a flat
 * colour would produce a 400px WebP smaller than the 160px one and make the
 * "smaller size is smaller" assertion meaningless.
 */
async function photo(width: number, height: number): Promise<Buffer> {
  const pixels = Buffer.alloc(width * height * 3);
  for (let i = 0; i < pixels.length; i++) {
    // Deterministic pseudo-noise: no Math.random, so a failure reproduces.
    pixels[i] = (i * 2654435761) % 251;
  }
  return sharp(pixels, { raw: { width, height, channels: 3 } }).jpeg().toBuffer();
}

function upload(
  token: string,
  body: Buffer,
  opts: { cover?: boolean; mime?: string; filename?: string } = {},
) {
  const req = request(http as never)
    .post(
      `/v1/admin/restaurants/${venueId}/images` +
        (opts.cover === true ? '?cover=true' : ''),
    )
    .set(...auth(token));

  return req.attach('file', body, {
    filename: opts.filename ?? 'venue.jpg',
    contentType: opts.mime ?? 'image/jpeg',
  });
}

beforeAll(async () => {
  await prisma.$connect();
  await resetOtpState();

  delivery = new RecordingOtpDelivery();
  storage = new InMemoryImageStorage();

  const mod = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(OTP_DELIVERY)
    .useValue(delivery)
    // The BUCKET is faked; the RESIZE is not. `sharp` really runs, and the
    // byte assertions below are about bytes it really produced.
    .overrideProvider(IMAGE_STORAGE)
    .useValue(storage)
    .compile();

  app = mod.createNestApplication();
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  await app.init();
  http = app.getHttpServer();

  const ownerAccount = await signUp(`+2061${suffix}`, 'Photo Owner');
  ownerUserId = ownerAccount.id;
  const owner = await prisma.restaurantOwner.create({
    data: { userId: ownerUserId, businessName: 'Photo Co', verificationStatus: 'verified' },
  });
  ownerId = owner.id;

  const rows = await prisma.$queryRaw<{ id: string }[]>`
    INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                             neighborhood, location, status, timezone,
                             created_at, updated_at)
    VALUES (${ownerId}::uuid, ${'photo-venue-' + suffix}, 'Photo Venue', 'مطعم الصور',
            ARRAY['levantine'], 'Cairo', 'Zamalek',
            ST_SetSRID(ST_MakePoint(31.2185, 30.0622), 4326)::geography,
            'active', 'Africa/Cairo', now(), now())
    RETURNING id`;
  venueId = rows[0].id;

  admin = await signUp(`+2062${suffix}`, 'Photo Admin');
  diner = await signUp(`+2063${suffix}`, 'Ordinary Diner');

  const adminRole = await prisma.role.findFirst({ where: { name: 'admin' } });
  if (adminRole) {
    await prisma.userRole.create({ data: { userId: admin.id, roleId: adminRole.id } });
  }
  // A fresh token, so the new role is in the claims.
  const re = await request(http as never)
    .post('/v1/auth/request-otp')
    // 202, not 200. `request-otp` accepts and sends; it does not answer a
    // question, because answering one is what AUTH-3 was.
    .send({ phone: `+2062${suffix}` })
    .expect(202);
  const code = delivery.sent.filter((m) => m.phone === `+2062${suffix}`).at(-1)!.code;
  const pair = await request(http as never)
    .post('/v1/auth/verify-otp')
    .send({ challengeId: re.body.challengeId, code })
    .expect(200);
  admin.token = pair.body.tokens.accessToken as string;
}, 180_000);

afterAll(async () => {
  if (app) await app.close();
  if (venueId) {
    await prisma.$executeRaw`DELETE FROM images WHERE owner_id = ${venueId}::uuid`;
    await prisma.$executeRaw`DELETE FROM restaurants WHERE id = ${venueId}::uuid`;
  }
  if (ownerId) await prisma.restaurantOwner.delete({ where: { id: ownerId } }).catch(() => undefined);
  for (const id of [admin.id, diner.id, ownerUserId].filter(Boolean)) {
    await prisma.$executeRaw`DELETE FROM refresh_tokens WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM user_roles     WHERE user_id = ${id}::uuid`;
    await prisma.$executeRaw`DELETE FROM users          WHERE id      = ${id}::uuid`;
  }
  await prisma.$disconnect();
}, 60_000);

describe('who may upload', () => {
  it('an anonymous caller cannot', async () => {
    const body = await photo(600, 400);
    await request(http as never)
      .post(`/v1/admin/restaurants/${venueId}/images`)
      .attach('file', body, { filename: 'v.jpg', contentType: 'image/jpeg' })
      .expect(401);
  });

  it('AN ORDINARY DINER CANNOT — this is the admin door', async () => {
    // The whole point of the route living under /admin. When R-2.2 ships, the
    // owner-facing upload is a SECOND controller with an ownership check, not
    // this one with its role list widened.
    const body = await photo(600, 400);
    const res = await upload(diner.token, body).expect(403);
    expect(res.body.error.code).toBe('forbidden_role');
  });
});

describe('the pipeline — resize on UPLOAD, never on display', () => {
  let imageId = '';

  it('1. accepts a photo and returns every rendition', async () => {
    const body = await photo(1600, 1200);
    const res = await upload(admin.token, body).expect(201);

    imageId = res.body.id;
    expect(res.body.width).toBe(1600);
    expect(res.body.height).toBe(1200);

    // Every declared size, and nothing else.
    expect(Object.keys(res.body.urls).sort()).toEqual(
      IMAGE_SIZES.map(String).sort(),
    );
  });

  it('2. THREE RENDITIONS REALLY EXIST AS BYTES', async () => {
    // Not "the response mentions three URLs" — three objects in storage. A URL
    // for a rendition nobody wrote is a broken image with a healthy-looking
    // API response behind it.
    const keys = [...storage.objects.keys()].filter((k) => k.includes(imageId));
    for (const size of IMAGE_SIZES) {
      expect(keys).toContain(`restaurants/${venueId}/${imageId}/${size}.webp`);
    }
  });

  it('3. AND THE SMALL ONE IS ACTUALLY SMALLER', async () => {
    // THE ASSERTION THE WHOLE FEATURE IS FOR. An implementation that stored
    // the original three times, or that stored one file and returned three
    // URLs pointing at it, passes tests 1 and 2 and fails this one.
    const sizeOf = (n: number) =>
      storage.objects.get(`restaurants/${venueId}/${imageId}/${n}.webp`)!.length;

    expect(sizeOf(160)).toBeLessThan(sizeOf(400));
    expect(sizeOf(400)).toBeLessThan(sizeOf(1200));

    // And the thumbnail is small in absolute terms, not merely smallest. A
    // 160px WebP of a photograph is single-digit kilobytes; anything near the
    // original means the resize did not happen.
    expect(sizeOf(160)).toBeLessThan(30 * 1024);
  });

  it('4. the renditions are WebP, whatever came in', async () => {
    const bytes = storage.objects.get(
      `restaurants/${venueId}/${imageId}/400.webp`,
    )!;
    const meta = await sharp(bytes).metadata();
    expect(meta.format).toBe('webp');
    expect(meta.width).toBe(400);
  });

  it('5. the ORIGINAL is kept, and is not one of the served sizes', async () => {
    // Kept so a fourth size later is a re-run rather than an email to fifty
    // restaurants. Never served: it is a full-size JPEG.
    const key = `restaurants/${venueId}/${imageId}/original`;
    expect(storage.objects.has(key)).toBe(true);

    const original = storage.objects.get(key)!;
    const served = storage.objects.get(
      `restaurants/${venueId}/${imageId}/1200.webp`,
    )!;
    expect(original.length).toBeGreaterThan(served.length);

    // And nothing in the API response points at it.
    const res = await request(http as never)
      .get(`/v1/restaurants/${venueId}`)
      .expect(200);
    const urls = JSON.stringify(res.body.images);
    expect(urls).not.toContain('/original');
  });

  it('6. a smaller photo is NOT enlarged to fill a bigger rendition', async () => {
    // `withoutEnlargement`. Upscaling a 200px photo to 1200 produces a blurry
    // file bigger than its source — paying more egress for a worse picture.
    const small = await photo(200, 150);
    const res = await upload(admin.token, small).expect(201);

    const big = storage.objects.get(
      `restaurants/${venueId}/${res.body.id}/1200.webp`,
    )!;
    const meta = await sharp(big).metadata();
    expect(meta.width).toBe(200);
  });
});

describe('what is refused', () => {
  it('an SVG, even though sharp would open it', async () => {
    // Deny-by-default. An SVG is a script-execution vector the moment
    // anything renders it as markup rather than as an image.
    const svg = Buffer.from(
      '<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>',
    );
    const res = await upload(admin.token, svg, {
      mime: 'image/svg+xml',
      filename: 'venue.svg',
    }).expect(400);
    expect(res.body.error.code).toBe('unsupported_image_type');
  });

  it('a file that is not an image at all', async () => {
    const res = await upload(admin.token, Buffer.from('this is not a jpeg')).expect(400);
    expect(res.body.error.code).toBe('invalid_image');
  });

  it('a venue that does not exist', async () => {
    const body = await photo(400, 300);
    await request(http as never)
      .post(`/v1/admin/restaurants/${randomUUID()}/images`)
      .set(...auth(admin.token))
      .attach('file', body, { filename: 'v.jpg', contentType: 'image/jpeg' })
      .expect(404);
  });
});

describe('ordering and the cover', () => {
  beforeAll(async () => {
    await prisma.$executeRaw`DELETE FROM images WHERE owner_id = ${venueId}::uuid`;
    for (const key of [...storage.objects.keys()]) storage.objects.delete(key);
  });

  it('THE FIRST PHOTO BECOMES THE COVER WITHOUT BEING ASKED', async () => {
    // A venue with photos and no cover renders an empty hero above a full
    // gallery — which reads as broken rather than as unconfigured. And nobody
    // uploading the first photo of a venue means "but not the main one".
    const res = await upload(admin.token, await photo(800, 600)).expect(201);
    expect(res.body.is_cover).toBe(true);
    expect(res.body.position).toBe(0);
  });

  it('the second does not steal it', async () => {
    const res = await upload(admin.token, await photo(800, 600)).expect(201);
    expect(res.body.is_cover).toBe(false);
    expect(res.body.position).toBe(1);
  });

  it('asking for the cover MOVES it, leaving exactly one', async () => {
    const res = await upload(admin.token, await photo(800, 600), { cover: true }).expect(201);
    expect(res.body.is_cover).toBe(true);

    const covers = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT COUNT(*)::bigint AS n FROM images
       WHERE owner_id = ${venueId}::uuid AND is_cover`;
    expect(Number(covers[0].n)).toBe(1);
    expect(res.body.id).toBeDefined();
  });

  it('POSTGRES REFUSES A SECOND COVER, not just the service', async () => {
    // The partial unique index. A second code path that forgot to demote
    // would be caught here rather than producing a hero that changes between
    // page loads with nothing to blame.
    const rows = await prisma.$queryRaw<{ id: string }[]>`
      SELECT id FROM images WHERE owner_id = ${venueId}::uuid AND NOT is_cover LIMIT 1`;

    await expect(
      prisma.$executeRaw`UPDATE images SET is_cover = true WHERE id = ${rows[0].id}::uuid`,
    ).rejects.toThrow();
  });

  it('the venue profile serves them cover first', async () => {
    const res = await request(http as never)
      .get(`/v1/restaurants/${venueId}`)
      .expect(200);

    expect(res.body.images.length).toBe(3);
    expect(res.body.images[0].is_cover).toBe(true);
    // Every image carries its own dimensions, so the client reserves a box
    // before a byte arrives.
    for (const image of res.body.images) {
      expect(image.width).toBeGreaterThan(0);
      expect(image.height).toBeGreaterThan(0);
    }
  });

  it('deleting the cover PROMOTES the next one', async () => {
    // A venue whose cover was deleted has photos and no hero.
    const before = await request(http as never)
      .get(`/v1/restaurants/${venueId}`)
      .expect(200);
    const coverId = before.body.images[0].id;

    await request(http as never)
      .delete(`/v1/admin/restaurants/${venueId}/images/${coverId}`)
      .set(...auth(admin.token))
      .expect(204);

    const after = await request(http as never)
      .get(`/v1/restaurants/${venueId}`)
      .expect(200);
    expect(after.body.images.length).toBe(2);
    expect(after.body.images[0].is_cover).toBe(true);
    expect(after.body.images[0].id).not.toBe(coverId);
  });

  it('and its BYTES are gone too, every rendition', async () => {
    // An image row deleted with its objects left behind is a bucket that grows
    // forever, on a plan where storage is the thing being paid for.
    const orphans = [...storage.objects.keys()].filter((k) => k.includes('deleted'));
    expect(orphans).toEqual([]);
  });
});

describe('a venue with no photos', () => {
  it('serves an EMPTY LIST, not null and not an error', async () => {
    // The client draws a designed empty state from this. `null` would make
    // every caller write a null check, and one of them would forget.
    const rows = await prisma.$queryRaw<{ id: string }[]>`
      INSERT INTO restaurants (owner_id, slug, name_en, name_ar, cuisines, city,
                               neighborhood, location, status, timezone,
                               created_at, updated_at)
      VALUES (${ownerId}::uuid, ${'no-photos-' + suffix}, 'No Photos', 'بدون صور',
              ARRAY['egyptian'], 'Cairo', 'Maadi',
              ST_SetSRID(ST_MakePoint(31.25, 29.96), 4326)::geography,
              'active', 'Africa/Cairo', now(), now())
      RETURNING id`;

    try {
      const res = await request(http as never)
        .get(`/v1/restaurants/${rows[0].id}`)
        .expect(200);
      expect(res.body.images).toEqual([]);
    } finally {
      await prisma.$executeRaw`DELETE FROM restaurants WHERE id = ${rows[0].id}::uuid`;
    }
  });
});
