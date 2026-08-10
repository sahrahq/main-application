# Firebase handover — exactly what is needed, and from whom

> ## DONE 2026-08-10 — Android. iOS still blocked.
>
> Project **`sahra-4881d`** exists, Analytics off, **Android app only**. The
> service-account key lives outside the repo and is referenced by PATH. The FCM
> adapter is bound, the client registers a token after a diner's first booking,
> and `DELETE /devices` is finally called on sign-out.
>
> **What is still not true:** there is no Apple Developer account, so no APNs
> key and no `GoogleService-Info.plist`. Every iOS send is **refused before the
> network** and recorded as `ios_not_configured`; `GET /health` answers **503**
> and names it; the boot log says it twice. Nothing about the iOS gap is silent.
>
> Two changes to what this page originally asked for, both made before anything
> read them — see 3.1 and 2.3.


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

### 2.3 An APNs auth key (iOS only) — NOT DONE, and deliberately loud

> **Status 2026-08-10:** no Apple Developer account, so this step has not
> happened. Rather than leave it as a gap somebody has to remember, the system
> refuses iOS sends and reports itself degraded. When the key is uploaded, set
> `FIREBASE_IOS_CONFIGURED=1` and iOS starts working with no code change —
> asserted in `fcm-push.delivery.spec.ts`.
>
> The flag is manual because **FCM offers no way to ask whether an APNs key
> exists.** Inferring it from a send failure means discovering it from a diner's
> missed booking.

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

### 3.1 The server — A PATH, changed from the inline JSON this page first asked for

```
FIREBASE_PROJECT_ID=sahra-4881d
FIREBASE_SERVICE_ACCOUNT_FILE=<absolute path to the service-account JSON>
FIREBASE_IOS_CONFIGURED=
```

**This page originally specified `FIREBASE_SERVICE_ACCOUNT_JSON`, the whole key
pasted inline. That was wrong, and it was changed before anything read it.** The
reasoning it gave — "a path means a mounted secret volume, a second deployment
concept" — weighed a deployment convenience against a credential, and lost:

1. **dotenv puts every `.env` value into `process.env`.** One
   `console.log(process.env)` — a debug session, a crash reporter, a "why is my
   config wrong" moment — prints the private key. A path is a short, boring
   string that can appear in a log harmlessly.
2. **A file you hand-edit is a file you paste** into a diff, a screenshot, a
   chat message. With a path the key never has to be opened at all.
3. **The key stays outside the repository**, where no `git add -A` can reach it.

The cost is real and accepted: production mounts the file rather than injecting
a variable. Every platform doc 10 names supports that, and it is the same shape
as `GOOGLE_APPLICATION_CREDENTIALS`, which the Google SDKs have always read as a
path.

Full reasoning, and the leak the loader is written to prevent:
`apps/api/src/shared/config/firebase.config.ts`.

### 3.2 The Android app

`apps/customer_app/android/app/google-services.json`

### 3.3 The iOS app

`apps/customer_app/ios/Runner/GoogleService-Info.plist`

---

## 4. WHAT MUST NEVER BE COMMITTED

| File / value | Status | Verified by `git check-ignore` on 2026-08-10 |
|---|---|---|
| The service-account JSON, in any form | **Never.** It can push to every user of the project and is not scoped to one app. | ignored — `*-firebase-adminsdk-*.json`, `serviceAccountKey.json`, `secrets/` |
| `apps/api/.env` | **Never.** | ignored |
| The APNs `.p8` | **Never.** | ignored — `*.p8`, **added 2026-08-10** |
| Anything under a `secrets/` directory | **Never.** | ignored — `secrets/`, `**/secrets/`, **added 2026-08-10** |
| `google-services.json` | **Never.** | ignored |
| `GoogleService-Info.plist` | **Never.** | ignored |

**Three of those six were NOT ignored** when this page first claimed they were.
The original §4 said "`.gitignore` already names …" and then listed the rules
from memory; asking `git check-ignore` instead showed that a `.p8`, a
`secrets/` path, and a service-account JSON under its own download filename
would all have been committed by the next `git add -A`. The rules were added
before any credential was placed.

The lesson is the same one this codebase keeps relearning: **reading the
patterns is not checking.** `git check-ignore -q <path>` is the only authority,
and it is now what §4 reports.

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
