# Firebase handover — exactly what is needed, and from whom

**Date:** 2026-08-09
**Blocks:** NOTIFY-1 Stage 2 (push delivery), C-3.9 reminders reaching anybody,
C-3.6's waitlist offer reaching anybody, and the second half of C-4.7.
**Does not block:** anything already built. See
`docs/decisions/2026-08-09-group-g-split.md`.

**Standing rule, restated because it is the reason this page exists:** no
Firebase work starts until the product owner confirms the project exists and
the credentials are in place.

---

## 1. What we are asking Firebase for, and what we are not

doc 08 §Option 5 is explicit: Firebase is a **client-services toolbox**, never
the data platform. For this batch we need exactly one of its services.

| | |
|---|---|
| **Cloud Messaging (FCM)** | **Yes.** The only free, reliable, cross-platform push service. |
| Firestore | **No.** Rejected in doc 08 §Option 1 — no range-overlap constraints, which is the one thing the reservation engine cannot do without. |
| Firebase Auth | **No.** We issue our own JWTs. A second identity provider is a second source of truth for who somebody is. |
| Analytics / Crashlytics / Remote Config | Later, and separately. They are free and useful, and none of them is in Group G. |

**Nothing in the app reads from Firebase.** It is a one-way outbound channel:
we hand FCM a token and a message. If Firebase disappeared, every notification
would still be recorded and the in-app centre would still show it.

---

## 2. What we need from you — the whole list

### 2.1 A Firebase project

Console → **Add project**. Name it so the environment is unmistakable, e.g.
`sahra-prod`. **Disable Google Analytics for the project** at creation unless
you want it — it is a separate consent and data-processing question, and
turning it on later is one click while turning it off is not.

Then add **two apps** inside it:

| Platform | Bundle / package id | Produces |
|---|---|---|
| Android | `app.sahra.customer` | `google-services.json` |
| iOS | `app.sahra.customer` | `GoogleService-Info.plist` |

> Confirm those ids before creating the apps. They are baked into the config
> files, and changing an application id after release means a new listing.

### 2.2 A service-account key (server → FCM)

Console → **Project settings → Service accounts → Generate new private key**.
That downloads a JSON file **once**. There is no way to retrieve it again; if
it is lost, revoke it and generate another.

### 2.3 An APNs auth key (iOS only)

Apple Developer → **Certificates, Identifiers & Profiles → Keys → +**, enable
**Apple Push Notifications service (APNs)**, download the `.p8`.

Upload it in Firebase Console → **Project settings → Cloud Messaging → APNs
Authentication Key**, with the **Key ID** and your **Team ID**.

> **Without this step iOS push silently never arrives.** Firebase accepts the
> token, the send reports success, and no device rings — the exact failure
> `LoggingPushDelivery` refuses to run in production to avoid, arriving through
> a different door. Android will be working, so "push works" will look true.

---

## 3. Where each credential goes

### 3.1 The server

Two variables, **already present and empty** in `apps/api/.env.example`:

```
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_JSON=
```

- `FIREBASE_PROJECT_ID` — the project id string, e.g. `sahra-prod`.
- `FIREBASE_SERVICE_ACCOUNT_JSON` — the **whole contents** of the service-account
  JSON, on one line.

**Why the JSON inline rather than a file path.** The app runs in a container;
a path means a mounted secret volume, which is a second deployment concept for
one credential. Every other secret in this system is an env var, and the boot
gate in `apps/api/src/shared/config/secrets.validation.ts` can only check what
it can read.

Put the real values in `apps/api/.env` for local work. **`.env` is gitignored;
`.env.example` is committed and must stay empty.**

In production these are injected by the platform's secret store, never from a
file — `secrets.validation.ts` already **refuses to boot in production if a
`.env` file is present**, and that rule covers these two the moment they matter.

### 3.2 The Android app

`apps/customer_app/android/app/google-services.json`

### 3.3 The iOS app

`apps/customer_app/ios/Runner/GoogleService-Info.plist`

---

## 4. WHAT MUST NEVER BE COMMITTED

| File / value | Status |
|---|---|
| The service-account JSON, in any form | **Never.** It can send push to every user of the project and is not scoped to one app. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` with a real value | **Never.** Only the empty key in `.env.example`. |
| `apps/api/.env` | **Never.** Already ignored. |
| The APNs `.p8` | **Never.** Already ignored by the `*.pem` / `*.key` rules — but a `.p8` is neither, so **do not keep it in the repo at all.** Upload it to Firebase and store it in the password manager. |
| `google-services.json` | **Never.** Already ignored by name. |
| `GoogleService-Info.plist` | **Never.** Already ignored by name. |

`.gitignore` already names `google-services.json`, `GoogleService-Info.plist`,
`.env`, `.env.*`, `*.pem`, `*.key`. **The `.p8` is the one gap** — it is not
matched by any existing rule, so keep it out of the working tree entirely.

**A note on the two config files.** `google-services.json` and
`GoogleService-Info.plist` contain an API key that Google itself documents as
not secret; they are ignored here anyway, because "which of our keys is
harmless" is not a judgement anyone should have to make correctly under time
pressure, and because they differ per environment.

**If a service-account key is ever committed, rotating it is the only fix.**
Deleting the commit does not help: it is in every clone and every fork.
Console → Service accounts → delete the key → generate a new one.

---

## 5. What we build once you confirm

In order, and none of it before then:

1. **`FcmPushDelivery implements PushDelivery`** — the adapter. Bound in
   `notifications.module.ts` in place of `LoggingPushDelivery`, which is a
   one-line change because that binding is the entire integration surface.
2. **Token-rot handling.** FCM answers `UNREGISTERED` / `INVALID_ARGUMENT` for
   a dead token. `devices.revoked_at` already exists for it; the adapter sets
   it, so a reinstalled phone stops being pushed to instead of failing forever.
3. **`firebase_messaging` in `customer_app`** — acquire a token, `POST /devices`,
   `DELETE /devices` on sign-out. Both endpoints are built and tested and have
   **never been called by anything**, because there is no token to send.
4. **The permission prompt, with context** (doc 11 §1): asked at the moment it
   makes sense — "so we can remind you before your reservation" — never on cold
   open. Asking cold gets refused, and iOS gives you one chance.
5. **Background and terminated-state handlers**, and tapping a push into the
   right screen. The payload already carries `reservation_id`; the centre's
   renderer already routes on it.
6. **Delete the "we can't alert your phone yet" note** from the notification
   centre, in the same commit as step 3. It is `notificationsNoPushNote` in
   both ARBs.

---

## 6. How we will know it actually worked

Not "the code compiles" and not "FCM returned 200".

- `notifications.delivery_error` stops reading **`no_registered_device`** for
  accounts that have opened the app. Today that is **every notification in the
  system**, which is the honest record of having no channel.
- `notifications.sent_at` becomes non-null.
- **A real Android handset and a real iPhone each ring**, with the app closed,
  in Arabic and in English — the device locale decides, not the account's, and
  that split is already implemented in `notification-copy.ts` and untested
  against a real lock screen.
- The iOS one is the one to check hardest. See §2.3.
