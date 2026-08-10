import { Controller, Get, Param } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { PublicRestaurantsService } from './public-restaurants.service';
import { RestaurantProfileResponse } from '../../shared/api/responses.dto';

/**
 * doc 06 §3 — public. Guest browsing all the way to the booking button is
 * C-1.6; only the reservation itself needs an account.
 *
 * ROUTE ORDER MATTERS HERE. `:idOrSlug` is a wildcard on the same base path as
 * `GET /restaurants/search` and `GET /restaurants/:id/availability`. Nest
 * resolves by registration order, so this module is imported LAST in
 * AppModule — after SearchModule and AvailabilityModule. That ordering is a
 * property of an import list two files away, which is exactly the kind of
 * thing that gets reordered by accident, so
 * `public-restaurant.e2e-spec.ts` asserts search still resolves. A shadowed
 * search route is a 404 on the app's busiest screen and nothing else in the
 * suite would notice.
 */
@ApiTags('restaurants')
@Controller('restaurants')
export class PublicRestaurantsController {
  constructor(private readonly restaurants: PublicRestaurantsService) {}

  @Get(':idOrSlug')
  @ApiOkResponse({ type: RestaurantProfileResponse })
  @ApiOperation({ summary: 'Public restaurant profile, by id or slug' })
  @ApiResponse({ status: 404, description: 'restaurant_not_found — also returned for a venue that is not active' })
  profile(@Param('idOrSlug') idOrSlug: string): Promise<RestaurantProfileResponse> {
    return this.restaurants.profile(idOrSlug) as Promise<RestaurantProfileResponse>;
  }
}
