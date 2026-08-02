/**
 * Ports for notifications. Same shape as the OTP ports, and for the same
 * reason: the thing that decides WHAT to send must not know HOW, or the
 * decision cannot be tested without a carrier and the carrier cannot be
 * swapped without touching the decision.
 */

/** The machine-readable kinds. The CLIENT owns the copy, keyed by this. */
export const NOTIFICATION_TYPES = [
  'reservation_cancelled_by_venue',
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

/** One addressable device. */
export interface PushTarget {
  token: string;
  platform: string;
  /** The device's language, which is not necessarily the account's. */
  locale: string;
}

export interface PushMessage {
  target: PushTarget;
  title: string;
  body: string;
  /** Deep-link payload — the client routes on it. Strings only: FCM's data
   * payload is a string map, and discovering that at send time is worse than
   * being told by a type. */
  data: Record<string, string>;
}

/**
 * Where a push physically goes.
 *
 * Stage 2 swaps `LoggingPushDelivery` for an FCM adapter. Nothing above this
 * interface changes when it does — which is the test of whether the seam is in
 * the right place.
 */
export interface PushDelivery {
  send(message: PushMessage): Promise<void>;
  /** For logs and audit: "fcm", "log". */
  readonly channel: string;
}

export const PUSH_DELIVERY = Symbol('PUSH_DELIVERY');
