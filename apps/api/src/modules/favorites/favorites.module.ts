import { Module } from '@nestjs/common';
import { FavoritesService } from './favorites.service';
import { WaitlistService } from './waitlist.service';
import { WaitlistOfferService } from './waitlist-offer.service';
import { WaitlistOfferScheduler } from './waitlist-offer.scheduler';
import { FavoritesController, WaitlistController } from './favorites.controller';
import { ImagesModule } from '../images/images.module';

/**
 * Saved places (C-2.7) and the waitlist (C-3.6) in one module.
 *
 * Two features, one module, because they are the same thing from the diner's
 * side: "I want this venue, just not right now." They share nothing in code —
 * separate services, separate controllers, separate tables — so if either
 * grows a console or a sweeper it moves out without untangling the other.
 *
 * The waitlist grew a sweeper in Group G and stayed, because the split above is
 * still clean: `WaitlistOfferService` and `WaitlistOfferScheduler` touch nothing
 * belonging to favourites.
 *
 * `WaitlistOfferService` is EXPORTED because its caller is not here. A table is
 * freed by a cancellation or a hold expiry, which live in `restaurants` and
 * `reservations` — the same reason `NotificationsModule` is global.
 */
@Module({
  imports: [ImagesModule],
  providers: [FavoritesService, WaitlistService, WaitlistOfferService, WaitlistOfferScheduler],
  controllers: [FavoritesController, WaitlistController],
  exports: [FavoritesService, WaitlistOfferService],
})
export class FavoritesModule {}
