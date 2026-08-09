import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ReportReason } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';

/**
 * C-4.4's report flow. **RECORDING WITH NO READER, DELIBERATELY.**
 *
 * ─────────────────────────────────────────────────────────────────────────
 * READ THIS BEFORE CONCLUDING IT IS HALF-FINISHED
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Nothing in this file, and nothing anywhere in the API, READS a report. There
 * is no queue, no triage, no notification, no automatic action. A-3 (admin
 * content moderation, P1) is where the reader arrives, and it is not built.
 *
 * That is a decision, accepted on exactly these terms:
 *
 *   > `review_reports` without a queue is accepted on the same terms as the
 *   > waitlist's join-without-notify: recording with no reader, deliberately,
 *   > with the reader arriving in A-3.
 *
 * `WaitlistService` carries the equivalent sentence — "nothing here offers
 * anybody a table" — and it is the reason nobody has since mistaken that
 * missing half for a bug. Same treatment here.
 *
 * **Why record before there is a reader.** Reviews are `published` by default,
 * because a moderation queue with no moderator does not moderate reviews — it
 * silently never publishes any. Published-by-default with no way to flag
 * anything is the combination that actually hurts. A report recorded today is
 * a report the moderator reads on their first day; a report that was never
 * offered is a diner who gave up on us.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * A REPORT DOES NOT CHANGE THE REVIEW
 * ─────────────────────────────────────────────────────────────────────────
 *
 * This corrects the Group D schema doc, which said `pending_moderation` was
 * "a state a REPORT moves a review into". Building it showed that is wrong.
 *
 * The venue page reads `status = 'published'` and the rating trigger averages
 * the same set. A report that moved a review to `pending_moderation` would
 * therefore remove it from the venue's page AND from its rating — so **one
 * account could silence any review**, with no moderator to release it. That is
 * precisely the brigading `idx_review_reports_unique` exists to prevent,
 * achieved through the front door instead.
 *
 * So a report is a row and nothing else. `review-reports.e2e-spec.ts` asserts
 * the negative directly: after a report, the review's status, its presence on
 * the venue page, and the venue's rating are all unchanged.
 */
@Injectable()
export class ReviewReportsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * File a report. Returns whether this call is what created it.
   *
   * **201 the first time, 200 afterwards, and both are success** — the same
   * shape as `POST /saved`, for a related but not identical reason. Saving is
   * a toggle; reporting is one-way. What they share is that a second press
   * means the same thing as the first, so turning the unique-index collision
   * into an error would be punishing a diner for caring twice, over a
   * connection that may simply have lost the first response.
   *
   * No `Idempotency-Key`: the unique index makes a replay structurally unable
   * to create a second row, which is what a key would have been protecting
   * against.
   */
  async report(input: {
    reviewId: string;
    reporterUserId: string;
    reason: ReportReason;
    note?: string;
  }): Promise<{ created: boolean }> {
    // PUBLISHED ONLY, and the 404 is deliberate for the other statuses too.
    // A review already removed or awaiting moderation is not something a diner
    // can see, so a report against one either comes from a stale screen or
    // from somebody probing ids — and neither should be told which.
    const review = await this.prisma.review.findFirst({
      where: { id: input.reviewId, status: 'published' },
      select: { id: true, userId: true },
    });

    if (!review) {
      throw new NotFoundException({
        code: 'review_not_found',
        message: 'We could not find that review.',
        message_ar: 'مش لاقيين التقييم ده.',
      });
    }

    // YOUR OWN REVIEW IS NOT REPORTABLE.
    //
    // Not because it would break anything — it would sit in the queue like any
    // other — but because it means the diner is looking for something else.
    // Somebody trying to retract what they wrote needs a delete, which does not
    // exist yet; letting them file a report instead would take the action they
    // meant and turn it into one that does nothing they wanted.
    if (review.userId === input.reporterUserId) {
      throw new BadRequestException({
        code: 'cannot_report_own_review',
        message: 'This is your own review.',
        message_ar: 'ده تقييمك إنت.',
      });
    }

    try {
      await this.prisma.reviewReport.create({
        data: {
          reviewId: review.id,
          reporterUserId: input.reporterUserId,
          reason: input.reason,
          // An empty or whitespace-only note is the absent note it actually
          // is; the CHECK constraint refuses a present-but-blank one.
          note: input.note?.trim() ? input.note.trim() : null,
        },
      });
      return { created: true };
    } catch (e) {
      // CAUGHT AT THE DATABASE, not checked before. A "have they reported this
      // already" read followed by an insert has a window between the two
      // statements, and a double tap on a slow connection lands in it.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return { created: false };
      }
      throw e;
    }
  }
}
