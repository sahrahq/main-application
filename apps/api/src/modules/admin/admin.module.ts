import { Module } from "@nestjs/common";
import { AdminRestaurantsService } from "./admin-restaurants.service";
import { AdminRestaurantsController } from "./admin-restaurants.controller";
import { SearchModule } from "../search/search.module";

@Module({
  // For the index port only — approving a venue is what makes it discoverable.
  imports: [SearchModule],
  providers: [AdminRestaurantsService],
  controllers: [AdminRestaurantsController],
  exports: [AdminRestaurantsService],
})
export class AdminModule {}