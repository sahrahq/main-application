import { Module } from "@nestjs/common";
import { RestaurantsService } from "./restaurants.service";
import { OwnerReservationsService } from "./owner-reservations.service";
import { TablesService } from "./tables.service";
import { ShiftsService } from "./shifts.service";
import { WalkInsService } from "./walk-ins.service";
import { ReservationsModule } from "../reservations/reservations.module";
import { FavoritesModule } from "../favorites/favorites.module";
import { OwnerRestaurantsController } from "./owner-restaurants.controller";
import { OwnerVenueConfigController } from "./owner-venue-config.controller";
import { OwnerReservationActionsController } from "./owner-reservation-actions.controller";
import { OwnerCancellationService } from "./owner-cancellation.service";

@Module({
  // Walk-ins go through the SAME engine path as app bookings (doc 05 §7),
  // so this module consumes ReservationsService rather than reimplementing it.
  //
  // `FavoritesModule` for `WaitlistOfferService`: a venue cancelling a booking
  // is the third path that frees a table, and C-3.6 says somebody may be
  // waiting for it.
  imports: [ReservationsModule, FavoritesModule],
  providers: [OwnerCancellationService, RestaurantsService, OwnerReservationsService, TablesService, ShiftsService, WalkInsService],
  controllers: [OwnerRestaurantsController, OwnerVenueConfigController, OwnerReservationActionsController],
  exports: [OwnerCancellationService, RestaurantsService, OwnerReservationsService, TablesService, ShiftsService, WalkInsService],
})
export class RestaurantsModule {}
