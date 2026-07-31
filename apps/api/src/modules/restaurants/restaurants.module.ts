import { Module } from "@nestjs/common";
import { RestaurantsService } from "./restaurants.service";
import { OwnerRestaurantsController } from "./owner-restaurants.controller";

@Module({
  providers: [RestaurantsService],
  controllers: [OwnerRestaurantsController],
  exports: [RestaurantsService],
})
export class RestaurantsModule {}