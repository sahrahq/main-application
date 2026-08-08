import { Module } from '@nestjs/common';
import { FavoritesService } from './favorites.service';
import { WaitlistService } from './waitlist.service';
import { FavoritesController, WaitlistController } from './favorites.controller';
import { ImagesModule } from '../images/images.module';

/**
 * Saved places (C-2.7) and the waitlist (C-3.6) in one module.
 *
 * Two features, one module, because they are the same thing from the diner's
 * side: "I want this venue, just not right now." They share nothing in code —
 * separate services, separate controllers, separate tables — so if either
 * grows a console or a sweeper it moves out without untangling the other.
 */
@Module({
  imports: [ImagesModule],
  providers: [FavoritesService, WaitlistService],
  controllers: [FavoritesController, WaitlistController],
  exports: [FavoritesService],
})
export class FavoritesModule {}
