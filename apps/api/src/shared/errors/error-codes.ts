import { HttpStatus } from '@nestjs/common';

/**
 * doc 06 §1 — the error envelope.
 *
 *   { "error": { "code", "message", "message_ar", "details"?, "request_id" } }
 *
 * `code` is the only field a client should branch on. `message` and
 * `message_ar` both travel on every error and the CLIENT chooses which to
 * show — the app's locale lives in its own settings, and a server that picked
 * one would be guessing on behalf of a bilingual user who may well have the
 * phone in one language and prefer the other for restaurant names.
 */
export interface ErrorDetail {
  field: string;
  issue: string;
}

export interface ErrorEnvelope {
  error: {
    code: string;
    message: string;
    message_ar: string;
    details?: ErrorDetail[];
    /** Seconds. Mirrors the `Retry-After` header (doc 06 §1, doc 05 §3). */
    retry_after?: number;
    request_id: string;
  };
}

/**
 * Fallbacks for exceptions that carry no code of their own — thrown by Nest
 * itself (an unmatched route, ParseUUIDPipe, a guard) rather than by our
 * domain code. Without these a framework error would arrive with an empty
 * `code`, and a client cannot branch on an empty string.
 */
const BY_STATUS: Record<number, { code: string; en: string; ar: string }> = {
  [HttpStatus.BAD_REQUEST]: {
    code: 'bad_request',
    en: 'The request was not valid.',
    ar: 'الطلب غير صحيح.',
  },
  [HttpStatus.UNAUTHORIZED]: {
    code: 'unauthenticated',
    en: 'Please sign in and try again.',
    ar: 'برجاء تسجيل الدخول والمحاولة مرة أخرى.',
  },
  [HttpStatus.FORBIDDEN]: {
    code: 'forbidden',
    en: 'You do not have permission to do that.',
    ar: 'ليس لديك صلاحية للقيام بذلك.',
  },
  [HttpStatus.NOT_FOUND]: {
    code: 'not_found',
    en: 'Not found.',
    ar: 'غير موجود.',
  },
  [HttpStatus.CONFLICT]: {
    code: 'conflict',
    en: 'That conflicts with the current state.',
    ar: 'فيه تعارض مع الحالة الحالية.',
  },
  [HttpStatus.PAYLOAD_TOO_LARGE]: {
    code: 'payload_too_large',
    en: 'That upload is too large.',
    ar: 'حجم الملف كبير جدًا.',
  },
  [HttpStatus.UNPROCESSABLE_ENTITY]: {
    code: 'unprocessable',
    en: 'The request could not be processed.',
    ar: 'تعذّر تنفيذ الطلب.',
  },
  [HttpStatus.TOO_MANY_REQUESTS]: {
    code: 'rate_limited',
    en: 'Too many requests. Please try again shortly.',
    ar: 'طلبات كتير. حاول تاني بعد شوية.',
  },
  [HttpStatus.SERVICE_UNAVAILABLE]: {
    code: 'service_unavailable',
    en: 'The service is temporarily unavailable. Please try again.',
    ar: 'الخدمة غير متاحة مؤقتًا. برجاء المحاولة مرة أخرى.',
  },
};

/**
 * What an unhandled exception becomes. Deliberately says nothing: the client
 * learns that it failed and gets a request_id to quote, and everything else
 * goes to the server log.
 */
export const INTERNAL = {
  code: 'internal_error',
  en: 'Something went wrong on our side. Please try again.',
  ar: 'حصل خطأ عندنا. برجاء المحاولة مرة أخرى.',
};

export function fallbackFor(status: number): { code: string; en: string; ar: string } {
  return BY_STATUS[status] ?? INTERNAL;
}
