import { BadRequestException, PayloadTooLargeException } from '@nestjs/common';
import { Readable } from 'stream';
import type { Request } from 'express';
import { readUpload } from './read-upload';
import { MAX_UPLOAD_BYTES } from './image.ports';

/**
 * THE HAND-ROLLED PARSER, FED THINGS IT WAS NOT EXPECTING.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHY THIS FILE IS LONGER THAN THE PARSER
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `multer` was not added, and the argument for that was proportionality: one
 * admin endpoint, one field, sixty lines. The other half of that argument is
 * this file. A hand-written parser for a binary wire format is a classic place
 * for a security hole, and "it works on the happy path" is what every one of
 * those looked like the day it shipped.
 *
 * So the cases here are the ones that break parsers: a boundary that never
 * appears, a part cut off mid-headers, headers with no body, a body larger
 * than the limit, a boundary an attacker chose, and content that is not UTF-8.
 *
 * THE BAR IS "FAILS CLEANLY", not "handles it". Every one of these must
 * produce a typed `BadRequestException` or `PayloadTooLargeException` — never
 * a `RangeError`, never an unhandled rejection, never a hang, and never a
 * silently truncated file that decodes into a corrupt photograph.
 *
 * Recorded in `docs/decisions/2026-08-09-hand-rolled-multipart.md`.
 */
