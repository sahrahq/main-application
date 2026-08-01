import { Module, MiddlewareConsumer, NestModule, ValidationPipe } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { AllExceptionsFilter } from './all-exceptions.filter';
import { RequestIdMiddleware } from './request-id.middleware';
import { validationExceptionFactory } from './validation.factory';

/**
 * The error contract (doc 06 §1), wired once.
 *
 * Both the filter and the ValidationPipe are registered as providers rather
 * than in `main.ts`. That is deliberate: `app.useGlobalFilters()` in the
 * bootstrap only applies to the app bootstrap builds, so an e2e test booting
 * `AppModule` would exercise a DIFFERENTLY CONFIGURED application than
 * production — the one place you least want a difference is the code that
 * decides what a failure looks like. As providers, tests and production get
 * the same pipeline.
 *
 * The pipe lives here, next to the filter, because the SHAPE of a validation
 * failure is part of the error contract: `details[]` is what lets a client
 * highlight the field that was rejected.
 */
@Module({
  providers: [
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    {
      provide: APP_PIPE,
      useFactory: () =>
        new ValidationPipe({
          // DEVELOPMENT.md §7 / doc 06 §1 — reject unknown fields outright
          // rather than ignoring them, so a client that misspells a field
          // hears about it instead of silently not sending it.
          whitelist: true,
          forbidNonWhitelisted: true,
          transform: true,
          transformOptions: { enableImplicitConversion: true },
          exceptionFactory: validationExceptionFactory,
        }),
    },
  ],
})
export class ErrorsModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
