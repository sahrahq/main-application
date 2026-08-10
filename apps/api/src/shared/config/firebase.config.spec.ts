import { FirebaseConfigError, loadFirebaseConfig } from './firebase.config';

/**
 * THE CREDENTIAL MUST NOT BE ABLE TO REACH A LOG, AN ERROR OR A STACK TRACE.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * WHY THIS IS A TEST AND NOT A CODE REVIEW NOTE
 * ─────────────────────────────────────────────────────────────────────────
 *
 * The dangerous path is not one anybody writes on purpose. `JSON.parse` quotes
 * a window of the input back at you when the failure is an unexpected TOKEN:
 *
 *   JSON.parse('{"private_key": SUPERSECRETXYZ}')
 *   → Unexpected token 'S', ..."ate_key": SUPERSECRE"... is not valid JSON
 *
 * On a hand-mangled service-account file — a value that lost its quotes, a BOM
 * or junk prefix, a key pasted in raw — that snippet is a slice of the private
 * key, and it lands wherever the boot error lands: a terminal, a container log,
 * a crash reporter, a stack trace pasted into a bug report. Nobody chose it; it
 * is the default behaviour of the language.
 *
 * NOT every malformation does this, and the first version of this file assumed
 * they all did. A truncated file gives `Unterminated string in JSON at position
 * 126`, which is harmless. The guard-the-guard test at the bottom uses a shape
 * that genuinely leaks, because a hazard demonstration that does not
 * demonstrate the hazard is worse than none.
 *
 * So the assertions below feed a file containing a recognisable fake key and
 * check that **no part of it appears in what is thrown**. A reviewer can read
 * the loader and believe it is careful; only this can show it.
 */

/** Not a real key. Distinctive enough that a substring match is meaningful. */
const FAKE_PRIVATE_KEY =
  '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BSUPERSECRETXYZ123\n-----END PRIVATE KEY-----\n';
const FAKE_EMAIL = 'firebase-adminsdk-abc@sahra-test.iam.gserviceaccount.com';

const validFile = JSON.stringify({
  type: 'service_account',
  project_id: 'sahra-test',
  private_key_id: 'abc123',
  private_key: FAKE_PRIVATE_KEY,
  client_email: FAKE_EMAIL,
});

const env = (over: Record<string, string | undefined> = {}) =>
  ({
    FIREBASE_PROJECT_ID: 'sahra-test',
    FIREBASE_SERVICE_ACCOUNT_FILE: '/abs/sa.json',
    ...over,
  }) as NodeJS.ProcessEnv;

