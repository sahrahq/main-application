/**
 * Export the OpenAPI document from the REAL application.
 *
 *   pnpm openapi:export          # write openapi.json
 *   pnpm openapi:export --check  # fail if it differs from what is committed
 *
 * This boots `AppModule` and asks Nest for the document its actual controllers
 * and DTOs describe. That is the whole point: a hand-maintained spec drifts
 * from the controllers within a week and then guarantee 1 is theatre — the
 * check would be comparing a file to itself.
 *
 * Because it boots the real app it needs the real services (Postgres, Redis,
 * Meilisearch). In CI they are already running for the e2e suite.
 *
 * The output is SORTED, so a diff shows what actually changed rather than
 * whatever order the decorator metadata happened to come back in.
 */
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { AppModule } from './app.module';

const OUTPUT = join(__dirname, '..', 'openapi.json');

/** Recursively sort object keys so the file is byte-stable across runs. */
function sortDeep(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortDeep);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value as Record<string, unknown>)
        .sort()
        .map((k) => [k, sortDeep((value as Record<string, unknown>)[k])]),
    );
  }
  return value;
}

async function main(): Promise<void> {
  const check = process.argv.includes('--check');

  // `logger: false` HERE MEANS A BOOT FAILURE IS SILENT.
  //
  // It was `false`, to keep the export's output clean. Then a module in Group D
  // failed to resolve a provider, and this script exited 1 with NOTHING on
  // either stream — because Nest logs a dependency-resolution failure through
  // its own ExceptionHandler and then exits, so the `main().catch` below never
  // runs and the suppressed logger swallows the only explanation.
  //
  // "Spec export failed" with no reason sends whoever hits it to guess. Errors
  // and warnings are on; `log` and `debug` stay off, which is what the quiet
  // was actually for.
  const app = await NestFactory.create(AppModule, { logger: ['error', 'warn'] });
  // Mirrors main.ts. The prefix is part of the contract — a client generated
  // without it would call the wrong paths.
  app.setGlobalPrefix('v1', { exclude: ['health'] });

  const config = new DocumentBuilder()
    .setTitle('SAHRA API')
    .setDescription('Restaurant reservation platform — Egypt/MENA')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  await app.close();

  const json = `${JSON.stringify(sortDeep(document), null, 2)}\n`;

  if (check) {
    if (!existsSync(OUTPUT)) {
      console.error(`openapi.json is missing. Run: pnpm openapi:export`);
      process.exit(1);
    }
    const committed = readFileSync(OUTPUT, 'utf8').replace(/\r\n/g, '\n');
    if (committed !== json) {
      console.error(
        'openapi.json is STALE — a controller or DTO changed without re-exporting.\n' +
          'Run: pnpm openapi:export\n\n' +
          diffSummary(committed, json),
      );
      process.exit(1);
    }
    console.log('openapi.json is current.');
    return;
  }

  writeFileSync(OUTPUT, json, 'utf8');
  const paths = Object.keys((document as { paths: object }).paths).length;
  console.log(`Wrote ${OUTPUT} — ${paths} paths.`);
}

/**
 * A readable diff, because "the spec is stale" without saying WHAT changed
 * sends the reader to regenerate blindly and hope.
 */
function diffSummary(before: string, after: string): string {
  const a = before.split('\n');
  const b = after.split('\n');
  const out: string[] = [];
  const max = Math.max(a.length, b.length);
  for (let i = 0, shown = 0; i < max && shown < 40; i++) {
    if (a[i] !== b[i]) {
      if (a[i] !== undefined) out.push(`  - ${a[i]}`);
      if (b[i] !== undefined) out.push(`  + ${b[i]}`);
      shown++;
    }
  }
  if (out.length === 0) return '  (differs only in trailing whitespace)';
  return `First differences:\n${out.join('\n')}`;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
