import { Module } from '@nestjs/common';
import { RestaurantReviewsController, ReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';
import { LiveRestaurantModule } from '../restaurants/live-restaurant.module';

@Module({
  imports: [LiveRestaurantModule],
  controllers: [RestaurantReviewsController, ReviewsController],
  providers: [ReviewsService],
  exports: [ReviewsService],
})
export class ReviewsModule {}
