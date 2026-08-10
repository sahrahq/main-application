import { Inject, Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { PUSH_DELIVERY, type NotificationType, type PushDelivery } from './notification.ports';
import { PUSH_READINESS, platformSupported, type PushReadiness } from './push-readiness';
import { renderPush } from './notification-copy';

export interface NotifyInput {
  userId: string;
  type: NotificationType;
  /** Substitutions for the copy, and the deep-link payload. Strings only. */
  data: Record<string, string>;
  /**
   * At most one notification per key, ever.
   *
   * For notifications emitted by a SWEEPER rather than by a request — the
   * reminders, the offer-expiry pass. Those are at-least-once by construction
   * and a diner told three times that their table is tomorrow learns to ignore
   * us. Enforced by `idx_notifications_dedupe`, a partial UNIQUE index, not by
   * a check-then-insert: two workers can both find nothing and both insert.
   *
   * Omit it for event-driven notifications. A venue legitimately cancelling two
   * of a diner's tables in one evening must produce two.
   */
  dedupeKey?: string;
}

export interface NotificationRow {
  id: string;
  type: string;
  data: Record<string, string>;
  created_at: string;
  read_at: string | null;
}

export interface NotificationPage {
  items: NotificationRow[];
  unread_count: number;
}

/** Postgres unique-violation — the dedupe index refusing a repeat. */
const PG_UNIQUE_VIOLATION = 'P2002';

/**
 * `data` is `jsonb`, so the DATABASE cannot promise the values are strings even
 * though `NotifyInput` does. Coerced on the way out rather than trusted.
 *
 * The contract says `Map<String, String>` and the generated Dart client parses
 * it as one — an old row with a number in it would throw a cast error inside
 * `NotificationResponse.fromJson`, which surfaces as an empty notification
 * centre with no explanation. Nulls are dropped rather than stringified to
 * "null", which is a word a diner should never be shown.
 */
function stringValues(value: unknown): Record<string, string> {
  const out: Record<string, string> = {};
  if (value && typeof value === 'object') {
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (v !== null && v !== undefined) out[k] = String(v);
    }
  }
  return out;
}

/** One page of the centre. Generous: a diner scrolls, they do not paginate. */
const PAGE_SIZE = 50;