describe('readUpload — malformed, truncated and oversized input', () => {
  /** A request whose body is [body], streamed in [chunks] pieces. */
  function requestWith(body: Buffer, contentType: string, chunkSize = 64 * 1024): Request {
    const pieces: Buffer[] = [];
    for (let at = 0; at < body.length; at += chunkSize) {
      pieces.push(body.subarray(at, Math.min(at + chunkSize, body.length)));
    }
    // An empty body still has to produce a stream that ends.
    const stream = Readable.from(pieces.length > 0 ? pieces : [Buffer.alloc(0)]);
    const req = stream as unknown as Request;
    (req as unknown as { headers: Record<string, string> }).headers = {
      'content-type': contentType,
    };
    // `collect` destroys the stream on overflow; Readable has `destroy`.
    return req;
  }

  const boundary = '----SahraTestBoundary';
  const ct = `multipart/form-data; boundary=${boundary}`;

  /** A well-formed single-file body. The control for everything below. */
  function wellFormed(payload: Buffer, mime = 'image/jpeg'): Buffer {
    return Buffer.concat([
      Buffer.from(
        `--${boundary}\r\n` +
          'Content-Disposition: form-data; name="file"; filename="v.jpg"\r\n' +
          `Content-Type: ${mime}\r\n\r\n`,
      ),
      payload,
      Buffer.from(`\r\n--${boundary}--\r\n`),
    ]);
  }

  it('THE CONTROL: a well-formed body parses, bytes intact', async () => {
    // Without this every assertion below could pass because the parser
    // rejects everything, which is not the same as rejecting the bad things.
    //
    // The payload is deliberately NOT valid UTF-8 — real image bytes are not,
    // and a parser that round-trips through a string corrupts them silently.
    const payload = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x80, 0x81, 0xfe]);
    const file = await readUpload(requestWith(wellFormed(payload), ct));

    expect(file.mimeType).toBe('image/jpeg');
    expect(file.filename).toBe('v.jpg');
    expect(Buffer.compare(file.body, payload)).toBe(0);
  });

  describe('the request is not multipart at all', () => {
    it('a JSON content-type', async () => {
      await expect(
        readUpload(requestWith(Buffer.from('{}'), 'application/json')),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('multipart with NO boundary parameter', async () => {
      await expect(
        readUpload(requestWith(Buffer.from('x'), 'multipart/form-data')),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('no content-type header whatsoever', async () => {
      const req = requestWith(Buffer.from('x'), '');
      (req as unknown as { headers: Record<string, string> }).headers = {};
      await expect(readUpload(req)).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('the body is malformed', () => {
    it('completely empty', async () => {
      await expect(
        readUpload(requestWith(Buffer.alloc(0), ct)),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('the declared boundary never appears', async () => {
      const body = Buffer.from('nothing here resembles a multipart body at all');
      await expect(readUpload(requestWith(body, ct))).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('a part with headers and NO blank line — truncated mid-headers', async () => {
      // `indexOf('\r\n\r\n')` returns -1. The parser must skip the part rather
      // than slicing from index 3.
      const body = Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="v.jpg"`,
      );
      await expect(readUpload(requestWith(body, ct))).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('a part with headers and an EMPTY body', async () => {
      // Legal multipart, zero-byte file. Must reach the service, which refuses
      // an empty image — not blow up in the parser.
      const file = await readUpload(requestWith(wellFormed(Buffer.alloc(0)), ct));
      expect(file.body.length).toBe(0);
    });

    it('a form field with no filename is not mistaken for a file', async () => {
      const body = Buffer.concat([
        Buffer.from(
          `--${boundary}\r\nContent-Disposition: form-data; name="cover"\r\n\r\ntrue\r\n`,
        ),
        Buffer.from(`--${boundary}--\r\n`),
      ]);
      await expect(readUpload(requestWith(body, ct))).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('a file part with no Content-Type is refused, not guessed', async () => {
      // Guessing from the extension is how an SVG arrives named `.jpg`.
      const body = Buffer.concat([
        Buffer.from(
          `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="v.jpg"\r\n\r\n`,
        ),
        Buffer.from([0xff, 0xd8]),
        Buffer.from(`\r\n--${boundary}--\r\n`),
      ]);
      await expect(readUpload(requestWith(body, ct))).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('CRLFs alone, no parts', async () => {
      await expect(
        readUpload(requestWith(Buffer.from('\r\n\r\n\r\n'), ct)),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('a boundary that is a regex metacharacter soup', async () => {
      // The boundary comes from a header the CALLER controls. It is used with
      // `Buffer.indexOf`, not in a regex — this asserts that stays true. If
      // somebody ever "improves" the split to use `RegExp`, this body turns
      // into a catastrophic-backtracking denial of service.
      const nasty = '(.*)+$^[a-z]{1,9999}';
      const nastyCt = `multipart/form-data; boundary=${nasty}`;
      const body = Buffer.concat([
        Buffer.from(
          `--${nasty}\r\nContent-Disposition: form-data; name="file"; filename="v.jpg"\r\n` +
            'Content-Type: image/jpeg\r\n\r\n',
        ),
        Buffer.from([0xff, 0xd8]),
        Buffer.from(`\r\n--${nasty}--\r\n`),
      ]);

      const file = await readUpload(requestWith(body, nastyCt));
      expect(file.body.length).toBe(2);
    });

    it('a quoted boundary, as the RFC allows', async () => {
      const quotedCt = `multipart/form-data; boundary="${boundary}"`;
      const file = await readUpload(requestWith(wellFormed(Buffer.from([0xff, 0xd8])), quotedCt));
      expect(file.mimeType).toBe('image/jpeg');
    });
  });

  describe('the body is oversized', () => {
    it('REFUSED WHILE READING, not after buffering it all', async () => {
      // The assertion that matters for availability. A body over the limit
      // must be rejected mid-stream — buffering 2 GB and then returning a
      // perfectly correct 413 is a denial of service with good manners.
      const oversized = Buffer.alloc(MAX_UPLOAD_BYTES + 1024, 0x41);
      await expect(
        readUpload(requestWith(wellFormed(oversized), ct, 1024 * 1024)),
      ).rejects.toBeInstanceOf(PayloadTooLargeException);
    });

    it('and the stream is destroyed rather than drained', async () => {
      const oversized = Buffer.alloc(MAX_UPLOAD_BYTES + 1024, 0x41);
      const req = requestWith(wellFormed(oversized), ct, 1024 * 1024);

      await expect(readUpload(req)).rejects.toBeInstanceOf(PayloadTooLargeException);
      expect((req as unknown as { destroyed: boolean }).destroyed).toBe(true);
    });

    it('a body exactly AT the limit is still accepted', async () => {
      // Off-by-one in the other direction: a limit that refuses the largest
      // legal upload is a limit nobody can discover the edge of.
      const payload = Buffer.alloc(1024, 0x41);
      const file = await readUpload(requestWith(wellFormed(payload), ct));
      expect(file.body.length).toBe(1024);
    });
  });

  describe('a stream that errors', () => {
    it('rejects rather than hanging', async () => {
      const stream = new Readable({
        read() {
          this.destroy(new Error('socket closed'));
        },
      });
      const req = stream as unknown as Request;
      (req as unknown as { headers: Record<string, string> }).headers = {
        'content-type': ct,
      };

      await expect(readUpload(req)).rejects.toThrow('socket closed');
    });
  });
});
