import { Module } from '@nestjs/common';
import { LiveRestaurantResolver } from './live-restaurant';

/**
 * NO CONTROLLERS, on purpose.
 *
 * `app.module.ts` orders `PublicRestaurantsModule` last so its
 * `GET /restaurants/:idOrSlug` wildcard cannot shadow the routes above it.
 * Menus and reviews need the same "is this venue live" lookup, and importing
 * `PublicRestaurantsModule` to get it would register that wildcard early and
 * quietly undo the ordering.
 *
 * A provider-only module has no routes to register, so it can be imported from
 * anywhere without moving anything.
 */
@Module({
  providers: [LiveRestaurantResolver],
  exports: [LiveRestaurantResolver],
})
export class LiveRestaurantModule {}
