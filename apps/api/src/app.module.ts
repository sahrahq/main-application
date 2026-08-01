import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { ScheduleModule } from "@nestjs/schedule";
import { BullModule } from "@nestjs/bullmq";
import { PrismaModule } from "./shared/prisma/prisma.module";
import { ErrorsModule } from "./shared/errors/errors.module";
import { AuditModule } from "./shared/audit/audit.module";
import { ReservationsModule } from "./modules/reservations/reservations.module";
import { AuthModule } from "./modules/auth/auth.module";
import { RestaurantsModule } from "./modules/restaurants/restaurants.module";
import { AvailabilityModule } from "./modules/availability/availability.module";
import { AdminModule } from "./modules/admin/admin.module";
import { SearchModule } from "./modules/search/search.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: [".env"] }),
    // Drives the 60s hold-expiry sweeper (doc 05 §4 backstop).
    ScheduleModule.forRoot(),
    // BullMQ root connection, only when Redis is configured. Absent Redis, the
    // sweeper still runs — expiry degrades in precision, never in correctness.
    ...(process.env.REDIS_URL
      ? [
          BullModule.forRoot({
            connection: {
              url: process.env.REDIS_URL,
              maxRetriesPerRequest: null, // required by BullMQ workers
            },
          }),
        ]
      : []),
    // First, so the error envelope and request id apply to everything below.
    ErrorsModule,
    PrismaModule,
    AuditModule,
    AuthModule,
    RestaurantsModule,
    AvailabilityModule,
    SearchModule,
    AdminModule,
    ReservationsModule,
  ],
})
export class AppModule {}