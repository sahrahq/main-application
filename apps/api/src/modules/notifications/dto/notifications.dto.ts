import { ApiPropertyOptional } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsOptional, IsUUID } from 'class-validator';

/**
 * doc 06 §3 — `POST /notifications/read`.
 *
 * ── AN EMPTY BODY MEANS "ALL", DELIBERATELY ──────────────────────────────
 *
 * The centre marks everything read when the diner opens it, which is what the
 * bell indicator's disappearance means. Requiring the client to send the ids it
 * happens to be holding would make "all" mean "all fifty I fetched", and a
 * diner with sixty notifications would open the centre, read everything, and
 * still see an unread badge.
 *
 * `ids` exists for the per-item case that does not exist yet (swipe to mark one
 * read). It is here because the alternative — adding a body shape later — is a
 * contract change, and this one is free.
 */
export class MarkNotificationsReadDto {
  @ApiPropertyOptional({
    type: [String],
    description:
      'Notification ids to mark read. Omit to mark every unread notification ' +
      'for the caller. Ids belonging to another user are ignored, not refused.',
    maxItems: 200,
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(200)
  @IsUUID('4', { each: true })
  ids?: string[];
}
