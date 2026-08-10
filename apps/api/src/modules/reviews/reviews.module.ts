import { Module } from '@nestjs/common';
import { RestaurantReviewsController, ReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';
import { ReviewReportsService } from './review-reports.service';
import { LiveRestaurantModule } from '../restaurants/live-restaurant.module';

@Module({
  imports: [LiveRestaurantModule],
  controllers: [RestaurantReviewsController, ReviewsController],
  providers: [ReviewsService, ReviewReportsService],
  exports: [ReviewsService],
})
export class ReviewsModule {}