/**
 * NOTIFY-1.
 *
 * THE RECORD IS WRITTEN FIRST, AND SEPARATELY FROM DELIVERY. `notify()`
 * returns as soon as the row exists; pushing is a best effort that happens
 * after. That ordering is the whole design:
 *
 *   - a diner who was owed a message is owed it whether or not FCM was up
 *   - the in-app centre (C-4.7) can show it even if every push failed
 *   - and the event that caused it — a venue cancelling a table — must never
 *     fail because a notification could not be delivered. A cancellation that
 *     rolls back because a push timed out is a table nobody freed.
 *
 * ── WHAT THE READ HALF CHANGED, AND WHAT IT DID NOT ──────────────────────
 *
 * Group G added `list`, `markRead` and `unreadCount` — the first reads of
 * `read_at` in the codebase, and the reason `idx_notif_user_unread` exists.
 * Delivery is unchanged and still a stub: `LoggingPushDelivery` is bound, so
 * every notification in the system currently records `no_registered_device`
 * and reaches the diner only if they open the centre and look.
 */
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(PUSH_DELIVERY) private readonly push: PushDelivery,
    // The SAME answer the boot banner and `/health` read. See the send loop.
    @Inject(PUSH_READINESS) private readonly readiness: PushReadiness,
  ) {}

  /**
   * Record the notification, then try to deliver it. **Never throws.**
   *
   * Returns the id, or null when nothing was written — which now means either
   * "the insert failed" or "this one was already sent" (a dedupe hit). Both are
   * non-events for the caller; the log distinguishes them for an operator.
   */
  async notify(input: NotifyInput): Promise<string | null> {
    let id: string;
    try {
      const row = await this.prisma.notification.create({
        data: {
          userId: input.userId,
          type: input.type,
          data: input.data,
          dedupeKey: input.dedupeKey ?? null,
        },
        select: { id: true },
      });
      id = row.id;
    } catch (err) {
      // THE DEDUPE INDEX DOING ITS JOB IS NOT AN ERROR. A sweeper that runs
      // twice over the same reservation reaches here, and the correct outcome
      // is silence — the diner has already been told.
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === PG_UNIQUE_VIOLATION &&
        input.dedupeKey
      ) {
        this.logger.debug(`Already sent ${input.dedupeKey}; not repeating.`);
        return null;
      }
      // Even the record failed. Log and return — the caller's own work (a
      // cancellation, a booking) must still stand.
      this.logger.error(`Could not record ${input.type} for ${input.userId}: ${String(err)}`);
      return null;
    }

    await this.deliver(id, input).catch((err) =>
      this.logger.error(`Delivery of ${id} failed: ${String(err)}`),
    );
    return id;
  }

  /**
   * C-4.7 — the in-app centre.
   *
   * Newest first, served by `idx_notifications_user`. The unread count is a
   * separate query rather than a filter over the page, because "3 unread" must
   * be true of the whole history and not of the fifty rows we happened to
   * return — a badge that counts a page is a badge that reads zero for a diner
   * with fifty-one notifications.
   */
  async list(userId: string, limit = PAGE_SIZE): Promise<NotificationPage> {
    const [rows, unread] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: Math.min(Math.max(limit, 1), PAGE_SIZE),
        select: { id: true, type: true, data: true, createdAt: true, readAt: true },
      }),
      this.unreadCount(userId),
    ]);

    return {
      items: rows.map((r) => ({
        id: r.id,
        type: r.type,
        data: stringValues(r.data),
        created_at: r.createdAt.toISOString(),
        read_at: r.readAt?.toISOString() ?? null,
      })),
      unread_count: unread,
    };
  }

  /** Served by `idx_notif_user_unread` — partial, on exactly this predicate. */
  async unreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({ where: { userId, readAt: null } });
  }

  /**
   * Mark notifications read. `ids` omitted means all of them.
   *
   * ── ALREADY-READ ROWS ARE NOT RE-STAMPED ────────────────────────────────
   *
   * `readAt: null` is in the predicate, so `read_at` keeps the moment the diner
   * FIRST saw it. Without that, every reopen of the centre would rewrite the
   * timestamp and "when did they see the cancellation?" — the question the
   * column exists to answer, and the one the acknowledgement model is built on
   * — would only ever return the last time they scrolled past it.
   *
   * ── AND IT IS SCOPED TO THE CALLER IN THE UPDATE ────────────────────────
   *
   * `userId` is in the WHERE clause, not checked before it. Ids are the only
   * input; without the predicate, a diner could mark somebody else's
   * notifications read — silencing a stranger's badge. Same discipline as
   * `OwnerCancellationService`.
   *
   * Returns how many rows changed, which is what makes "it did nothing" a
   * distinguishable outcome in a test rather than an assumption.
   */
  async markRead(userId: string, ids?: string[]): Promise<number> {
    const result = await this.prisma.notification.updateMany({
      where: {
        userId,
        readAt: null,
        ...(ids && ids.length > 0 ? { id: { in: ids } } : {}),
      },
      data: { readAt: new Date() },
    });
    return result.count;
  }

  /**
   * Push to every live device the user has.
   *
   * Per-device failures are recorded, not thrown: one dead token must not stop
   * the diner's other handset from ringing.
   */
  private async deliver(notificationId: string, input: NotifyInput): Promise<void> {
    const devices = await this.prisma.device.findMany({
      where: { userId: input.userId, revokedAt: null },
      select: { token: true, platform: true, locale: true },
    });

    if (devices.length === 0) {
      // Not an error. A diner with no registered device is exactly the person
      // the in-app centre exists for, and recording why is more useful than
      // an empty `sent_at`.
      //
      // TODAY THIS IS EVERY NOTIFICATION IN THE SYSTEM. Nothing acquires a push
      // token, because that needs FCM. `no_registered_device` is the honest
      // record of that, and it is what an operator should see until the
      // Firebase handover is done.
      await this.prisma.notification.update({
        where: { id: notificationId },
        data: { deliveryError: 'no_registered_device' },
      });
      return;
    }

    const failures: string[] = [];
    for (const device of devices) {
      // ── PLATFORM SUPPORT IS A PROPERTY OF THE SYSTEM, NOT OF THE ADAPTER ──
      //
      // This check used to live only inside `FcmPushDelivery`, which meant the
      // guarantee "the database never claims an iPhone was reached" evaporated
      // the moment a different adapter was bound — including in CI and in
      // every local run, where `LoggingPushDelivery` is bound and cheerfully
      // "delivers" to iOS, setting `sent_at` on a delivery that never happened.
      //
      // Found on 2026-08-10 when the e2e suite ran on a machine with no
      // Firebase credentials. It is the mirror image of the `venue-cancellation`
      // defect fixed the same week, where a test asserted the STUB's behaviour
      // and broke once a real carrier appeared. Both say the same thing:
      // A GUARANTEE THAT DEPENDS ON WHICH IMPLEMENTATION IS BOUND IS NOT A
      // GUARANTEE. Asking the readiness answer here makes it one, and it is
      // the same answer `/health` and the boot banner read, so the three
      // cannot disagree.
      //
      // The adapter keeps its own check. That is deliberate belt-and-braces,
      // not duplication with drift risk: both read `PUSH_READINESS`, so there
      // is one source and two places that refuse.
      // `platformSupported`, NOT `readiness.deliverable`. The latter folds in
      // "is a carrier configured", which is an ENVIRONMENT fact — gating on it
      // refused Android whenever no credential was present, i.e. in CI and
      // every local run, and nothing was ever recorded as sent. See the long
      // note on `platformSupported`.
      const support = platformSupported(device.platform);
      if (!support.supported) {
        failures.push(`${device.platform}: ${support.reason}`);
        continue;
      }

      const copy = renderPush(input.type, input.data, device.locale);
      try {
        await this.push.send({
          target: device,
          title: copy.title,
          body: copy.body,
          data: { type: input.type, ...input.data },
        });
      } catch (err) {
        failures.push(`${device.platform}: ${String(err)}`);
      }
    }

    await this.prisma.notification.update({
      where: { id: notificationId },
      data: {
        // `sent_at` means "at least one device was reached". Partial delivery
        // is delivery; total failure is not.
        sentAt: failures.length < devices.length ? new Date() : null,
        deliveryError: failures.length > 0 ? failures.join(' | ') : null,
      },
    });
  }
}
