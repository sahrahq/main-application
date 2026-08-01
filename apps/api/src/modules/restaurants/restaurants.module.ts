import { Module } from "@nestjs/common";
import { RestaurantsService } from "./restaurants.service";
import { OwnerReservationsService } from "./owner-reservations.service";
import { TablesService } from "./tables.service";
import { ShiftsService } from "./shifts.service";
import { OwnerRestaurantsController } from "./owner-restaurants.controller";
import { OwnerVenueConfigController } from "./owner-venue-config.controller";

@Module({
  providers: [RestaurantsService, OwnerReservationsService, TablesService, ShiftsService],
  controllers: [OwnerRestaurantsController, OwnerVenueConfigController],
  exports: [RestaurantsService, OwnerReservationsService, TablesService, ShiftsService],
})
export class RestaurantsModule {}
