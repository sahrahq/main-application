# The notification centre, the reminders, and the waitlist's notify half

**Date:** 2026-08-09
**Covers:** the unblocked half of Group G. What is blocked and why:
`2026-08-09-group-g-split.md`. What we need to unblock it:
`2026-08-09-firebase-handover.md`.

---

## 1. Nobody is told anything, and the app says so

> **SUPERSEDED 2026-08-10 for Android.** The adapter is bound, the client
> registers a token, and an Android handset rings. The notice described below
> was deleted in that commit — but **not** at the moment the adapter was bound:
> push reaches nobody until a handset registers a token, and nothing in the
> client had ever called `POST /devices`. The client half went in first.
>
> **iOS is still unreachable** and is loud about it. `2026-08-10-fcm-stage-2.md`.
>
> The section below is left as written because the reasoning is why the notice
> existed at all, and why it could not be deleted a step early.

Push does not exist. Every notification the system has ever produced records
`delivery_error = 'no_registered_device'`, because nothing acquires a token and
nothing can until the Firebase project exists.

So a diner learns their table was cancelled **only by opening the app and
tapping a bell**. That is a bad product, and the honest response to shipping it
is to say so on the screen:

> "We can't alert your phone yet, so check back here."

It sits at the top of the centre, above the list. A diner who is never alerted
and is never told they will not be alerted concludes the app is broken the
first time they miss something — and they are right to. **The line is deleted
in the same commit that binds the FCM adapter**; the handover doc names it as a
step and gives the ARB key.

This is the `waitlist_offer` copy argument again, one level up: say what the
thing does, not what we wish it did.

---

## 2. Three deviations from the docs, all forced by the same missing feature

doc 05 §5 and doc 11 §4 describe the waitlist offer as **exclusive** — the
freed slot is withheld for ten minutes so "the waiter's 10 minutes are real".
It is not withheld (§3.1 of the split doc: that is a booking write from a
background job, and CLAUDE.md rule 1 keeps it out of a notifications batch).

Everything else follows from that, and each piece had to be re-derived rather
than copied:

| doc says | we do | because |
|---|---|---|
| "Table available — **claim in 10 min**" | "A table opened up… **first come, first served**" | Sending a diner to a slot somebody else already took is worse than never telling them — they made the journey for it. |
| Lapsed offer → `status = 'expired'` | Lapsed offer → **`status = 'waiting'`** | `expired` is right for an offer you DECLINED. Losing a race for a table nobody held is not declining, and dropping someone from a queue for it would punish them for our missing feature. |
| On expiry, `goto loop` — offer the slot to the next person | **No re-offer chain** | Ten minutes later we do not know whether that table is still free, because we never held it. Telling a second diner about a table that is probably gone is the first defect with an extra step. The next FREED table finds the next waiter. |

All three revert when withholding lands, and `waitlist-offer.e2e-spec.ts` is
what will force the conversation: it asserts the freed slot is **still on public
availability** after an offer. That test fails the day somebody implements
withholding, and they have to come and read this table.

---

## 3. `dedupe_key` — "we already told them this", as a database fact

Group G introduced the first notifications emitted by a **sweeper** rather than
by a request. Sweepers are at-least-once by construction: overlapping ticks, two
API instances in a rolling deploy, a slow sweep running into the next one.

A diner told three times that their table is tomorrow learns to ignore us.

The alternative was `SELECT … WHERE NOT EXISTS` before each insert, which is
check-then-act across two statements — two workers both find nothing and both
write. So it is a **partial UNIQUE index** on `notifications (dedupe_key)
WHERE dedupe_key IS NOT NULL`, and `notify()` treats a 23505 on that index as
"already told them" rather than as an error.

Partial, so ordinary event-driven notifications are unaffected: a venue
cancelling two of a diner's tables in one evening must produce two. That
property is asserted directly — a total unique index on a nullable column
behaves differently per database, and if this one ever became total, every
event-driven notification after the first would be silently dropped for the
whole platform.

