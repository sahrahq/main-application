import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

/**
 * No providers. `PUSH_READINESS` comes from `NotificationsModule`, which is
 * `@Global()` — the same reason every module can emit a notification without
 * importing anything.
 */
@Module({ controllers: [HealthController] })
export class HealthModule {}
