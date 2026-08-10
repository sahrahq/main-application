import { FcmPushDelivery, PushPlatformUnavailable, type FcmMessage } from './fcm-push.delivery';
import type { FirebaseConfig } from '../../../shared/config/firebase.config';
import type { PushMessage } from '../notification.ports';

/**
 * The FCM adapter, and the assertion the whole Stage 2 batch rests on.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * "PUSH WORKS" MUST NOT BE ABLE TO LOOK TRUE WHILE EVERY iPHONE GETS NOTHING
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Firebase project `sahra-4881d` has an Android app and no APNs key, because
 * there is no Apple Developer account. The failure that state produces is
 * invisible from every angle an engineer normally checks:
 *
 *   - **FCM accepts an iOS send with no APNs key** and answers with a message
 *     id. The failure to reach Apple happens later, inside Google, and is never
 *     reported on that call.
 *   - so `sent_at` would be set, `delivery_error` would be null, and the
 *     database would record a delivery that did not happen
 *   - and a manual test passes, because the tester's Android phone rings
 *
 * The only defence is to refuse before the network. These tests are what prove
 * the refusal happens and that it is recorded rather than swallowed.
 *
 * Every case runs with a FAKE sender: no credential, no SDK, no socket. The
 * decisions worth testing are all in the adapter.
 */

const config: FirebaseConfig = {
  projectId: 'sahra-test',
  serviceAccount: {
    projectId: 'sahra-test',
    clientEmail: 'x@sahra-test.iam.gserviceaccount.com',
    privateKey: 'not-a-real-key',
  },
};

class FakeSender {
  sent: FcmMessage[] = [];
  error: (Error & { code?: string }) | null = null;

  async send(message: FcmMessage): Promise<string> {
    if (this.error) throw this.error;
    this.sent.push(message);
    return 'projects/sahra-test/messages/1';
  }
}

const message = (platform: string): PushMessage => ({
  target: { token: `tok-${platform}`, platform, locale: 'en' },
  title: 'Layali Lounge cancelled your table',
  body: 'Tonight, 21:00',
  data: { type: 'reservation_cancelled_by_venue', reservation_id: 'r1' },
});

/** Android reachable, iOS not — the shipped configuration on 2026-08-10. */
const ANDROID_ONLY = { FIREBASE_IOS_CONFIGURED: undefined } as NodeJS.ProcessEnv;
const BOTH = { FIREBASE_IOS_CONFIGURED: '1' } as NodeJS.ProcessEnv;

