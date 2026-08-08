import { BadRequestException, PayloadTooLargeException } from '@nestjs/common';
import type { Request } from 'express';
import { ACCEPTED_MIME, MAX_UPLOAD_BYTES } from './image.ports';

export interface UploadedFile {
  body: Buffer;
  mimeType: string;
  filename: string;
}

/**
 * Read ONE file out of a `multipart/form-data` request.
 *
 * ── WHY THIS IS NOT `multer` ─────────────────────────────────────────────
 *
 * `@nestjs/platform-express` ships `FileInterceptor`, which wants `multer` and
 * `@types/multer`. Neither is in the stack table (doc 08 §5), and CLAUDE.md
 * says stop and ask before adding one. `sharp` and `url_launcher` were worth
 * asking for; a multipart parser for a single admin endpoint that accepts one
 * field is not — this is sixty lines against a format that has not changed
 * since 1998.
 *
 * ── AND WHY IT IS STILL BOUNDED ──────────────────────────────────────────
 *
 * The size limit is enforced WHILE READING, not after. Buffering the whole
 * body and then checking its length is how a 2 GB upload takes the API down
 * with a perfectly correct 400 that arrives too late to matter. Chunks are
 * counted as they arrive and the stream is destroyed the moment the total goes
 * over.
 *
 * Scope, stated plainly: ONE file, in the first file part found, ignoring
 * every other field. That is exactly what the admin upload sends. It is not a
 * general multipart parser and must not grow into one — the day a second
 * endpoint needs fields alongside files is the day to ask for `multer`.
 */
export async function readUpload(req: Request): Promise<UploadedFile> {
  const contentType = req.headers['content-type'] ?? '';
  const boundaryMatch = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType);

  if (!contentType.toLowerCase().startsWith('multipart/form-data') || !boundaryMatch) {
    throw new BadRequestException({
      code: 'invalid_image',
      message: 'Send the image as multipart/form-data with a `file` part.',
      message_ar: 'ابعت الصورة بصيغة multipart/form-data في حقل اسمه file.',
    });
  }

  const boundary = boundaryMatch[1] ?? boundaryMatch[2];
  const raw = await collect(req);

  // Parts are separated by `--boundary`. Splitting on the Buffer rather than a
  // string, because image bytes are not valid UTF-8 and a round trip through a
  // string would corrupt them — the classic way a "working" upload produces a
  // file that will not open.
  const separator = Buffer.from(`--${boundary}`);
  const parts = splitBuffer(raw, separator);

  for (const part of parts) {
    // Headers end at the first blank line; everything after is the payload.
    const headerEnd = part.indexOf('\r\n\r\n');
    if (headerEnd === -1) continue;

    const headers = part.subarray(0, headerEnd).toString('utf8');
    if (!/filename=/i.test(headers)) continue;

    const filename = /filename="([^"]*)"/i.exec(headers)?.[1] ?? 'upload';
    const declared = /content-type:\s*([^\r\n;]+)/i.exec(headers)?.[1]?.trim().toLowerCase();

    // Trailing CRLF belongs to the boundary, not to the file.
    let body = part.subarray(headerEnd + 4);
    if (body.length >= 2 && body[body.length - 2] === 0x0d && body[body.length - 1] === 0x0a) {
      body = body.subarray(0, body.length - 2);
    }

    if (!declared || !(ACCEPTED_MIME as readonly string[]).includes(declared)) {
      throw new BadRequestException({
        code: 'unsupported_image_type',
        message: 'Upload a JPEG, PNG or WebP.',
        message_ar: 'ارفع صورة JPEG أو PNG أو WebP.',
        details: [{ field: 'file', issue: declared ?? 'missing' }],
      });
    }

    return { body, mimeType: declared, filename };
  }

  throw new BadRequestException({
    code: 'invalid_image',
    message: 'No file part found in that upload.',
    message_ar: 'مفيش ملف في الطلب ده.',
  });
}

/** Buffer the body, refusing to grow past the limit. */
function collect(req: Request): Promise<Buffer> {
  return new Promise<Buffer>((resolve, reject) => {
    const chunks: Buffer[] = [];
    let total = 0;

    req.on('data', (chunk: Buffer) => {
      total += chunk.length;
      if (total > MAX_UPLOAD_BYTES) {
        // Destroyed mid-stream. Reading to the end first would mean a hostile
        // upload gets to allocate everything it sent before being told no.
        req.destroy();
        reject(
          new PayloadTooLargeException({
            code: 'image_too_large',
            message: `Images must be under ${Math.round(MAX_UPLOAD_BYTES / 1024 / 1024)} MB.`,
            message_ar: `الصورة لازم تكون أقل من ${Math.round(MAX_UPLOAD_BYTES / 1024 / 1024)} ميجا.`,
          }),
        );
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

/** Split on a byte sequence, keeping the pieces between occurrences. */
function splitBuffer(source: Buffer, separator: Buffer): Buffer[] {
  const parts: Buffer[] = [];
  let start = 0;

  for (;;) {
    const at = source.indexOf(separator, start);
    if (at === -1) {
      parts.push(source.subarray(start));
      break;
    }
    if (at > start) parts.push(source.subarray(start, at));
    start = at + separator.length;
  }

  return parts;
}
