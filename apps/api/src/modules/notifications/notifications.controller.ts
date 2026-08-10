import { Body, Controller, Get, HttpCode, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../shared/auth/jwt-auth.guard';
import { CurrentUser } from '../../shared/auth/current-user.decorator';
import type { AuthedUser } from '../../shared/auth/jwt.strategy';
import { NotificationsService } from './notifications.service';
import { MarkNotificationsReadDto } from './dto/notifications.dto';
import { MarkReadResponse, NotificationListResponse } from '../../shared/api/responses.dto';

/**
 * C-4.7 — the in-app notification centre. doc 06 §3:
 * `/notifications` GET, `POST /notifications/read`.
 *
 * ── THIS IS THE FIRST THING THAT READS `read_at` ─────────────────────────
 *
 * The column has existed since NOTIFY-1 stage 1 and nothing had ever selected
 * on it, which is why `idx_notif_user_unread` was deliberately not built until
 * now (`prisma/migrations/20260802020000_notifications_stage_1/README.md`).
 * Both routes below filter on it, and the index went in with them.
 *
 * ── AND IT IS THE ONLY WAY A DINER LEARNS ANYTHING ───────────────────────
 *
 * Push is not built — the Firebase project does not exist. So a notification
 * reaches a person if and only if they open the app and tap the bell. That is
 * the honest state, it is written down in
 * `docs/decisions/2026-08-09-group-g-split.md`, and it is why the centre was
 * worth building before the channel: the records are already correct and
 * complete on the day an adapter is bound.
 */
@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'The notification centre — newest first, with an unread count' })
  @ApiQuery({ name: 'limit', required: false, type: 'integer' })
  @ApiOkResponse({ type: NotificationListResponse })
  // `listNotifications`, not `list`. The generator derives the Dart method name
  // from this one and appends a digit on a collision — `list` already exists on
  // another controller, so it emitted `list2()`. The numeric-suffix ban from
  // Group B is what caught it, for the second time. A method called `list2` in
  // a generated client is a name nobody can look up and nobody can guess.
  async listNotifications(
    @CurrentUser() user: AuthedUser,
    @Query('limit') limit?: string,
  ): Promise<NotificationListResponse> {
    const n = Number.parseInt(limit ?? '', 10);
    return this.notifications.list(user.id, Number.isFinite(n) ? n : undefined);
  }

  /**
   * Mark read. Body `{ids}`, or an empty body for all.
   *
   * ── NOT A MUTATION THAT NEEDS AN `Idempotency-Key` (CLAUDE.md rule 2) ────
   *
   * The rule covers mutations that create or commit a reservation, or issue
   * credentials. This creates nothing and issues nothing, and it is idempotent
   * by construction: `read_at IS NULL` is in the predicate, so a replay marks
   * zero rows and returns the same state. Pinned with that reasoning in
   * `idempotency-contract.spec.ts`.
   *
   * 200, not 204 — the response carries the remaining unread count, which is
   * what the client's badge is drawn from. Returning nothing would make the app
   * re-fetch the list to find out whether the badge should still be there.
   */
  @Post('read')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mark notifications read — ids, or all of them' })
  @ApiOkResponse({ type: MarkReadResponse })
  async markRead(
    @CurrentUser() user: AuthedUser,
    @Body() dto: MarkNotificationsReadDto,
  ): Promise<MarkReadResponse> {
    const marked = await this.notifications.markRead(user.id, dto.ids);
    return { marked, unread_count: await this.notifications.unreadCount(user.id) };
  }
}
