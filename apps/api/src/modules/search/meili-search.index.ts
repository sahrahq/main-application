import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import {
  RestaurantIndexPort,
  RestaurantSearchDoc,
  IndexQuery,
  IndexHits,
} from './search.port';

export const DEFAULT_INDEX_UID = 'restaurants';

/**
 * Meilisearch adapter (doc 06 §3), over its REST API with `fetch`.
 *
 * No client library on purpose. `meilisearch@0.60` is ESM-only and the API is
 * a CommonJS Nest build, so the official client would have forced either a
 * pinned two-year-old release or a module-system change across the whole
 * service. The surface actually used here is six endpoints; absorbing that is
 * what RestaurantIndexPort exists for, and it keeps the stack table
 * (DEVELOPMENT.md §2) unchanged.
 *
 * Only `id` is read back from a hit — every displayed field is re-read from
 * Postgres by the caller. Meilisearch decides the ORDER and the MEMBERSHIP of
 * the result set; nothing more.
 */
@Injectable()
export class MeiliSearchIndex extends RestaurantIndexPort {
  private readonly logger = new Logger(MeiliSearchIndex.name);
  private readonly base: string;
  private readonly apiKey?: string;
  private readonly uid: string;
  private ready = false;

  constructor(host: string, apiKey?: string, uid: string = DEFAULT_INDEX_UID) {
    super();
    this.base = host.replace(/\/+$/, '');
    this.apiKey = apiKey || undefined;
    this.uid = uid;
  }

  /**
   * Create the index and pin its settings. Idempotent — safe on every boot.
   *
   * `nameAr` is searchable alongside `nameEn` because SAHRA is bilingual by
   * column (CLAUDE.md): a diner typing "زوبا" and a diner typing "Zooba" are
   * looking for the same venue, and neither should have to know which language
   * the listing was created in.
   */
  async ensureIndex(): Promise<void> {
    // 409 index_already_exists is the expected steady state, not an error.
    await this.request('POST', '/indexes', { uid: this.uid, primaryKey: 'id' }, [409]);

    const task = await this.request<{ taskUid: number }>(
      'PATCH',
      `/indexes/${this.uid}/settings`,
      {
        searchableAttributes: ['nameEn', 'nameAr', 'cuisines', 'neighborhood', 'city'],
        filterableAttributes: [
          'cuisines', 'neighborhood', 'city', 'priceBand', 'rating', 'amenities', '_geo',
        ],
        sortableAttributes: ['rating', 'ratingCount', '_geo'],
        // Arabic and English tokenise differently; naming both stops Meili
        // guessing per document and mis-stemming short Arabic names.
        localizedAttributes: [
          { attributePatterns: ['nameAr'], locales: ['ara'] },
          { attributePatterns: ['nameEn', 'neighborhood', 'city'], locales: ['eng'] },
        ],
      },
    );
    await this.waitForTask(task.taskUid);
    this.ready = true;
  }

  async upsert(docs: RestaurantSearchDoc[]): Promise<void> {
    if (docs.length === 0) return;
    await this.request('POST', `/indexes/${this.uid}/documents?primaryKey=id`, docs);
  }

  async remove(ids: string[]): Promise<void> {
    if (ids.length === 0) return;
    await this.request('POST', `/indexes/${this.uid}/documents/delete-batch`, ids);
  }

  async query(q: IndexQuery): Promise<IndexHits> {
    const filter = this.buildFilter(q);
    const sort = this.buildSort(q);
    try {
      const res = await this.request<{
        hits: { id: string }[];
        estimatedTotalHits?: number;
      }>('POST', `/indexes/${this.uid}/search`, {
        q: q.q?.trim() || '',
        limit: q.limit,
        offset: q.offset,
        ...(filter.length ? { filter } : {}),
        ...(sort ? { sort } : {}),
        // Only the key. Everything else is hydrated from Postgres.
        attributesToRetrieve: ['id'],
      });
      return {
        ids: res.hits.map((h) => h.id),
        estimatedTotal: res.estimatedTotalHits ?? res.hits.length,
      };
    } catch (err) {
      // A search outage must read as an outage. Returning [] would tell the
      // diner "no restaurants match", which is a lie the client would cache.
      this.logger.error(`Meilisearch query failed: ${(err as Error).message}`);
      throw new ServiceUnavailableException({
        code: 'search_unavailable',
        message: 'Search is temporarily unavailable. Please try again.',
        message_ar: 'البحث غير متاح مؤقتًا. برجاء المحاولة مرة أخرى.',
      });
    }
  }

