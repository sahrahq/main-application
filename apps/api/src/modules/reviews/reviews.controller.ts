import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiQuery,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { ReviewsService } from './reviews.service';
import { ReviewReportsService } from './review-reports.service';
import { CreateReviewDto, ReportReviewDto } from './dto/reviews.dto';
import { ReviewPageResponse, ReviewResponse } from '../../shared/api/responses.dto';

/**
 * doc 06 §3 — `GET /restaurants/:id/reviews`, "Paginated, published only".
 *
 * PUBLIC, like the menu and for the same reason: reviews are most of what a
 * diner is deciding on, and C-1.6 says browsing needs no account.
 */
@ApiTags('reviews')
@Controller('restaurants')
export class RestaurantReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @Get(':idOrSlug/reviews')
  @ApiOkResponse({ type: ReviewPageResponse })
  @ApiOperation({ summary: "A venue's published reviews, newest first" })
  @ApiQuery({ name: 'cursor', required: false, description: 'ISO instant from `next_cursor`.' })
  @ApiQuery({ name: 'limit', required: false, type: 'integer' })
  @ApiResponse({ status: 404, description: 'restaurant_not_found' })
  listReviews(
    @Param('idOrSlug') idOrSlug: string,
    @Query('cursor') cursor?: string,
    // 20 is what fits a sheet twice over; 50 is the ceiling so a caller cannot
    // ask for the whole table and call it pagination.
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit = 20,
  ): Promise<ReviewPageResponse> {
    return this.reviews.forRestaurant(idOrSlug, {
      cursor,
      limit: Math.min(Math.max(limit, 1), 50),
    }) as Promise<ReviewPageResponse>;
  }
}

/**
 * doc 06 §"Reviews, payments, profile" — `POST /reviews`.
 *
 * NO `Idempotency-Key`, and the reasoning is structural rather than a
 * judgement call: `reviews.reservation_id` is UNIQUE, so a replay cannot
 * create a second review. The database refuses it and the caller gets the 409
 * the contract already specifies. A key would be a second mechanism for a
 * guarantee that already exists — and a second mechanism that can disagree
 * with the first is worse than one.
 *
 * Pinned by `idempotency-contract.spec.ts`, which counts rather than trusts.
 */
@ApiTags('reviews')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('reviews')
export class ReviewsController {
  constructor(
    private readonly reviews: ReviewsService,
    private readonly reports: ReviewReportsService,
  ) {}

  @Post()
  @ApiOkResponse({ type: ReviewResponse })
  @ApiOperation({ summary: 'Review a visit that happened' })
  @ApiResponse({ status: 201, description: 'Posted, and live immediately' })
  @ApiResponse({
    status: 400,
    description: 'validation_failed — including `photo_ids`, which is not accepted; see the DTO',
  })
  @ApiResponse({
    status: 403,
    description:
      'review_not_eligible (the visit did not happen) or review_too_early (the table time is not over)',
  })
  @ApiResponse({
    status: 404,
    description: "reservation_not_found — ALSO for another diner's reservation, deliberately",
  })
  @ApiResponse({ status: 409, description: 'review_already_exists — one review per visit' })
  // `createReview`, not `create`. There is already a `create` on another
  // controller, and the generator de-duplicates by appending a digit — so this
  // would have shipped as `create2()` in the Dart client, a name that changes
  // meaning the next time a controller is registered in a different order.
  // Caught by `client_drift_test.dart`, which bans a trailing digit for exactly
  // this reason. Second time that guard has paid for itself.
  createReview(
    @CurrentUser() user: AuthedUser,
    @Body() dto: CreateReviewDto,
  ): Promise<ReviewResponse> {
    return this.reviews.create({
      userId: user.id,
      reservationId: dto.reservationId,
      rating: dto.rating,
      foodRating: dto.foodRating,
      serviceRating: dto.serviceRating,
      ambienceRating: dto.ambienceRating,
      body: dto.body,
    }) as Promise<ReviewResponse>;
  }

  /**
   * Report a review. C-4.4's report flow.
   *
   * **NOTHING READS THIS.** The queue is A-3 and is not built; a report is
   * recorded and looked at by nobody until then. That is the agreed shape, not
   * an unfinished edge — see `ReviewReportsService` for why recording without a
   * reader is better than offering no way to flag a published review.
   *
   * **And it does not change the review.** A report that moved a review to
   * `pending_moderation` would take it off the venue page and out of the
   * rating, which would let one account silence any review with no moderator
   * to release it.
   *
   * 201 the first time, 200 on a repeat — a second press means the same thing
   * as the first. No `Idempotency-Key`: the unique index on
   * (review, reporter) makes a replay structurally unable to create a second
   * row.
   */
  @Post(':id/report')
  @ApiOperation({ summary: 'Report a review (recorded; the queue is A-3)' })
  @ApiResponse({ status: 201, description: 'Reported' })
  @ApiOkResponse({ description: 'Already reported by this diner' })
  @ApiResponse({ status: 400, description: 'cannot_report_own_review' })
  @ApiResponse({
    status: 404,
    description:
      'review_not_found — ALSO for a review that is not published, deliberately',
  })
  async reportReview(
    @CurrentUser() user: AuthedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReportReviewDto,
    @Res({ passthrough: true }) res: Response,
  ): Promise<void> {
    const { created } = await this.reports.report({
      reviewId: id,
      reporterUserId: user.id,
      reason: dto.reason,
      note: dto.note,
    });
    res.status(created ? 201 : 200);
  }
}