### 3.1 And the index is not the only mechanism, deliberately

The reminder sweeper ALSO filters already-notified reservations in SQL, with a
`NOT EXISTS` on the same key. That looks redundant and is not:

- The **index is the guarantee** — it is what makes two workers safe.
- The **predicate is what keeps the ordinary path clean.** The 24h window is an
  hour wide and the sweeper ticks every minute, so without it every booking
  would be re-selected ~60 times, and each attempt would raise a unique
  violation that **Prisma logs as an ERROR**. An operator would see sixty
  failures an hour describing a system working exactly as designed, which is
  how real failures stop being visible.

Same relationship as layers 2 and 3 in the booking engine: the re-check makes
the common path clean, the constraint makes it correct. Found by running the
tests and reading the log, not by design.

---

## 4. Reminders exist, and on their own they are worth nothing

C-3.9 is P0 and calls reminders "the single biggest no-show reducer". That is
true of a reminder that reaches a lock screen. **A reminder that reaches only an
in-app centre reduces no-shows by approximately zero** — nobody opens a
notification centre the day before dinner.

Built anyway, for one reason: on the day an adapter is bound, the schedule is
already correct and already tested, rather than being written under the pressure
of a channel that has suddenly started working. It should not be reported as
"reminders are done".

**A sweeper, not a delayed job per reservation.** Hold expiry schedules a BullMQ
job at booking time because a hold's deadline is fixed when it is created. A
reminder's is not: C-3.4 lets a diner move a booking, and a job scheduled for
the old `starts_at` fires at the wrong hour — or fires for a booking since
cancelled. A sweeper reads the current row every time.

**The window is `[now+23h, now+24h)`, not `<= now+24h`.** The second form fires
"your table is tomorrow" the instant somebody books a table for tonight. The
cost is stated rather than hidden: an outage longer than the window silently
skips that reminder. The alternative — two more columns on `reservations`, the
hottest table in the system — is not worth recovering a reminder for an outage
during which nothing else worked either.

---

## 5. Bidi: the third tool, and why two were not enough

`ltrRun` (U+2066) is for a run we KNOW is Latin. `contentDirection` is for a
paragraph that is ENTIRELY somebody else's. Neither covers the commonest case in
a notification: **somebody else's words inside a sentence of ours.**

> `"{venue} ألغى حجزك"` — the venue names itself, in either script.

`ltrRun` would lay «ليالي لاونج» out backwards. `contentDirection` would flip
the whole line to left-to-right because a venue happens to be called "Zooba".

So `isolate()` (U+2068 FIRST STRONG ISOLATE) was added to `sahra_bidi.dart`: the
run picks its own direction, and its punctuation cannot escape into a sentence
somebody else wrote — the `.Nour H` defect the reviews list already shipped once.

**Found by looking at the Arabic golden**, not by any assertion. The first
version passed `contentDirection(body)` on the whole line and the Arabic
reminder rendered starting at the wrong edge.

And a fourth case turned up in the same picture: the **cancellation reason** is a
whole clause the venue typed. Interpolated into an Arabic line it wraps
mid-phrase — «… — A burst pipe in the» ends one line and «kitchen» begins the
next at the opposite edge. Correct per Unicode, unreadable in practice. It is
its own line now, with its own direction, which is what `contentDirection` is
for.

---

## 6. What the guards caught that looking would not have

Recorded because the ratio matters: five of the eight defects in this batch were
found by an existing guard rather than by review.

1. **`list2()`** — the generated Dart client. The numeric-suffix ban from Group
   B, firing for the second time. `NotificationsController.list` collided with
   another controller's `list`, and a method called `list2` is a name nobody can
   look up. Renamed to `listNotifications`.
2. **`Map<String, dynamic> data`** — the client-drift test refuses untyped maps
   and has exactly one named exemption. Rather than add a second, `data` was
   declared `additionalProperties: {type: string}`, which is TRUE (the server
   types it `Record<string, string>`) and generates `Map<String, String>`.
