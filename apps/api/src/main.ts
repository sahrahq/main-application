import { NestFactory } from "@nestjs/core";
import { ValidationPipe, Logger } from "@nestjs/common";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { AppModule } from "./app.module";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);

  // DEVELOPMENT.md §7 — reject unknown fields outright rather than ignoring them.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

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