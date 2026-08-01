import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';
import {
  ErrorDetail,
  ErrorEnvelope,
  INTERNAL,
  fallbackFor,
} from './error-codes';
import { RequestWithId, ensureRequestId, REQUEST_ID_HEADER } from './request-id.middleware';

/**
 * The single place an error becomes a response body (doc 06 §1).
 *
 * `@Catch()` with no argument means EVERYTHING — including the failures we did
 * not anticipate, which are exactly the ones that leak. No controller shapes
 * its own errors; if this filter is bypassed, the shape is wrong, so there is
 * one thing to get right instead of one per endpoint.
 *
 * The status code is never changed here. What a caller got before this filter
 * existed, they still get; only the body is reshaped.
 *
 * THE RULE ABOUT LEAKS: an `HttpException` was thrown deliberately by our code
 * and its message was written to be read by a diner, so it passes through. A
 * raw `Error` was not — it may carry a stack, a file path, a connection
 * string, a SQL fragment or a Prisma error body — so nothing from it reaches
 * the client. That detail is genuinely useful, so it goes to the log under the
 * same request_id the client is holding.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Errors');

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<RequestWithId>();

    // Middleware normally set this. Recomputed rather than assumed, because an
    // error thrown before the middleware chain completes must still produce a
    // correlatable envelope.
    const requestId = ensureRequestId(req);
    if (!res.headersSent) res.setHeader(REQUEST_ID_HEADER, requestId);

    const { status, body, logAs } = this.render(exception, requestId);

    const where = `${req.method ?? '?'} ${req.originalUrl ?? req.url ?? '?'}`;
    if (logAs === 'error') {
      // Everything the client did not get.
      this.logger.error(
        `[${requestId}] ${where} → ${status} ${body.error.code}`,
        stackOf(exception),
      );
    } else {
      this.logger.debug?.(`[${requestId}] ${where} → ${status} ${body.error.code}`);
    }

    if (body.error.retry_after !== undefined && !res.headersSent) {
      // doc 06 §1 lists Retry-After for 429; doc 05 §3 for the 503 under lock
      // contention. A client obeying standard HTTP semantics should not have
      // to parse our body to learn how long to wait.
      res.setHeader('Retry-After', String(body.error.retry_after));
    }

    if (res.headersSent) return; // a streamed response already committed
    res.status(status).json(body);
  }

  private render(
    exception: unknown,
    requestId: string,
  ): { status: number; body: ErrorEnvelope; logAs: 'error' | 'debug' } {
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const fb = fallbackFor(status);
      const payload = exception.getResponse();

      let code = fb.code;
      let message = fb.en;
      let messageAr = fb.ar;
      let details: ErrorDetail[] | undefined;
      let retryAfter: number | undefined;

      if (typeof payload === 'string') {
        // Nest's own shorthand, e.g. "Cannot GET /x". Safe to show, but it has
        // no code of its own, so the status supplies one.
        message = payload;
      } else if (payload && typeof payload === 'object') {
        const p = payload as Record<string, unknown>;
        if (typeof p.code === 'string' && p.code) code = p.code;
        // An array `message` is the stock ValidationPipe shape. We install our
        // own factory, so reaching here means some other pipe produced it —
        // keep the generic text rather than concatenating raw constraint
        // strings into a user-facing message.
        if (typeof p.message === 'string' && p.message) message = p.message;
        if (typeof p.message_ar === 'string' && p.message_ar) messageAr = p.message_ar;
        if (Array.isArray(p.details)) details = p.details as ErrorDetail[];
        if (typeof p.retry_after === 'number') retryAfter = p.retry_after;
      }

      return {
        status,
        body: envelope({ code, message, messageAr, details, retryAfter, requestId }),
        // 5xx is ours to explain even when deliberate; 4xx is the caller's.
        logAs: status >= HttpStatus.INTERNAL_SERVER_ERROR ? 'error' : 'debug',
      };
    }

    // Not an HttpException: nothing about it is fit to send.
    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      body: envelope({
        code: INTERNAL.code,
        message: INTERNAL.en,
        messageAr: INTERNAL.ar,
        requestId,
      }),
      logAs: 'error',
    };
  }
}

function envelope(input: {
  code: string;
  message: string;
  messageAr: string;
  details?: ErrorDetail[];
  retryAfter?: number;
  requestId: string;
}): ErrorEnvelope {
  return {
    error: {
      code: input.code,
      message: input.message,
      message_ar: input.messageAr,
      ...(input.details?.length ? { details: input.details } : {}),
      ...(input.retryAfter !== undefined ? { retry_after: input.retryAfter } : {}),
      request_id: input.requestId,
    },
  };
}

/** Whatever detail exists, for the LOG only. */
function stackOf(exception: unknown): string {
  if (exception instanceof Error) return exception.stack ?? `${exception.name}: ${exception.message}`;
  try {
    return typeof exception === 'string' ? exception : JSON.stringify(exception);
  } catch {
    return String(exception);
  }
}
