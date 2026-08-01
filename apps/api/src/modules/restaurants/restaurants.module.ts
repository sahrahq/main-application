import { Module } from "@nestjs/common";
import { RestaurantsService } from "./restaurants.service";
import { OwnerReservationsService } from "./owner-reservations.service";
import { TablesService } from "./tables.service";
import { ShiftsService } from "./shifts.service";
import { WalkInsService } from "./walk-ins.service";
import { ReservationsModule } from "../reservations/reservations.module";
import { OwnerRestaurantsController } from "./owner-restaurants.controller";
import { OwnerVenueConfigController } from "./owner-venue-config.controller";

@Module({
  // Walk-ins go through the SAME engine path as app bookings (doc 05 §7),
  // so this module consumes ReservationsService rather than reimplementing it.
  imports: [ReservationsModule],
  providers: [RestaurantsService, OwnerReservationsService, TablesService, ShiftsService, WalkInsService],
  controllers: [OwnerRestaurantsController, OwnerVenueConfigController],
  exports: [RestaurantsService, OwnerReservationsService, TablesService, ShiftsService, WalkInsService],
})
export class RestaurantsModule {}
