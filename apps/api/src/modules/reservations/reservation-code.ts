import { customAlphabet } from 'nanoid';

/**
 * Human-readable reservation code, e.g. 'SAH-7K2M' (doc 04 §2 `reservations`).
 *
 * Alphabet excludes 0/O/1/I/L to survive being read aloud over the phone to a
 * host — that is the actual use case, not URL safety. Column is VARCHAR(8),
 * so the format is exactly 'SAH-' + 4 chars.
 */
const ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const nano = customAlphabet(ALPHABET, 4);

export function generateReservationCode(): string {
  return `SAH-${nano()}`;
}
