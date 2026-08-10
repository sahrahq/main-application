# Group G — notifications, split at the Firebase line

**Date:** 2026-08-09
**Why a split:** the Firebase project does not exist yet and the product owner
has to create it. Everything in G that needs a credential is stopped at a seam;
everything that does not is built.

The handover — which credential, which file, which env var, what must never be
committed — is a separate page so whoever sets Firebase up can open it on its
own: **`docs/decisions/2026-08-09-firebase-handover.md`**.

---

## 0. What already existed before G

NOTIFY-1 Stage 1, built during the venue-cancellation batch:

- `notifications` and `devices` tables.
- `NotificationsService.notify()` — writes the record, then attempts delivery,
  and **never throws**: the event that caused the notification must not fail
  because a push did.
- `PushDelivery` port + `LoggingPushDelivery` stub, which refuses to construct
  in production.
- `POST /devices`, `DELETE /devices`.
- One notification type: `reservation_cancelled_by_venue`, one caller.

Nothing read `read_at`. Nothing listed a notification. No diner could see one.

---

## 1. UNBLOCKED — built in this batch

### Server

| | |
|---|---|
| **G1** | `notifications.dedupe_key` + a unique partial index. "We already told them this" becomes a database fact rather than a code convention, which is what makes an at-least-once job safe to retry. |
| **G2** | `idx_notif_user_unread` under **doc 04's name**, partial on `WHERE read_at IS NULL`, and the exemption removed from `schema-invariants.e2e-spec.ts` **in the same commit** — per the instructions left in `prisma/migrations/20260802020000_notifications_stage_1/README.md`. |
| **G3** | `GET /notifications` — the in-app centre's list, newest first, with `unread_count`. |
| **G4** | `POST /notifications/read` — `{ids}` or all. The first thing in the system to write `read_at`. |
| **G5** | Five new notification types, for events that **already fire**: `reservation_confirmed`, `waitlist_offer`, `waitlist_offer_expired`, `reservation_reminder_24h`, `reservation_reminder_2h`. |
| **G6** | The waitlist **notify half** (C-3.6, doc 05 §5): `on slot_freed` → pick the top matching waiting entry `FOR UPDATE SKIP LOCKED` → `offered` → record the notification. Hooked into all three paths that free a table. |
| **G7** | The offer-expiry sweeper: a lapsed offer becomes `expired`, that diner is told, and the slot passes to the next in the queue. |
| **G8** | The 24h/2h reminder sweeper (C-3.9's record half), deduped by G1. |

### Client

| | |
|---|---|
| **G9** | The notifications centre, reached from the **bell row** the Account screen's reference (`ProfileScreen.jsx`) already draws. |
| **G10** | An unread indicator, so the row is worth tapping. |
| **G11** | Copy per type, EN + AR, owned by the client (doc 06 §7) — and a deep link per type. |
| **G12** | Golden ×4, accessibility ×4, 200%-text ×4, and drift tests tying the client's type list to the server's. |

---

## 2. BLOCKED on Firebase — not started

Everything here is **delivery**. The seam is one binding in
`notifications.module.ts`; nothing above `PushDelivery` changes when it lands.

- **`FcmPushDelivery implements PushDelivery`** — the adapter. Needs a
  service-account key.
- **`firebase_messaging` in `customer_app`** — acquiring a token at all.
- **`POST /devices` and `DELETE /devices` gaining their first caller.** Both
  endpoints are built, tested, and have never been called by anything: there is
  no token to send until FCM issues one. A capability nothing calls is
  indistinguishable from one that does not exist, and these two are currently
  in that state on purpose.
- **The permission prompt with context** — doc 11 §1: asked at the moment it
  makes sense ("so we can remind you before your reservation"), never on cold
  open.
- **Background and terminated-state handlers**, and tapping a push into the
  right screen.
- **`google-services.json`** (Android), **`GoogleService-Info.plist`** + an
  **APNs auth key** (iOS).
- **Anything that makes `sent_at` mean something.** Today every notification
  records `no_registered_device`, because that is the truth.

**WhatsApp is a second, separate block.** C-3.9 says "push + WhatsApp" and
C-4.7 lists four channels. WhatsApp needs a Business API provider and a
template approval; it is not Firebase and unblocking one does not unblock the
other.

---

## 3. NOT in G at all — named so nobody assumes it

### 3.1 The offer does not withhold the table

doc 05 §5 says the freed slot is held back from public availability during the
10-minute offer window, via a Redis `waitlist_hold` marker, "so the waiter's 10
minutes are real". **This batch does not do that, and the copy does not claim
it.**

Two reasons, and the second is the real one:

1. A Redis marker is a **second source of truth for whether a table is free**,
   which `EXCLUDE USING GIST on reservation_tables` already owns. This codebase
   has spent two batches removing exactly that shape.
2. The right implementation is for the offer to create a real `held`
   reservation — then the constraint withholds it, and the existing hold-expiry
   sweeper releases it, with no new mechanism at all. But that is **a booking
   write**, made by a background job, and CLAUDE.md rule 1 is explicit: nothing
   goes near reservation locking without its concurrency test first. That is
   its own proposal, not a corner of a notifications batch.

So today an offer is a **notification and a queue position**, not a claim on a
table. `offer_expires_at` means "after this we move to the next person", not
"this table is yours until then".

**And that is asserted, not just written here.** `waitlist-offer.e2e-spec.ts`
makes an offer and then checks the freed slot is **still on public
availability**. The day somebody implements withholding, that test fails and
they have to come and read this section — the same shape as the
`review_reports` "exactly one path mentions a report" assertion. A gap nobody
can trip over is a gap that gets forgotten.

### 3.2 The claim flow

doc 11 §4: tapping the offer lands in a pre-filled booking review. Requires
3.1, and requires push to exist so there is something to tap.

### 3.3 Granular per-type preferences (the second half of C-4.7)

C-4.7 is "notifications center **+ granular preferences** (push/SMS/WhatsApp/
email per event type)". The centre is built; the preferences are not.

Not for effort reasons. **A preference that suppresses a channel which does not
deliver is unfalsifiable** — you cannot tell a working "off" from a broken
"on", and neither can a test. Preferences gate delivery, and delivery is a
stub, so the whole feature would be four toggles over three channels that do
not exist and one that logs to stdout. It goes in when there is a channel to
switch off.

### 3.4 `review_invite` ("How was your visit?")

doc 11 §5 wants this pushed the morning after a `completed` reservation. Of the
six owner actions in doc 06 §4, **only `cancel` is built** — no reservation ever
reaches `completed` through the API, so the event does not exist. Same finding
already recorded in `review-eligibility.ts`.

### 3.5 The management app (R-4.3)

New booking, cancellation, review posted, waitlist activity — for the venue,
not the diner. `management_app` has no notification surface at all yet.

---

## 4. The honest state after this batch

A diner can open the notification centre and read every notification the system
has ever owed them. **They will not be told a new one arrived** unless they open
the app and look, because that is what push is for and push is not built.

Reminders in particular are worth naming: C-3.9 calls them "the single biggest
no-show reducer", and a reminder that reaches only an in-app centre reduces
no-shows by approximately nothing — nobody opens a notification centre the day
before dinner. What the sweeper buys is that the **records exist and are
correct** the day the adapter is bound, rather than the schedule being written
under time pressure afterwards.

See `docs/decisions/2026-08-09-notification-centre.md` for the design decisions
inside the built half.
