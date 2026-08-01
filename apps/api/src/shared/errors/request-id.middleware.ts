import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { nanoid } from 'nanoid';

export const REQUEST_ID_HEADER = 'X-Request-Id';

/** Where the filter and the logger both read it from. */
export interface RequestWithId extends Request {
  requestId?: string;
}

/**
 * One id per request, on the response header and inside every error envelope.
 *
 * It is the only handle a diner can give support — "it said req_a1b2c3" — and
 * the only way to find the stack trace that goes with the generic message they
 * were shown. An id that appears in the log but not in the response, or vice
 * versa, is useless for that.
 *
 * A client-supplied id is honoured so a mobile client can correlate its own
 * telemetry with ours, but it is SANITISED first: it is echoed straight back
 * into a response header, and an unfiltered value containing CR/LF would let a
 * caller inject headers into our response.
 */
@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  use(req: RequestWithId, res: Response, next: NextFunction): void {
    const id = ensureRequestId(req);
    res.setHeader(REQUEST_ID_HEADER, id);
    next();
  }
}

export function ensureRequestId(req: RequestWithId): string {
  if (req.requestId) return req.requestId;

  const supplied = req.headers?.['x-request-id'];
  const raw = Array.isArray(supplied) ? supplied[0] : supplied;
  const clean = typeof raw === 'string' ? raw.replace(/[^A-Za-z0-9_.:-]/g, '').slice(0, 128) : '';

  req.requestId = clean || `req_${nanoid(10)}`;
  return req.requestId;
}
