/**
 * Ports for notifications. Same shape as the OTP ports, and for the same
 * reason: the thing that decides WHAT to send must not know HOW, or the
 * decision cannot be tested without a carrier and the carrier cannot be
 * swapped without touching the decision.
 */

/**
 * The machine-readable kinds. The CLIENT owns the copy, keyed by this.
 *
 * ── EVERY ENTRY HERE HAS A CAUSE THAT ALREADY FIRES ──────────────────────
 *
 * A type with no emitter is a string in a switch statement: it looks like a
 * feature, it has copy in two languages, and no diner will ever receive one.
 * The client's `notification_type_test.dart` reads THIS list off disk and fails
 * if the Dart enum drifts from it, so an unemitted type would also grow a
 * translated string in both ARBs and a case in the centre's renderer — three
 * files of evidence for something that does not happen.
 *
 * Types deliberately NOT here, and why, so nobody adds them speculatively:
 *
 *   - `review_invite` ("How was your visit?") — doc 11 §5 fires it the morning
 *     after a `completed` reservation. Of the six owner actions in doc 06 §4
 *     only `cancel` is built, so no reservation reaches `completed` and the
 *     cause does not exist.
 *   - `reservation_accepted` / `reservation_declined` — same reason: the venue
 *     `accept`/`decline` actions are not built.
 *   - `hold_expired` — the diner walked away from a checkout. Telling them
 *     about the consequence of abandoning something is noise.
 */
export const NOTIFICATION_TYPES = [
  /** The venue cancelled a table. Stage 1's only type. */
  'reservation_cancelled_by_venue',
  /** A hold became a booking. The receipt, in the centre. */
  'reservation_confirmed',
  /** 24 hours out (C-3.9). */
  'reservation_reminder_24h',
  /** 2 hours out (C-3.9). */
  'reservation_reminder_2h',
  /** A table freed and this diner is next in the queue (C-3.6). */
  'waitlist_offer',
  /** Their turn passed to the next person. */
  'waitlist_offer_expired',
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
 * the right place. What that swap needs from the product owner is listed in
 * `docs/decisions/2026-08-09-firebase-handover.md`.
 */
export interface PushDelivery {
  send(message: PushMessage): Promise<void>;
  /** For logs and audit: "fcm", "log". */
  readonly channel: string;
}

export const PUSH_DELIVERY = Symbol('PUSH_DELIVERY');
