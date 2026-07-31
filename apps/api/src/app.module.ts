import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { PrismaModule } from "./shared/prisma/prisma.module";
import { ReservationsModule } from "./modules/reservations/reservations.module";
import { AuthModule } from "./modules/auth/auth.module";
import { RestaurantsModule } from "./modules/restaurants/restaurants.module";
import { AvailabilityModule } from "./modules/availability/availability.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: [".env"] }),
    PrismaModule,
    AuthModule,
    RestaurantsModule,
    AvailabilityModule,
    ReservationsModule,
  ],
})
export class AppModule {}