3. **A label literal** — `label: '${copy.title}. ${copy.body}'` in a `Semantics`.
   Refused by `source_rules_test`. Moving the separator to the ARB was then
   refused by `arb_test` as an untranslated string. Both were right: the answer
   was `MergeSemantics`, so the screen reader announces what is on screen and
   there is no third copy of the sentence to keep in step.
4. **A dead ARB key** — `notifCancelledReason` stopped being used when the reason
   moved to its own line. Caught by the bidi scan's "at-risk copy that nothing
   uses" check.
5. **Hardcoded dates** — five `'2026-08-05'` literals in a new test file, caught
   by `fixture_dates_test`. A pinned date drifts into the past and silently
   changes what its test covers.

And two that only looking found: the **icon fallback** (§7) and the **bidi
direction** (§5).

---

## 7. `x-circle` and `info` do not exist

`SahraIcon` falls back to `Icons.help_outline` for a name it does not know. Both
invented names rendered as **a question mark in a circle** — beside a
cancellation, that reads "we don't know what happened".

Found by enlarging an Arabic golden. Now a test: every kind's icon is checked
against `SahraIcon.drawnIcons + fallbackIcons`, so the next invented name fails
in CI rather than in a picture somebody has to notice.

The no-push note lost its icon entirely rather than gaining one. Adding a glyph
to the design system to decorate a temporary notice is not a trade worth making.

---

## 8. The contrast check, third occurrence — and this time it explained itself

The product owner asked for the `textContrastGuideline` analysis to be moved to
the point of failure. It was, and it immediately paid for itself twice.

**First, it corrected the claim.** The caveat as first drafted said "on our
surfaces, no colour can pass". Asserting it (`palette_contrast_test.dart`)
showed that is true of the LIGHT surfaces — ceiling 3.85–3.93 — and **false of
the night surfaces**, where near-white ink reaches 4.72–5.16 at the same 50%
edge. Written down unasserted, that over-generalisation would have taught the
next reader to dismiss a real dark-theme failure as an artefact.

**Second, it diagnosed the third occurrence.** Adding the Notifications row to
the Account screen moved the sampled pixel, and the check began failing at
**3.02:1 in Arabic only**. The pair is `textBody` on `surfacePage`, which
measures **17.54:1** — the strongest text combination in the entire palette. No
colour change was possible, and none was needed: the failure was reporting that
Reem Kufi at 16pt regular has thin strokes.

The remedy the caveat itself prescribes is more ink, and that is what was done —
`w500` on account-row labels, which is a defensible weight for a navigation
label on its own terms. **Not** a moved layout block, which is what the first
occurrence did and the reason there was a second.

---

## 9. And one found by running the suite twice

**The live API suite was poisoning itself.** It books against the seeded venue
on a shared dev database and never cancelled what it booked. Layali has six
tables; each run left two or three confirmed bookings for tomorrow. On the third
run the venue was full and two tests failed with "no availability" — a failure
that says nothing about the code and everything about the last run.

Worse than flaky, because it is **monotonic**: passes today, passes tomorrow,
fails permanently. The natural reading is "something broke".

Not a Group G defect — the leak has been there since the live suite was written.
But "8 live tests green" was a weaker claim than it looked, because it depended
on how recently they had last been run. Two fixes:

- a `tearDownAll` that cancels every reservation the run created, **through the
  real cancel endpoint** — a suite that reaches around its own API to tidy up
  can pass while that API is broken;
- `firstBookable()`, which walks forward up to seven days instead of assuming
  tomorrow. A shared database means a full venue is an ordinary state, and a
  week of no availability anywhere still fails, loudly, with the dates it tried.

Verified by running the suite three times in a row. **The twelve bookings
already accumulated could not be cleaned up** — they belong to accounts this run
has no token for, and the direct database write was refused. They are harmless
now that the suite walks forward, but they are still sitting on tomorrow at
Layali and somebody with database access may want to cancel them.