  /**
   * Wait out every enqueued/processing task on this index.
   *
   * Meilisearch indexes asynchronously: a 202 from addDocuments means accepted,
   * not visible. Anything that must read its own write goes through here.
   */
  async waitForIdle(timeoutMs = 30_000): Promise<void> {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const pending = await this.request<{ results: unknown[] }>(
        'GET',
        `/tasks?indexUids=${encodeURIComponent(this.uid)}&statuses=enqueued,processing&limit=1`,
      );
      if (pending.results.length === 0) return;
      await new Promise((r) => setTimeout(r, 100));
    }
    this.logger.warn(`Index ${this.uid} still had pending tasks after ${timeoutMs}ms`);
  }

  /** Every id currently in the index — the reindex orphan sweep. */
  async allDocumentIds(): Promise<string[]> {
    const ids: string[] = [];
    const page = 1000;
    for (let offset = 0; ; offset += page) {
      const res = await this.request<{ results: { id: string }[] }>(
        'GET',
        `/indexes/${this.uid}/documents?limit=${page}&offset=${offset}&fields=id`,
      );
      ids.push(...res.results.map((d) => d.id));
      if (res.results.length < page) return ids;
    }
  }

  /** Test teardown only. */
  async dropIndex(): Promise<void> {
    await this.request('DELETE', `/indexes/${this.uid}`, undefined, [404]).catch(() => undefined);
  }

  isReady(): boolean {
    return this.ready;
  }

  private async waitForTask(taskUid: number, timeoutMs = 30_000): Promise<void> {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const t = await this.request<{ status: string; error?: { message: string } }>(
        'GET',
        `/tasks/${taskUid}`,
      );
      if (t.status === 'succeeded') return;
      if (t.status === 'failed' || t.status === 'canceled') {
        throw new Error(`Meilisearch task ${taskUid} ${t.status}: ${t.error?.message ?? ''}`);
      }
      await new Promise((r) => setTimeout(r, 100));
    }
    throw new Error(`Meilisearch task ${taskUid} did not settle within ${timeoutMs}ms`);
  }

  private async request<T = unknown>(
    method: string,
    path: string,
    body?: unknown,
    tolerate: number[] = [],
  ): Promise<T> {
    const res = await fetch(`${this.base}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(this.apiKey ? { Authorization: `Bearer ${this.apiKey}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

    if (!res.ok && !tolerate.includes(res.status)) {
      const detail = await res.text().catch(() => '');
      throw new Error(`Meilisearch ${method} ${path} → ${res.status} ${detail.slice(0, 300)}`);
    }
    if (res.status === 204) return undefined as T;
    return (await res.json().catch(() => ({}))) as T;
  }

  private buildFilter(q: IndexQuery): string[] {
    const f: string[] = [];
    if (q.cuisine) f.push(`cuisines = ${JSON.stringify(q.cuisine)}`);
    if (q.neighborhood) f.push(`neighborhood = ${JSON.stringify(q.neighborhood)}`);
    if (q.priceBand !== undefined) f.push(`priceBand = ${q.priceBand}`);
    if (q.ratingMin !== undefined) f.push(`rating >= ${q.ratingMin}`);
    for (const a of q.amenities ?? []) f.push(`amenities = ${JSON.stringify(a)}`);
    if (q.lat !== undefined && q.lng !== undefined && q.radiusKm !== undefined) {
      f.push(`_geoRadius(${q.lat}, ${q.lng}, ${Math.round(q.radiusKm * 1000)})`);
    }
    return f;
  }

  private buildSort(q: IndexQuery): string[] | undefined {
    if (q.sort === 'rating') return ['rating:desc', 'ratingCount:desc'];
    if (q.sort === 'distance' && q.lat !== undefined && q.lng !== undefined) {
      return [`_geoPoint(${q.lat}, ${q.lng}):asc`];
    }
    return undefined; // Meili's own relevance ranking
  }
}
