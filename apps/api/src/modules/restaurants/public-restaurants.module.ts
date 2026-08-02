import { Module } from '@nestjs/common';
import { PublicRestaurantsService } from './public-restaurants.service';
import { PublicRestaurantsController } from './public-restaurants.controller';

/**
 * Its own module, separate from RestaurantsModule, for one reason: route
 * order. `GET /restaurants/:idOrSlug` is a wildcard that would shadow
 * `/restaurants/search` and `/restaurants/:id/availability` if it were
 * registered first, and RestaurantsModule is imported before both of theirs.
 *
 * Splitting it means AppModule can import this last without moving the owner
 * endpoints, and the ordering requirement lives next to the code that depends
 * on it rather than in a comment on an unrelated module.
 */
@Module({
  providers: [PublicRestaurantsService],
  controllers: [PublicRestaurantsController],
  exports: [PublicRestaurantsService],
})
export class PublicRestaurantsModule {}
