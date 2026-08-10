import { readFileSync } from 'fs';
import { isAbsolute } from 'path';

/**
 * The Firebase service-account credential, loaded from a FILE PATH.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * A PATH, NOT THE JSON INLINE — AND THAT IS A SECURITY DECISION
 * ─────────────────────────────────────────────────────────────────────────
 *
 * `.env.example` used to declare `FIREBASE_SERVICE_ACCOUNT_JSON`, meaning the
 * whole 2.3 KB private key pasted into a file a human edits by hand. That was
 * wrong, and it was replaced before anything read it:
 *
 *   - **dotenv puts every `.env` value into `process.env`.** One
 *     `console.log(process.env)` — in a debug session, a crash reporter, a
 *     "why is my config wrong" moment — prints the private key. A path is a
 *     short, boring string that can appear in a log harmlessly.
 *   - **A file you hand-edit is a file you paste into a diff, a screenshot or
 *     a chat message.** The key never has to be opened at all now.
 *   - **The key stays outside the repository**, where no `git add -A` can
 *     reach it, and `.gitignore` covers `secrets/`, `*-firebase-adminsdk-*.json`
 *     and `*.p8` as a second line anyway.
 *
 * The cost is that production must mount the file rather than inject a
 * variable. That is normal for every platform doc 10 names, and it is the same
 * shape as `GOOGLE_APPLICATION_CREDENTIALS`, which the Google SDKs have always
 * read as a path.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * NOTHING HERE CAN ECHO THE KEY
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Every failure path below constructs its message from **the path and the
 * problem**, never from the file's contents. That is not a style preference —
 * two of these were live hazards:
 *
 *   - **`JSON.parse` quotes a window of the input back at you.** Measured on
 *     Node 22, not assumed — and the first draft of this comment was too broad,
 *     so here is what actually happens. An *unterminated string* is safe
 *     (`Unterminated string in JSON at position 126`). An **unexpected token**
 *     is not:
 *
 *         JSON.parse('{"private_key": SUPERSECRETXYZ}')
 *         → Unexpected token 'S', ..."ate_key": SUPERSECRE"... is not valid JSON
 *
 *     That is a realistic shape for a mangled credential: a value that lost its
 *     quotes, a file with a BOM or junk prefix, a key pasted in raw. The
 *     snippet is a slice of the private key and it lands in the log as an
 *     unhandled boot error. So the parse is wrapped and the original message is
 *     **discarded**, not chained.
 *   - The loaded object must never be spread into an error, a `JSON.stringify`
 *     of config, or a Nest DI failure. It is returned and handed straight to
 *     `admin.credential.cert()`.
 *
 * `firebase.config.spec.ts` asserts the negative directly: it feeds a
 * corrupt file containing a recognisable fake key and checks the thrown message
 * does not contain any of it.
 */

/** The fields `admin.credential.cert()` actually needs. */
export interface FirebaseServiceAccount {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

export interface FirebaseConfig {
  projectId: string;
  serviceAccount: FirebaseServiceAccount;
}

/** Thrown for every failure. Its message never contains file contents. */
export class FirebaseConfigError extends Error {}

/**
 * Read the credential, or return null when Firebase is simply not configured.
 *
 * NULL IS A FIRST-CLASS ANSWER, not an error. Local development, CI and every
 * test run have no service account, and they must boot — the stub delivery
 * exists for exactly that. An error here would make "no push configured" and
 * "push configured wrongly" the same event, and the second one needs to be
 * loud while the first is routine.
 *
 * Configured-but-broken IS an error, and it throws.
 */
export function loadFirebaseConfig(
  env: NodeJS.ProcessEnv = process.env,
  read: (path: string) => string = (p) => readFileSync(p, 'utf8'),
): FirebaseConfig | null {
  const path = env.FIREBASE_SERVICE_ACCOUNT_FILE?.trim();
  const projectId = env.FIREBASE_PROJECT_ID?.trim();

  if (!path && !projectId) return null;

  // HALF-CONFIGURED IS CONFIGURED WRONGLY, and it must not fall back to the
  // stub. Somebody who set one of the two believes push is on; booting quietly
  // into the logging adapter would prove them right until a diner missed a
  // cancellation.
  if (!path) {
    throw new FirebaseConfigError(
      'FIREBASE_PROJECT_ID is set but FIREBASE_SERVICE_ACCOUNT_FILE is not. ' +
        'Set it to the ABSOLUTE PATH of the service-account JSON downloaded ' +
        'from Firebase Console → Project settings → Service accounts. Never ' +
        'paste the JSON itself into .env.',
    );
  }
  if (!projectId) {
    throw new FirebaseConfigError(
      'FIREBASE_SERVICE_ACCOUNT_FILE is set but FIREBASE_PROJECT_ID is not.',
    );
  }

  if (!isAbsolute(path)) {
    // A relative path resolves against the process working directory, which is
    // one `npm --prefix` away from meaning something else. For a credential,
    // "it worked on my machine" is not an acceptable failure mode.
    throw new FirebaseConfigError(
      `FIREBASE_SERVICE_ACCOUNT_FILE must be an absolute path (got a relative one).`,
    );
  }

  let raw: string;
  try {
    raw = read(path);
  } catch {
    // The original error is dropped: an fs error message contains only the
    // path, but chaining it invites a future `cause` that carries more.
    throw new FirebaseConfigError(
      `Could not read the Firebase service-account file at ${path}. ` +
        'Check the path and that the process can read it.',
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    // ── THE ONE THAT MATTERS ──────────────────────────────────────────────
    // V8's SyntaxError quotes a ~10-character window of the input when the
    // failure is an unexpected TOKEN — an unquoted value, a junk prefix — and
    // on a credential file that window is a slice of the private key. The
    // original message is DISCARDED, never chained and never logged.
    // (Truncation gives "Unterminated string", which is harmless; measured in
    // `firebase.config.spec.ts` rather than assumed either way.)
    throw new FirebaseConfigError(
      `The Firebase service-account file at ${path} is not valid JSON. ` +
        'Re-download it from the Firebase console — it must be the file exactly ' +
        'as generated. (The parser error is deliberately not repeated here: it ' +
        'quotes the malformed input, which would put part of the private key in ' +
        'the log.)',
    );
  }

  const account = parsed as Record<string, unknown>;
  const missing = (['project_id', 'client_email', 'private_key'] as const).filter(
    (k) => typeof account[k] !== 'string' || (account[k] as string).length === 0,
  );
  if (missing.length > 0) {
    // Field NAMES, never values — the same discipline as `secrets.validation.ts`,
    // which reports secret names and bit counts and never the secret.
    throw new FirebaseConfigError(
      `The Firebase service-account file at ${path} is missing: ${missing.join(', ')}. ` +
        'This looks like the wrong file — google-services.json is the ANDROID ' +
        'config and is not a service account.',
    );
  }

  if (account.project_id !== projectId) {
    // Two names for one project is how staging pushes to production.
    throw new FirebaseConfigError(
      `The service-account file is for project "${String(account.project_id)}" but ` +
        `FIREBASE_PROJECT_ID is "${projectId}". A key from the wrong project ` +
        'would send every notification to the wrong app.',
    );
  }

  return {
    projectId,
    serviceAccount: {
      projectId,
      clientEmail: account.client_email as string,
      // Escaped newlines, because a key that HAS been through an env var at
      // some point in its life arrives with literal `\n`. Harmless when it has
      // not.
      privateKey: (account.private_key as string).replace(/\\n/g, '\n'),
    },
  };
}
