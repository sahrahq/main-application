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
import { PublicRestaurantsModule } from "./modules/restaurants/public-restaurants.module";
import { AvailabilityModule } from "./modules/availability/availability.module";
import { AdminModule } from "./modules/admin/admin.module";
import { SearchModule } from "./modules/search/search.module";
import { NotificationsModule } from "./modules/notifications/notifications.module";
import { ImagesModule } from './modules/images/images.module';
import { FavoritesModule } from './modules/favorites/favorites.module';

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
    // Global — the event that causes a notification lives in whichever
    // module it happens in, so this is imported once rather than everywhere.
    NotificationsModule,
    AuthModule,
    RestaurantsModule,
    AvailabilityModule,
    SearchModule,
    AdminModule,
    ImagesModule,
    FavoritesModule,
    ReservationsModule,
    // LAST, and it has to stay last: its `GET /restaurants/:idOrSlug` is a
    // wildcard that would shadow /restaurants/search and
    // /restaurants/:id/availability if registered before them. Guarded by
    // test/public-restaurant.e2e-spec.ts, not by this comment.
    PublicRestaurantsModule,
  ],
})
export class AppModule {}