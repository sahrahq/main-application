import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ImageStorage, StoredObject } from './image.ports';

/**
 * Supabase Storage over its S3-compatible REST API.
 *
 * NO `@supabase/supabase-js`. The client library is a large dependency that is
 * not in the stack table, and this needs exactly three operations — PUT an
 * object, DELETE a prefix, and know the public URL. `fetch` is in Node 22.
 * Adding a SDK to avoid writing thirty lines would be the wrong trade and
 * would need its own approval.
 *
 * ── CONFIGURATION, AND FAILING LOUDLY WITHOUT IT ─────────────────────────
 *
 * `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` are required in production and the
 * module refuses to construct without them. A storage adapter that silently
 * falls back to "pretend it worked" is the decoy pattern in a different hat:
 * uploads would report success, the database would grow rows, and every venue
 * would render an empty state that looks exactly like a venue with no photos.
 */
@Injectable()
export class SupabaseImageStorage implements ImageStorage {
  private readonly logger = new Logger(SupabaseImageStorage.name);

  constructor(
    private readonly baseUrl: string,
    private readonly serviceKey: string,
    private readonly bucket: string,
  ) {}

  /**
   * Built from the environment, refusing to exist when it cannot work.
   *
   * The check is on the VALUES, not on `NODE_ENV`. A staging box with a blank
   * key is as broken as production with one, and finding out at boot is
   * cheaper than finding out from a restaurant asking where their photos went.
   */
  static fromEnv(env: NodeJS.ProcessEnv): SupabaseImageStorage {
    const url = env.SUPABASE_URL?.replace(/\/+$/, '') ?? '';
    const key = env.SUPABASE_SERVICE_KEY ?? '';
    const bucket = env.SUPABASE_IMAGE_BUCKET ?? 'venue-photos';

    if (!url || !key) {
      throw new Error(
        'SUPABASE_URL and SUPABASE_SERVICE_KEY are required for image uploads. ' +
          'Set them, or register InMemoryImageStorage explicitly for a local run ' +
          '— there is deliberately no silent fallback.',
      );
    }
    return new SupabaseImageStorage(url, key, bucket);
  }

  async put(key: string, body: Buffer, contentType: string): Promise<StoredObject> {
    const res = await fetch(`${this.baseUrl}/storage/v1/object/${this.bucket}/${key}`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${this.serviceKey}`,
        'content-type': contentType,
        // Overwrite, so re-running the resizer over an original is safe and
        // idempotent rather than producing `photo (2)`.
        'x-upsert': 'true',
        // A year, immutable. The key contains the image id and the size, so a
        // given URL's bytes never change — which is what makes a long cache
        // safe rather than a way to serve stale photos.
        'cache-control': 'public, max-age=31536000, immutable',
      },
      body: new Uint8Array(body),
    });

    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      this.logger.error(`Storage PUT ${key} failed: ${res.status} ${detail}`);
      throw new HttpException(
        {
          code: 'storage_unavailable',
          message: 'We could not store that image. Please try again.',
          message_ar: 'مقدرناش نحفظ الصورة. حاول تاني.',
        },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    return { key, bytes: body.length };
  }

  async remove(prefix: string): Promise<void> {
    const listed = await fetch(`${this.baseUrl}/storage/v1/object/list/${this.bucket}`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${this.serviceKey}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ prefix, limit: 100 }),
    });

    if (!listed.ok) return;
    const objects = (await listed.json()) as { name: string }[];
    if (objects.length === 0) return;

    await fetch(`${this.baseUrl}/storage/v1/object/${this.bucket}`, {
      method: 'DELETE',
      headers: {
        authorization: `Bearer ${this.serviceKey}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ prefixes: objects.map((o) => `${prefix}/${o.name}`) }),
    });
  }

  publicUrl(key: string): string {
    return `${this.baseUrl}/storage/v1/object/public/${this.bucket}/${key}`;
  }
}

/**
 * Storage that keeps bytes in a Map. For tests and for a local run with no
 * Supabase credentials.
 *
 * REGISTERED EXPLICITLY, never as a fallback. `SupabaseImageStorage.fromEnv`
 * throws rather than returning this, because the whole failure mode worth
 * preventing is an environment that thinks it is storing photos and is not.
 */
@Injectable()
export class InMemoryImageStorage implements ImageStorage {
  readonly objects = new Map<string, Buffer>();

  async put(key: string, body: Buffer): Promise<StoredObject> {
    this.objects.set(key, body);
    return { key, bytes: body.length };
  }

  async remove(prefix: string): Promise<void> {
    for (const key of [...this.objects.keys()]) {
      if (key.startsWith(prefix)) this.objects.delete(key);
    }
  }

  publicUrl(key: string): string {
    // A shape a client can hold and a test can assert on, that is obviously
    // not a real CDN address if one ever leaked into a fixture.
    return `http://localhost/images/${key}`;
  }
}