describe('FcmPushDelivery', () => {
  let sender: FakeSender;
  let revoked: string[];
  const make = (env: NodeJS.ProcessEnv) =>
    new FcmPushDelivery(config, sender, async (t) => void revoked.push(t), env);

  beforeEach(() => {
    sender = new FakeSender();
    revoked = [];
  });

  it('sends to Android', async () => {
    await make(ANDROID_ONLY).send(message('android'));

    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].token).toBe('tok-android');
    expect(sender.sent[0].notification.title).toContain('cancelled your table');
    // The deep-link payload the client routes on survives the trip.
    expect(sender.sent[0].data.reservation_id).toBe('r1');
  });

  it('sends at HIGH priority, because every one of these is time-critical', () => {
    // Normal priority lets Android hold a message until the device next wakes,
    // which for a dozing phone is hours. A cancelled table tonight, a reminder
    // two hours out and a waitlist offer that expires in ten minutes are all
    // useless late.
    return make(ANDROID_ONLY)
      .send(message('android'))
      .then(() => expect(sender.sent[0].android.priority).toBe('high'));
  });

  // ══════════════════════════════════════════════════════════════════════
  //  THE LOAD-BEARING ONE.
  // ══════════════════════════════════════════════════════════════════════
  describe('iOS, with no APNs key', () => {
    it('IS REFUSED BEFORE THE NETWORK — nothing is handed to FCM', async () => {
      await expect(make(ANDROID_ONLY).send(message('ios'))).rejects.toThrow(
        PushPlatformUnavailable,
      );

      // The part that matters. If this call reached FCM it would SUCCEED, set
      // `sent_at`, and record a delivery that never happened.
      expect(sender.sent).toEqual([]);
    });

    it('and the reason names the platform and the cause', async () => {
      // This string is what a human reads out of `notifications.delivery_error`
      // six weeks later, when somebody asks why an iPhone user missed a
      // cancellation. "Error" would not answer that.
      await expect(make(ANDROID_ONLY).send(message('ios'))).rejects.toThrow(
        /ios_not_configured.*APNs/s,
      );
    });

    it('while Android in the SAME configuration still works', async () => {
      // The trap this batch exists to avoid: half-working is the state that
      // looks fine. Both halves are asserted together so neither can be read
      // as the whole story.
      const delivery = make(ANDROID_ONLY);
      await delivery.send(message('android'));
      await expect(delivery.send(message('ios'))).rejects.toThrow();
      expect(sender.sent.map((m) => m.token)).toEqual(['tok-android']);
    });

    it('and it starts working the moment the key is confirmed', async () => {
      // The flag is the only thing standing between here and a working iOS
      // push. Asserted so the refusal is provably a configuration state and not
      // a hardcoded "iOS is off".
      await make(BOTH).send(message('ios'));
      expect(sender.sent.map((m) => m.token)).toEqual(['tok-ios']);
    });
  });

  it('refuses `web`, which is not in scope', async () => {
    // doc 02 scopes the customer app to iOS and Android. `web` is in the
    // `POST /devices` enum because it is in the doc 04 column, and a token that
    // can be registered must not be silently dropped at send time.
    await expect(make(BOTH).send(message('web'))).rejects.toThrow(/web/);
    expect(sender.sent).toEqual([]);
  });

  it('refuses a platform it has never heard of', async () => {
    // Only reachable if the `POST /devices` enum grows without this file being
    // told. The safe answer to "can we reach this?" is no.
    await expect(make(BOTH).send(message('watchos'))).rejects.toThrow(/unknown_platform/);
    expect(sender.sent).toEqual([]);
  });

  describe('a dead token is revoked, not retried forever', () => {
    it.each([
      'messaging/registration-token-not-registered',
      'messaging/invalid-registration-token',
      'messaging/invalid-argument',
    ])('%s', async (code) => {
      sender.error = Object.assign(new Error('boom'), { code });

      await expect(make(ANDROID_ONLY).send(message('android'))).rejects.toThrow(/dead_token/);

      // `devices.revoked_at` exists for exactly this: a reinstalled app, a
      // wiped phone, a handset sold on. Without it the same dead token is
      // pushed to on every notification for the life of the account.
      expect(revoked).toEqual(['tok-android']);
    });

    it('but a TRANSIENT failure does not revoke anything', async () => {
      // The distinction is the whole point of the list. Revoking on a network
      // blip would silently unsubscribe a working handset, and nothing would
      // ever tell the diner.
      sender.error = Object.assign(new Error('boom'), { code: 'messaging/server-unavailable' });

      await expect(make(ANDROID_ONLY).send(message('android'))).rejects.toThrow(/fcm_send_failed/);
      expect(revoked).toEqual([]);
    });

    it('and a failure to revoke still reports the send as failed', async () => {
      // The send genuinely did fail. Losing that because the bookkeeping also
      // failed would leave `sent_at` set on a notification nobody received.
      sender.error = Object.assign(new Error('boom'), {
        code: 'messaging/registration-token-not-registered',
      });
      const delivery = new FcmPushDelivery(
        config,
        sender,
        async () => {
          throw new Error('database down');
        },
        ANDROID_ONLY,
      );
      await expect(delivery.send(message('android'))).rejects.toThrow(/dead_token/);
    });
  });

  it('never rethrows the FCM error object, which can carry the token', async () => {
    // An FCM error can hold the request in `err.response`, and the request
    // contains the device token. Rethrowing by message keeps a registration
    // token out of the log line that records the failure.
    const original = Object.assign(new Error('raw'), {
      code: 'messaging/server-unavailable',
      response: { token: 'tok-android-SECRET' },
    });
    sender.error = original;

    const thrown = await make(ANDROID_ONLY)
      .send(message('android'))
      .catch((e: Error) => e);

    expect(thrown).not.toBe(original);
    expect(JSON.stringify(thrown, Object.getOwnPropertyNames(thrown))).not.toContain('SECRET');
  });

  it('reports its channel as fcm, so an audit line says which carrier ran', () => {
    expect(make(BOTH).channel).toBe('fcm');
  });
});
