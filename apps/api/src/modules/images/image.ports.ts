/**
 * The two things the image pipeline needs from the outside world, as ports.
 *
 * Same shape as the OTP and push ports: the service depends on an interface,
 * and the Supabase adapter is one implementation of it. That is not
 * architecture for its own sake — it is what lets the e2e suite exercise the
 * whole upload path, including resize, ordering and the cover rules, without a
 * network call or a bucket. A test that had to reach Supabase would either be
 * skipped in CI or make CI depend on somebody else's uptime.
 */

/** The renditions every image is stored in. */
export const IMAGE_SIZES = [160, 400, 1200] as const;
export type ImageSize = (typeof IMAGE_SIZES)[number];

/**
 * WHY THESE THREE, AND WHY THEY ARE FIXED.
 *
 *   160  — search rows and booking cards, where the image is a thumbnail
 *   400  — restaurant cards, and the venue hero on a phone
 *   1200 — the venue hero on a tablet, and anything full-bleed
 *
 * Resizing happens ONCE, at upload. Nothing on a request path transforms an
 * image, and no paid transformation feature is used: an image transformed per
 * view is an image paid for per view, and egress is the constraint that
 * actually binds on the free tier (doc 10 §3b).
 */
export const IMAGE_FORMAT = 'webp';

/** Where the renditions for one image live, derived from its base key. */
export function renditionKey(baseKey: string, size: ImageSize): string {
  return `${baseKey}/${size}.${IMAGE_FORMAT}`;
}

/**
 * The ORIGINAL, kept and never served.
 *
 * Worth the storage: a fourth size later, a re-crop, or a change of format is
 * a re-run over these rather than an email to fifty restaurants asking for
 * their photos again. The app must never request this path — it is a full-size
 * JPEG and would blow the egress budget on its own.
 */
export function originalKey(baseKey: string): string {
  return `${baseKey}/original`;
}

export interface StoredObject {
  key: string;
  bytes: number;
}

/** Somewhere to put bytes and get a public URL back. */
export interface ImageStorage {
  /**
   * Store [body] at [key]. Overwrites, so a re-run of the resizer is safe.
   *
   * [contentType] is passed explicitly rather than sniffed: a WebP served as
   * `application/octet-stream` is a download prompt, not an image.
   */
  put(key: string, body: Buffer, contentType: string): Promise<StoredObject>;

  /** Every object under [prefix] — used to delete an image's whole family. */
  remove(prefix: string): Promise<void>;

  /**
   * The address a client fetches [key] from.
   *
   * Composed by the ADAPTER, not by the client and not by the database. The
   * bucket, the CDN in front of it and the path convention are all deployment
   * concerns; a client that built URLs itself would have to be re-released the
   * day any of them changed.
   */
  publicUrl(key: string): string;
}

export const IMAGE_STORAGE = Symbol('IMAGE_STORAGE');

export interface ResizedImage {
  size: ImageSize;
  body: Buffer;
}

export interface ProcessedImage {
  /** The original's dimensions, for the aspect-ratio box every client reserves. */
  width: number;
  height: number;
  renditions: ResizedImage[];
  /** The original bytes, stored but never served. */
  original: Buffer;
}

/** Turn one uploaded file into the fixed set of renditions. */
export interface ImageProcessor {
  process(input: Buffer): Promise<ProcessedImage>;
}

export const IMAGE_PROCESSOR = Symbol('IMAGE_PROCESSOR');

/**
 * What the API will accept.
 *
 * 12 MB because a modern phone camera produces 4–8 MB and a restaurant sending
 * their best shot should not be refused for it. The limit exists so a
 * malformed or hostile upload cannot make `sharp` allocate without bound —
 * the resize happens in-process, so an unbounded input is an unbounded
 * allocation in the API.
 */
export const MAX_UPLOAD_BYTES = 12 * 1024 * 1024;

/**
 * Formats accepted from a caller.
 *
 * A DENY-BY-DEFAULT LIST. `sharp` will happily open SVG, PDF and TIFF, and SVG
 * in particular is a script-execution vector the moment anything renders it as
 * markup rather than as an image. Photographs are what this endpoint is for.
 */
export const ACCEPTED_MIME = ['image/jpeg', 'image/png', 'image/webp'] as const;
