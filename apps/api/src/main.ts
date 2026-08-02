import { NestFactory } from "@nestjs/core";
import type { NestExpressApplication } from "@nestjs/platform-express";
import { Logger } from "@nestjs/common";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { AppModule } from "./app.module";
import { validateSecrets } from "./shared/config/secrets.validation";
import { corsOptionsFor } from "./shared/config/cors.options";
import { resolveTrustProxy } from "./shared/config/trust-proxy";

async function bootstrap(): Promise<void> {
  // Before anything can serve traffic: refuse to start on a weak or
  // file-resident signing secret in production (doc 09 §1.1).
  validateSecrets();

  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // How many proxies are in front of us, as a HOP COUNT — never `true`.
  //
  // `req.ip` feeds every per-IP rate limit and the refresh-token audit trail,
  // and it is derived from a header the client sends. Trusting the whole chain
  // makes those limits bypassable by typing a different X-Forwarded-For, which
  // is worse than the limits being too strict. Required in production; see
  // trust-proxy.ts for why it is not defaulted.
  const proxy = resolveTrustProxy();
  app.set('trust proxy', proxy.hops);
  new Logger('bootstrap').log(proxy.reason);

  // Browser origins (doc 07 §3 — the admin surface is Flutter Web, and the
  // customer app is developed in Chrome). The policy itself lives in
  // cors.options.ts and is unit-tested there; "allow anything in dev" is one
  // typo away from "allow anything".
  app.enableCors(corsOptionsFor(process.env.NODE_ENV, process.env.CORS_ORIGINS));

  // Validation and the error envelope are registered as providers in
  // ErrorsModule, not here — see the note in that file. Configuring them at
  // bootstrap would mean e2e tests booting AppModule exercised a different
  // pipeline than production, and the error contract is the last place that
  // difference should exist.

  app.setGlobalPrefix("v1", { exclude: ["health"] });

  // Contract-first: this spec is the source of truth for sahra_api_client.
  const config = new DocumentBuilder()
    .setTitle("SAHRA API")
    .setDescription("Restaurant reservation platform — Egypt/MENA")
    .setVersion("1.0")
    .addBearerAuth()
    .build();
  SwaggerModule.setup("api/docs", app, SwaggerModule.createDocument(app, config));

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  new Logger("bootstrap").log(`SAHRA API on :${port} — docs at /api/docs`);
}

void bootstrap();