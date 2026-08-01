import { Module } from "@nestjs/common";
import { AdminRestaurantsService } from "./admin-restaurants.service";
import { AdminRestaurantsController } from "./admin-restaurants.controller";

@Module({
  providers: [AdminRestaurantsService],
  controllers: [AdminRestaurantsController],
  exports: [AdminRestaurantsService],
})
export class AdminModule {}