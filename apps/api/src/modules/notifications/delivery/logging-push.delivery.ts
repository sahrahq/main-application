import { Injectable, Logger } from '@nestjs/common';
import type { PushDelivery, PushMessage } from '../notification.ports';

/**
 * STUB DELIVERY — writes the push to the application log instead of sending it.
 *
 * NOTIFY-1 Stage 2 replaces this with an FCM adapter, which needs a Firebase
 * project and a service-account key. Replacing this class is the entire
 * integration surface; `NotificationsService` does not change.
 *
 * THIS ADAPTER REFUSES TO RUN IN PRODUCTION — the same guard as
 * `LoggingOtpDelivery`, for a weaker but real reason. An OTP in a log is a
 * working credential; a push in a log is merely a diner who was never told
 * their table was cancelled, silently, while the system reported success.
 * "We forgot to swap the adapter" is the mistake both classes exist to make
 * impossible, and a notification nobody receives is exactly the failure
 * NOTIFY-1 was opened about.
 */
@Injectable()
export class LoggingPushDelivery implements PushDelivery {
  readonly channel = 'log';
  private readonly logger = new Logger('PushDelivery');

  constructor(nodeEnv: string = process.env.NODE_ENV ?? 'development') {
    if (nodeEnv === 'production') {
      throw new Error(
        'LoggingPushDelivery must never run in production: it writes ' +
          'notifications to the log instead of delivering them, so every diner ' +
          'would silently never be told. Configure the FCM adapter first ' +
          '(NOTIFY-1 Stage 2).',
      );
    }
  }

  async send(message: PushMessage): Promise<void> {
    this.logger.warn(
      `[STUB PUSH] -> ${message.target.platform}/${message.target.locale} ` +
        `"${message.title}" / "${message.body}" ${JSON.stringify(message.data)} ` +
        '— not actually sent.',
    );
  }
}
