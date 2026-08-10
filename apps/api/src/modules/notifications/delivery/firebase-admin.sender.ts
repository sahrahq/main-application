import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { FirebaseConfig } from '../../../shared/config/firebase.config';
import type { FcmMessage, FcmSender } from './fcm-push.delivery';

/**
 * The only file in this repository that imports `firebase-admin`.
 *
 * ── WHY THE SDK IS BEHIND ITS OWN THIN CLASS ────────────────────────────
 *
 * `FcmPushDelivery` holds the decisions worth testing — which platforms are
 * refused, what a dead token does, what gets recorded. None of those should
 * require Google's SDK to be initialised, a credential to exist, or a socket to
 * open. So the SDK sits here, behind a two-method interface, and the adapter
 * takes that interface.
 *
 * The practical test of the boundary: `fcm-push.delivery.spec.ts` exercises
 * every branch of the adapter with a fake sender, no credential and no network.
 *
 * The MODULAR entrypoints (`firebase-admin/app`, `firebase-admin/messaging`)
 * rather than the `import * as admin` namespace — v14 removed the namespace
 * members, so the old form compiles against the types and fails at runtime.
 *
 * ── AND THE APP IS NAMED ────────────────────────────────────────────────
 *
 * `initializeApp()` with no name registers the SDK's global default app and
 * throws on a second call. A named app makes this safe to construct twice —
 * which happens in tests, and in a Nest e2e suite that builds the module more
 * than once per process.
 */
export const FIREBASE_APP_NAME = 'sahra-push';

export class FirebaseAdminSender implements FcmSender {
  private readonly app: App;

  constructor(config: FirebaseConfig) {
    this.app =
      getApps().find((a) => a.name === FIREBASE_APP_NAME) ??
      initializeApp(
        {
          // `cert()` takes the object and never logs it. The credential goes
          // straight from `loadFirebaseConfig` to here without passing through
          // a string, a template or an error message.
          credential: cert({
            projectId: config.serviceAccount.projectId,
            clientEmail: config.serviceAccount.clientEmail,
            privateKey: config.serviceAccount.privateKey,
          }),
          projectId: config.projectId,
        },
        FIREBASE_APP_NAME,
      );
  }

  async send(message: FcmMessage): Promise<string> {
    return getMessaging(this.app).send(message);
  }
}
