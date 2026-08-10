import { Injectable, Logger } from '@nestjs/common';
import type { PushDelivery, PushMessage } from '../notification.ports';
import type { FirebaseConfig } from '../../../shared/config/firebase.config';
import { pushReadiness, type PushPlatform, type PushReadiness } from '../push-readiness';

/**
 * What a caller needs from firebase-admin, and nothing else.
 *
 * INJECTED AS A PORT so the adapter is testable without a network, a
 * credential, or the 15 MB of transitive SDK that `admin.initializeApp` drags
 * in. `FcmPushDelivery` is where the interesting decisions are — which
 * platforms are refused, what a dead token does — and none of them should need
 * Google's servers to exercise.
 */
export interface FcmSender {
  send(message: FcmMessage): Promise<string>;
}

export interface FcmMessage {
  token: string;
  notification: { title: string; body: string };
  data: Record<string, string>;
  android: { priority: 'high' | 'normal' };
}

/** Raised when a platform is not deliverable. Distinct so tests can name it. */
export class PushPlatformUnavailable extends Error {}

/**
 * FCM error codes that mean THE TOKEN IS DEAD, not that the send failed.
 *
 * The distinction is the whole reason this list exists. A transient failure
 * should be retried against the same token; a dead token should be revoked, or
 * it is retried forever and every send to that diner reports a failure that no
 * amount of retrying can fix.
 */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * NOTIFY-1 Stage 2 — push, for real.
 *
 * Replaces `LoggingPushDelivery`. Nothing above `PushDelivery` changed to make
 * this work, which was the test of whether the seam was in the right place.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * AN UNREACHABLE PLATFORM IS REFUSED HERE, BEFORE THE NETWORK
 * ─────────────────────────────────────────────────────────────────────────
 *
 * This is the load-bearing behaviour in this file and it is not an
 * optimisation.
 *
 * **FCM ACCEPTS AN iOS SEND WITH NO APNs KEY.** It answers with a message id.
 * The failure to reach Apple happens afterwards, inside Google's
 * infrastructure, and is never reported on the call that sent it. So an
 * implementation that simply forwarded everything would:
 *
 *   - return success for every iPhone
 *   - set `notifications.sent_at`, recording a delivery that did not happen
 *   - leave `delivery_error` null
 *   - and pass a manual test, because the tester's Android phone rang
 *
 * There would be no signal anywhere. So the platform check happens BEFORE the
 * send, it throws, and `NotificationsService` records the reason — meaning the
 * database says `ios_not_configured` instead of claiming success. See
 * `push-readiness.ts` for why the flag is manual.
 */
@Injectable()
export class FcmPushDelivery implements PushDelivery {
  readonly channel = 'fcm';
  private readonly logger = new Logger('PushDelivery');

  private readonly readiness: PushReadiness;

  constructor(
    config: FirebaseConfig,
    private readonly sender: FcmSender,
    /**
     * Called when FCM says a token is dead. Wired to
     * `DevicesService.revokeByToken` in the module; a function rather than the
     * service so this file depends on nothing but its ports.
     */
    private readonly onDeadToken: (token: string) => Promise<void>,
    env: NodeJS.ProcessEnv = process.env,
  ) {
    this.readiness = pushReadiness(config.projectId, env);
  }

  async send(message: PushMessage): Promise<void> {
    const platform = message.target.platform as PushPlatform;
    const support = this.readiness.platforms.find((p) => p.platform === platform);

    // AN UNKNOWN PLATFORM IS REFUSED, not passed through. `POST /devices`
    // validates against a fixed enum, so this can only be reached if that enum
    // grows without this file being told — and the safe answer to "can we reach
    // this?" is no.
    if (!support) {
      throw new PushPlatformUnavailable(
        `unknown_platform:${platform} — not in PUSH_PLATFORMS, so no delivery was attempted`,
      );
    }

    if (!support.deliverable) {
      // The string a human reads out of `notifications.delivery_error` six
      // weeks later, so it names the platform and the cause.
      throw new PushPlatformUnavailable(`${platform}_not_configured — ${support.reason}`);
    }

    try {
      await this.sender.send({
        token: message.target.token,
        notification: { title: message.title, body: message.body },
        data: message.data,
        // HIGH PRIORITY, deliberately. Every notification this system sends is
        // time-critical — a cancelled table tonight, a reminder two hours out,
        // a waitlist offer that is gone in minutes. Normal priority lets
        // Android hold a message until the device next wakes, which for a
        // dozing phone can be hours.
        android: { priority: 'high' },
      });
    } catch (err) {
      const code = (err as { code?: string })?.code ?? '';
      if (DEAD_TOKEN_CODES.has(code)) {
        // REVOKED, NOT RETRIED. A reinstalled app, a wiped phone, a handset
        // sold on: the token will never work again, and `devices.revoked_at`
        // exists exactly for this. Without it the same dead token is pushed to
        // on every notification for the life of the account.
        await this.onDeadToken(message.target.token).catch((e) =>
          // Failing to revoke must not turn a dead token into a thrown send:
          // the send genuinely did fail, and that is what the caller records.
          this.logger.error(`Could not revoke a dead token: ${String(e)}`),
        );
        throw new Error(`dead_token:${code}`);
      }

      // Anything else — a network blip, a quota, an outage. Rethrown as-is so
      // `NotificationsService` records it per device and the diner's other
      // handset still gets its chance.
      //
      // NOTE the error is rethrown by MESSAGE, not by object: an FCM error can
      // carry the request in `err.response`, and the request contains the
      // device token.
      throw new Error(`fcm_send_failed:${code || 'unknown'}`);
    }
  }
}
