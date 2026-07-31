import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { PrismaModule } from "./shared/prisma/prisma.module";
import { ReservationsModule } from "./modules/reservations/reservations.module";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: [".env"] }),
    PrismaModule,
    ReservationsModule,
  ],
})
export class AppModule {}