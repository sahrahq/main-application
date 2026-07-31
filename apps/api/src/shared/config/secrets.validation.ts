import { Logger } from '@nestjs/common';

/**
 * Boot-time gate on the JWT signing secret (doc 09 §1.1).
 *
 * A policy that lives only in a document is not a control. This makes the
 * requirement executable: in production the process refuses to start rather
 * than run with a weak or file-resident key, because an API that boots is an
 * API someone will assume is safe.
 *
 * HS256 is a symmetric MAC — the secret IS the ability to mint valid access
 * tokens for any user, including admins. A short one is brute-forceable
 * offline from a single captured token.
 */

/** doc 09 §1.1 — at least 256 bits. */
export const MIN_SECRET_BITS = 256;
const MIN_HEX_CHARS = MIN_SECRET_BITS / 4; // 64 hex chars
const MIN_RAW_BYTES = MIN_SECRET_BITS / 8; // 32 bytes of any encoding

/** Values that must never reach production, whatever their length. */
const KNOWN_PLACEHOLDERS = [
  'test-secret-not-for-production',
  'changeme',
  'change-me',
  'secret',
  'dev',
  'development',
];

export interface SecretCheck {
  name: string;
  ok: boolean;
  bits: number;
  reason?: string;
}

/** Entropy floor. Hex is counted at 4 bits/char, anything else at 8 bits/byte. */
export function secretStrength(value: string): number {
  if (/^[0-9a-fA-F]+$/.test(value)) return value.length * 4;
  return Buffer.byteLength(value, 'utf8') * 8;
}

export function checkSecret(name: string, value: string | undefined): SecretCheck {
  if (!value) return { name, ok: false, bits: 0, reason: 'not set' };

  if (KNOWN_PLACEHOLDERS.includes(value.toLowerCase())) {
    return { name, ok: false, bits: 0, reason: 'is a known placeholder value' };
  }

  const bits = secretStrength(value);
  if (bits < MIN_SECRET_BITS) {
    const need = /^[0-9a-fA-F]+$/.test(value)
      ? `${MIN_HEX_CHARS} hex chars`
      : `${MIN_RAW_BYTES} bytes`;
    return { name, ok: false, bits, reason: `${bits} bits, need ≥ ${MIN_SECRET_BITS} (${need})` };
  }

  return { name, ok: true, bits };
}

/**
 * Called from bootstrap. Throws in production, warns loudly in development —
 * local work must not require a secrets manager, but must not quietly ship
 * the dev posture either.
 */
export function validateSecrets(
  env: NodeJS.ProcessEnv = process.env,
  /** Injectable so the production guard is testable without touching disk. */
  envFileExists: () => boolean = () => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { existsSync } = require('fs') as typeof import('fs');
    return existsSync('.env');
  },
): void {
  const logger = new Logger('SecretsValidation');
  const isProd = env.NODE_ENV === 'production';

  const results = [
    checkSecret('JWT_ACCESS_SECRET', env.JWT_ACCESS_SECRET),
    checkSecret('JWT_REFRESH_SECRET', env.JWT_REFRESH_SECRET),
  ];
  const failures = results.filter((r) => !r.ok);

  if (failures.length > 0) {
    const detail = failures.map((f) => `  - ${f.name}: ${f.reason}`).join('\n');
    const msg = `JWT secrets do not meet doc 09 §1.1 (≥ ${MIN_SECRET_BITS} bits):\n${detail}`;
    if (isProd) throw new Error(msg);
    logger.warn(`${msg}\n  Tolerated because NODE_ENV != production.`);
  }

  // In production the secret must come from the injected environment, not a
  // file on the image. A readable .env means the secret is in the artifact.
  if (isProd) {
    if (envFileExists()) {
      throw new Error(
        'A .env file is present in production. JWT secrets must be injected by ' +
          'the platform secrets manager (AWS Secrets Manager / SSM per doc 10), ' +
          'never baked into the image. Remove .env from the deployment artifact.',
      );
    }
  }

  if (failures.length === 0) {
    logger.log(
      `JWT secrets OK (${results.map((r) => `${r.name}=${r.bits}b`).join(', ')})` +
        (isProd ? ' — sourced from injected environment' : ''),
    );
  }
}
