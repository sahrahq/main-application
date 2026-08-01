import { BadRequestException } from '@nestjs/common';
import { ValidationError } from 'class-validator';
import { ErrorDetail } from './error-codes';

/**
 * class-validator's constraint names are implementation detail. These are the
 * stable slugs a client can switch on to render its own localised text — the
 * whole point of `details` is that the CLIENT decides what to say next to the
 * offending field, in whichever language it is running.
 */
const ISSUE: Record<string, string> = {
  isNotEmpty: 'required',
  isDefined: 'required',
  isString: 'type',
  isInt: 'type',
  isNumber: 'type',
  isBoolean: 'type',
  isArray: 'type',
  isDateString: 'format',
  isEmail: 'format',
  isUuid: 'format',
  matches: 'format',
  isIn: 'not_allowed',
  isEnum: 'not_allowed',
  min: 'too_small',
  max: 'too_large',
  minLength: 'too_short',
  maxLength: 'too_long',
  // Emitted by forbidNonWhitelisted for a property the DTO never declared.
  whitelistValidation: 'unknown_field',
};

/**
 * Turn class-validator output into the envelope's `details`.
 *
 * Field paths are dotted so a nested DTO still points at something the client
 * can highlight (`address.city`, not `city`). Nothing here echoes the VALUE
 * that failed — a rejected password would otherwise end up in the response
 * body and, worse, in whatever logs that body.
 */
export function validationExceptionFactory(errors: ValidationError[]): BadRequestException {
  const details = flatten(errors);
  return new BadRequestException({
    code: 'validation_failed',
    message: 'Some of the values sent are not valid.',
    message_ar: 'فيه قيم غير صحيحة في الطلب.',
    details,
  });
}

function flatten(errors: ValidationError[], prefix = ''): ErrorDetail[] {
  const out: ErrorDetail[] = [];

  for (const err of errors) {
    const field = prefix ? `${prefix}.${err.property}` : err.property;

    for (const constraint of Object.keys(err.constraints ?? {})) {
      out.push({ field, issue: ISSUE[constraint] ?? toSnake(constraint) });
    }
    if (err.children?.length) out.push(...flatten(err.children, field));
  }

  // One entry per (field, issue): a field failing the same rule twice tells
  // the client nothing extra.
  const seen = new Set<string>();
  return out.filter((d) => {
    const key = `${d.field}:${d.issue}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function toSnake(s: string): string {
  return s.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
}
