import { Inject, Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { PUSH_DELIVERY, type NotificationType, type PushDelivery } from './notification.ports';
import { renderPush } from './notification-copy';

export interface NotifyInput {
  userId: string;
  type: NotificationType;
  /** Substitutions for the copy, and the deep-link payload. Strings only. */
  data: Record<string, string>;
}

/**
 * NOTIFY-1 Stage 1.
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
 */
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(PUSH_DELIVERY) private readonly push: PushDelivery,
  ) {}

  /** Record the notification, then try to deliver it. Never throws. */
  async notify(input: NotifyInput): Promise<string | null> {
    let id: string;
    try {
      const row = await this.prisma.notification.create({
        data: { userId: input.userId, type: input.type, data: input.data },
        select: { id: true },
      });
      id = row.id;
    } catch (err) {
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
      await this.prisma.notification.update({
        where: { id: notificationId },
        data: { deliveryError: 'no_registered_device' },
      });
      return;
    }

    const failures: string[] = [];
    for (const device of devices) {
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