describe('loadFirebaseConfig', () => {
  it('loads a valid service account', () => {
    const cfg = loadFirebaseConfig(env(), () => validFile);
    expect(cfg).not.toBeNull();
    expect(cfg!.projectId).toBe('sahra-test');
    expect(cfg!.serviceAccount.clientEmail).toBe(FAKE_EMAIL);
    expect(cfg!.serviceAccount.privateKey).toContain('BEGIN PRIVATE KEY');
  });

  it('returns NULL when nothing is configured — that is not an error', () => {
    // Local development, CI and every test run have no service account and
    // must still boot. An error here would make "no push configured" and "push
    // configured wrongly" the same event.
    expect(loadFirebaseConfig({} as NodeJS.ProcessEnv, () => '')).toBeNull();
  });

  it('un-escapes a key that has been through an env var at some point', () => {
    const escaped = JSON.stringify({
      type: 'service_account',
      project_id: 'sahra-test',
      private_key: '-----BEGIN PRIVATE KEY-----\\nABC\\n-----END PRIVATE KEY-----\\n',
      client_email: FAKE_EMAIL,
    });
    const cfg = loadFirebaseConfig(env(), () => escaped);
    expect(cfg!.serviceAccount.privateKey).toContain('\n');
    expect(cfg!.serviceAccount.privateKey).not.toContain('\\n');
  });

  describe('half-configured is configured WRONGLY, and refuses to boot', () => {
    // The failure mode this prevents: somebody sets the project id, believes
    // push is on, and the process quietly falls back to the logging stub. It
    // would look fine until a diner missed a cancellation.
    it('project id without a file', () => {
      expect(() =>
        loadFirebaseConfig(env({ FIREBASE_SERVICE_ACCOUNT_FILE: undefined }), () => ''),
      ).toThrow(FirebaseConfigError);
    });

    it('file without a project id', () => {
      expect(() =>
        loadFirebaseConfig(env({ FIREBASE_PROJECT_ID: undefined }), () => validFile),
      ).toThrow(FirebaseConfigError);
    });

    it('a RELATIVE path', () => {
      // Resolves against the process working directory, which is one
      // `npm --prefix` away from meaning something else.
      expect(() =>
        loadFirebaseConfig(env({ FIREBASE_SERVICE_ACCOUNT_FILE: 'sa.json' }), () => validFile),
      ).toThrow(/absolute path/i);
    });

    it('a key from a DIFFERENT project', () => {
      // Two names for one project is how staging pushes to production.
      const other = JSON.stringify({
        type: 'service_account',
        project_id: 'someone-elses-project',
        private_key: FAKE_PRIVATE_KEY,
        client_email: FAKE_EMAIL,
      });
      expect(() => loadFirebaseConfig(env(), () => other)).toThrow(/wrong project|but FIREBASE/i);
    });

    it('google-services.json by mistake — the commonest wrong file', () => {
      const androidConfig = JSON.stringify({
        project_info: { project_id: 'sahra-test' },
        client: [],
      });
      expect(() => loadFirebaseConfig(env(), () => androidConfig)).toThrow(/missing/i);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  //  THE NEGATIVE THAT CARRIES THIS FILE.
  // ══════════════════════════════════════════════════════════════════════
  describe('NOTHING THROWN EVER CONTAINS THE KEY', () => {
    /** Every failure the loader can produce, given a file that has a key in it. */
    const cases: Array<[string, string]> = [
      // ── THE TWO THAT GENUINELY LEAK through a naive rethrow ─────────────
      // Both are unexpected-token errors, which is the form V8 quotes.
      ['a key value that lost its quotes', '{"private_key": SUPERSECRETXYZ123}'],
      ['junk before the JSON', 'SUPERSECRETXYZ123{"type":"service_account"}'],
      // ── And the ones that do not, kept so the sweep is over every shape ──
      ['truncated mid-key', validFile.slice(0, validFile.indexOf('SUPERSECRET') + 6)],
      ['trailing garbage', `${validFile}xx`],
      ['not JSON at all', `-----BEGIN PRIVATE KEY-----\nSUPERSECRETXYZ123\n`],
      [
        'valid JSON, wrong project',
        JSON.stringify({
          type: 'service_account',
          project_id: 'wrong',
          private_key: FAKE_PRIVATE_KEY,
          client_email: FAKE_EMAIL,
        }),
      ],
    ];

    it.each(cases)('%s', (_name, contents) => {
      let thrown: unknown;
      try {
        loadFirebaseConfig(env(), () => contents);
      } catch (e) {
        thrown = e;
      }

      // Not vacuous: it must actually have failed, or the assertions below are
      // checking an undefined for the absence of a secret.
      expect(thrown).toBeInstanceOf(Error);

      // The message, the stack, and a naive stringify of the whole error —
      // three places a logger might take it from.
      const surfaces = [
        (thrown as Error).message,
        (thrown as Error).stack ?? '',
        String(thrown),
        JSON.stringify(thrown, Object.getOwnPropertyNames(thrown as object)),
      ].join('\n');

      // `SUPERSECRE`, ten characters — V8's quoted window is about that wide,
      // so a canary longer than the window would pass while the leak happened.
      // Measured, not guessed: see the guard-the-guard below.
      for (const secret of ['SUPERSECRE', 'MIIEvQIBADAN', 'BEGIN PRIVATE KEY']) {
        expect(surfaces).not.toContain(secret);
      }
    });

    it('and the detector works — a naive rethrow WOULD have leaked', () => {
      // Guards the guard. If `JSON.parse` ever stopped quoting its input, every
      // assertion above would pass while proving nothing. This shows the hazard
      // is real in THIS Node version, so the loader's care is load-bearing
      // rather than superstition — and if a future Node makes it safe, this
      // fails and somebody gets to simplify deliberately.
      let native = '';
      try {
        JSON.parse('{"private_key": SUPERSECRETXYZ123}');
      } catch (e) {
        native = (e as Error).message;
      }
      expect(native).not.toBe('');
      // Ten characters of the value, verbatim:
      //   Unexpected token 'S', ..."ate_key": SUPERSECRE"... is not valid JSON
      // Bounded, and still a leak — key material in a log is key material in a
      // log, and several such errors narrow it further.
      expect(native).toContain('SUPERSECRE');
    });
  });
});
