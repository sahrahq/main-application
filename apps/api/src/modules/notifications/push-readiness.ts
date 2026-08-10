/**
 * WHICH PLATFORMS CAN ACTUALLY BE REACHED, as one answer the whole system uses.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THIS EXISTS BECAUSE "PUSH WORKS" MUST NOT BE ABLE TO LOOK TRUE
 * ─────────────────────────────────────────────────────────────────────────
 *
 * As of 2026-08-10 the Firebase project `sahra-4881d` has an **Android app and
 * nothing else**. There is no Apple Developer account, so there is no
 * `GoogleService-Info.plist` and no APNs auth key uploaded to Firebase.
 *
 * The dangerous property of that state is that it looks fine from every angle
 * an engineer normally checks:
 *
 *   - the adapter is bound and initialises without complaint
 *   - `admin.messaging().send()` on an iOS token is ACCEPTED by FCM and
 *     answers with a message id — FCM's failure to reach APNs happens later,
 *     asynchronously, and is not reported back on that call
 *   - an Android handset rings, so a manual test passes
 *
 * Every iPhone gets nothing, and the only symptom is silence. That is the
 * exact shape of defect this codebase keeps finding, and it is why the answer
 * is not a comment but a value that three separate things read: the startup
 * banner, `/health`, and the send path itself.
 *
 * ── WHEN iOS IS SET UP ───────────────────────────────────────────────────
 *
 * Upload the APNs key (Firebase Console → Cloud Messaging → APNs Authentication
 * Key), add the iOS app, drop `GoogleService-Info.plist` into
 * `apps/customer_app/ios/Runner/`, and set `FIREBASE_IOS_CONFIGURED=1`.
 *
 * The flag is manual and deliberately so. **Nothing in the FCM API can be asked
 * whether an APNs key is present** — there is no endpoint for it, and inferring
 * it from a send failure means discovering it from a diner's missed booking.
 * A human confirming a thing a human did is the honest mechanism; the guard is
 * that until they confirm it, every iOS send fails loudly and is recorded as a
 * failure rather than as a delivery.
 */

/** Platforms `POST /devices` accepts, and therefore that we may be asked to reach. */
export const PUSH_PLATFORMS = ['android', 'ios', 'web'] as const;
export type PushPlatform = (typeof PUSH_PLATFORMS)[number];

/** DI token for the computed readiness, so `/health` and the send path agree. */
export const PUSH_READINESS = Symbol('PUSH_READINESS');

export interface PlatformReadiness {
  platform: PushPlatform;
  deliverable: boolean;
  /** Why not. Empty when it is deliverable. */
  reason: string;
}

export interface PushReadiness {
  /** True when a real carrier is bound at all. */
  configured: boolean;
  projectId: string | null;
  platforms: PlatformReadiness[];
  /** The platforms a diner could register and never hear from. */
  unreachable: PushPlatform[];
}

export function pushReadiness(
  projectId: string | null,
  env: NodeJS.ProcessEnv = process.env,
): PushReadiness {
  const configured = projectId !== null;

  // OPT-IN, and false by default. A default of "configured" would mean the day
  // somebody adds an iOS build with no APNs key, everything reports healthy.
  const iosConfirmed = env.FIREBASE_IOS_CONFIGURED === '1';

  const platforms: PlatformReadiness[] = [
    {
      platform: 'android',
      deliverable: configured,
      reason: configured ? '' : 'no Firebase service account configured',
    },
    {
      platform: 'ios',
      deliverable: configured && iosConfirmed,
      reason: !configured
        ? 'no Firebase service account configured'
        : iosConfirmed
          ? ''
          : 'no APNs auth key — there is no Apple Developer account yet, so ' +
            'FCM accepts an iOS send and the handset never rings. Set ' +
            'FIREBASE_IOS_CONFIGURED=1 once the key is uploaded.',
    },
    {
      platform: 'web',
      deliverable: false,
      // Not a gap being tracked: doc 02 scopes the customer app to iOS and
      // Android. `web` is in the DTO's enum because `POST /devices` validates
      // against the doc 04 column, not because anything ships it.
      reason: 'web push is not in scope (doc 02 — iOS and Android only)',
    },
  ];

  return {
    configured,
    projectId,
    platforms,
    unreachable: platforms.filter((p) => !p.deliverable).map((p) => p.platform),
  };
}

/**
 * The startup banner. Returned as lines rather than logged here, so the same
 * text is testable without capturing a logger.
 *
 * Deliberately shouty. A one-line `warn` among two hundred boot lines is a line
 * nobody reads, and the thing it is warning about is invisible by nature.
 */
export function pushReadinessBanner(readiness: PushReadiness): string[] {
  if (!readiness.configured) {
    return [
      'PUSH IS NOT CONFIGURED — no notification will reach any handset.',
      'Diners see notifications only by opening the app. This is expected in',
      'development and CI. Set FIREBASE_PROJECT_ID and',
      'FIREBASE_SERVICE_ACCOUNT_FILE to enable delivery.',
    ];
  }

  const blocked = readiness.platforms.filter((p) => !p.deliverable && p.platform !== 'web');
  if (blocked.length === 0) {
    return [`Push configured for project ${readiness.projectId} — all platforms deliverable.`];
  }

  return [
    '════════════════════════════════════════════════════════════════════',
    `  PUSH IS PARTIALLY CONFIGURED — project ${readiness.projectId}`,
    '',
    ...blocked.flatMap((p) => [
      `  ${p.platform.toUpperCase()} CANNOT BE REACHED.`,
      `    ${p.reason}`,
    ]),
    '',
    '  Android push works. Do not read that as "push works" — a send to an',
    '  unreachable platform is refused before it leaves this process and is',
    '  recorded in notifications.delivery_error, so the database never claims',
    '  a delivery that did not happen.',
    '════════════════════════════════════════════════════════════════════',
  ];
}
