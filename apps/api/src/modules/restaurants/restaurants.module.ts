import { Module } from "@nestjs/common";
import { RestaurantsService } from "./restaurants.service";
import { OwnerReservationsService } from "./owner-reservations.service";
import { OwnerRestaurantsController } from "./owner-restaurants.controller";

@Module({
  providers: [RestaurantsService, OwnerReservationsService],
  controllers: [OwnerRestaurantsController],
  exports: [RestaurantsService, OwnerReservationsService],
})
export class RestaurantsModule {}