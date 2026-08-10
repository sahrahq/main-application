# Optional email at sign-up — decisions

**Date:** 2026-08-02 · **Status:** decided, building in five steps
**Product owner:** Geno · **Related:** AUTH-1, AUTH-3, IDEM-1, OPS-1

---

## The market judgement, first, because it will look like indecision otherwise

An **optional** email field is not a failure to decide. It is the decision.

> Resy and OpenTable require email at sign-up because email is the primary
> identity in the US and Europe. Delivery apps here take phone only, because in
> Egypt the phone **is** the identity. We serve both — an Egyptian in a hurry to
> grab a table, and a visiting tourist who arrives from the Resy world and finds
> it strange **not** to be asked. An optional field satisfies both: the Egyptian
> skips it with no friction, the tourist fills it because that's what he
> expects.
> — Geno, 2026-08-02

The next person to read the sign-up screen will be tempted in one of two
directions. **Making it required** copies Resy and costs bookings from the
larger half of the market. **Deleting it** copies the delivery apps and gives a
tourist an account with no contact channel he recognises. Both are a product
decision being made by whoever last touched the file. It is optional on
purpose.

The word "optional" is in the **label**, not the hint and not the help text,
because only the label is announced as part of the field's accessible name. A
diner using a screen reader must hear that it is optional at the same moment a
sighted diner reads it.

---

## Decision 1 — One screen, three fields

Phone (required), name (required), email (optional), all on the existing
`_PhoneStep`.

**Rejected: a two-step flow** — phone first, then name and email only if the
number turns out to be new. Cost: the screen would visibly branch on whether an
account exists, which is AUTH-3's enumeration oracle re-created in the UI. It is
also why there is no separate sign-up screen today. Learning the answer from the
server and then *showing* it is the same leak one step later.

**Investigated and rejected: moving the name field to the code step for
returning diners.** Same oracle — a name field that appears only for new
accounts answers "does this number have an account?". Independently blocked by
`RegisterDto.fullName` being required, so `register` cannot be called before the
name is collected.

**Accepted cost, stated plainly:** a returning diner sees two fields they do not
need. The name field already carries exactly this cost and has since the screen
was built; email makes it two instead of one. That is the price of not having an
enumeration oracle, and it is the right trade.

---

## Decision 2 — A returning diner's email is applied only AFTER verification

If a returning diner types an email, it is held in memory and written by
`PATCH /v1/auth/me` **after** the OTP succeeds and a session exists. Never as a
side effect of `request-otp`.

**Why:** writing an email onto a record identified only by a phone number means
anyone who knows a phone number can attach their address to someone else's
account.

If verification fails or is abandoned, the typed address is discarded silently.
No partial write.

**Rejected: dropping it, the way `fullName` is dropped today.** `request-otp`
takes only a phone, so a returning diner's typed name is already discarded. Cost
of extending that to email: the diner types an address, taps continue, and
nothing ever happens to it. Since `PATCH /v1/auth/me` has to exist for the
Account screen anyway, holding the value costs nothing extra.

---

## Decision 3 — Email is removed from the login identifier match — **DONE, step 1**

`AuthService.login` matched `phone OR email`. Any address on a record that also
carried a `passwordHash` was therefore a **second way in**.

Diners were safe only because the customer app happens to send no password at
registration — a property of one client, not a boundary anyone built. Collecting
an optional contact email is precisely what stops that accident holding.

> **`users.email` is a CONTACT field, not a credential. It identifies nobody and
> grants access to nothing.**

**Rejected: narrowing the branch to "accounts where email authentication is
intended".** Cost: no such concept exists in this system, so guarding a hole
would mean inventing one — a second thing to get wrong, and a flag somebody
would eventually set for a reason that made sense that day.

**Verified before removing:** every `login()` call in the repository passes a
phone. Nothing has ever logged in by email; the only trace was the `LoginDto`
description string. Owners and staff log in by phone, which is what they already
do.

Defence in depth: `LoginDto.identifier` now rejects anything that is not
phone-shaped, using the same expression as `RegisterDto.phone`. The field keeps
its name — renaming is a breaking contract change, and the name is not the
load-bearing part once an address cannot pass validation.

Guarded by `auth.e2e-spec.ts` → *"email is a contact field, not a credential"*,
which sets up the dangerous combination on purpose (real password **and** real
email on one row) and asserts that email login fails while phone login on the
same account still succeeds. Without that second assertion the test would pass
on a completely broken login.

---

## Decision 4 — Provider and DNS before the UI ships

A field that stores an address and sends nothing is the checkbox nobody honours.

**Provider: Resend.** 3,000 emails/month free, then $20/month for 50,000. At
five venues and a few hundred bookings a month the free tier covers it entirely.
Postmark ($15/month, 10k) is the upgrade if deliverability ever becomes a
problem. SES is cheapest at scale but needs a sandbox-exit request and its own
reputation management, which is not worth it yet.

**This is NOT blocked by company registration.** A personal account and a domain
are enough — unlike SMS, and unlike what an earlier version of the OTP delivery
comment claimed.

The delivery stub throws on construction when `NODE_ENV=production`, the same
guard `LoggingOtpDelivery` uses. Logging or discarding a real message in
production is the mistake that guard exists to make impossible.

---

## Decision 5 — The skip counter lives on the device

The post-booking prompt fires **at most twice across the account's lifetime**.
The Account row is always present, because tapping it is the diner's own choice
and not an ask.

**Rejected: a column on `users`.** Cost: a schema migration whose only job is
suppressing a prompt.

**Accepted cost:** a diner who changes phones or reinstalls is asked once more.
That is acceptable and is written down here so it is not later reported as a
bug.

Stored in `flutter_secure_storage` — not because a nag counter is a secret, but
because it is the only approved storage dependency (doc 08 §5) and adding
`shared_preferences` for two integers is not worth a new package.

---

## Decision 6 — Uniqueness applies only to VERIFIED addresses

While an address is unverified, `@unique` buys nothing and costs two things:
anyone can type your address and lock you out of using it, and the resulting
`email_exists` tells them the address is registered.

So: `email` loses `@unique` in the Prisma schema, and a **partial unique index
conditioned on `email_verified_at IS NOT NULL`** is created in raw SQL. Prisma
6.2.1 cannot express a partial index — there is no `where` on `@@unique` — so
the migration is hand-written and says why.

Safe to do: nothing in the repository calls `findUnique` on email.

`register`'s `email_exists` response becomes indistinguishable from success, and
**so does `PATCH /v1/auth/me`'s**. Same rule, both doors — a clash reachable with
a valid session is still an oracle.

### The correction that made this coherent

As first specified, Decision 6 was **jointly unsafe** with "sending is a real
behaviour", and the reasoning is worth keeping:

1. Nothing writes `emailVerifiedAt`. It has been in the schema since the start
   and is always null.
2. So a partial index conditioned on it would never apply to a single row.
   Uniqueness would have been **removed permanently, not deferred**.
3. And with no uniqueness and no verification, I could type your address on my
   account and **you** would receive **my** booking confirmations — venue, date,
   party size. Personal data delivered to an unverified third party under PDPL
   151/2020, and a harassment vector. Worse than the denial vector Decision 6
   was closing.

> "You are correct that Decision 6 and 'sending is real' are jointly unsafe…
> My error." — Geno, 2026-08-02

**The fix: a verification flow (step 3).** The first email to any new address is
a verification email. Booking confirmations flow only once `emailVerifiedAt` is
set. That makes the field real, makes the partial index meaningful, and means an
address that is not yours never receives your bookings.

### A verification link is not a credential

Redeeming a verification token sets `emailVerifiedAt` **and nothing else**. It
never signs anyone in, never issues a token pair, never elevates anything. A
link that arrives in an inbox is not proof of identity — it is proof that
somebody can read that inbox, which is exactly the one fact it is allowed to
record.

The token is single-use, time-limited, and compared in constant time. The redeem
endpoint answers **identically** for an expired token, an already-redeemed
token, and one that never existed.

`emailVerifiedAt` is the ONLY field any future Google or Apple account-linking
logic may read. A test fails if linking ever keys off an unverified address.

---

## Where the profile is read from

The Account screen reads `GET /v1/auth/me`, and the **whole** profile moves
there — not just email.

**Rejected: adding `email` to `Session`.** `Session` is a credential snapshot
written at sign-in and persisted to the keystore. An email added on the
confirmation screen minutes later would leave it stale. Reading only email from
`/auth/me` while name and phone come from `Session` gives one screen two sources
of truth that can disagree.

**Cost:** one request when the Account tab opens, and a loading state.
`SahraAsyncView` already provides both.

---

## Two invariants with tests attached

**The confirmation email is transactional.** It must never read or be gated on
`marketingOptIn`. Under PDPL 151/2020 the distinction between a transactional
message and a marketing one is the difference between legitimate processing and
needing consent, and the way that distinction erodes is one `if` that seemed
reasonable. Asserted by test.

**It rides the notifications module, not a parallel path.** Scoping found the
module is push-only — `notify()` → device lookup → `PushDelivery`, with no
channel concept — and that **no notification is emitted on booking confirmation
at all**. So step 2 generalises the module to channels and adds
`reservation_confirmed` as the first confirmation notification. Push
confirmations come nearly free with it.

---

## Rate limiting — two different risks, two different shapes

Added 2026-08-06, correcting a design that treated both as the same kind of
threat.

**Requesting another code is not an attack on the account.** It means the first
one did not arrive — weak signal, delayed SMS, a network switch on the metro. A
real diner does this often, and its only cost to us is money.

**Entering a wrong code IS the takeover path.**

Treating them alike meant a diner with a bad connection hit a lockout built for
an attacker.

### Wrong-code attempts — unchanged

Strict counter, hard 15-minute lock, per-account across channels. The lock key
outlives the challenge so a new send cannot reset it (doc 11 flow 1). Nothing
here softens.

### Resends — backoff, not a wall

A fixed budget ending in a lockout is replaced by increasing backoff: first
resend immediate, then ~30s, 60s, 2m, 4m, capped. A real diner waits thirty
seconds and continues; an abuser throttles themselves into uselessness.

An absolute per-account-per-hour ceiling stays, so SMS spend cannot run away —
set high enough that a diner on a bad connection never reaches it.

Keying is unchanged: per-`userId` **and** per-phone. The per-user key is what
makes the budget per-ACCOUNT rather than per-channel, so adding email as a
second OTP channel (step 6) cannot double an attacker's guessing budget. The
per-phone key stays alongside it because it also protects a number across
different account rows, which the account-squatting path relies on.

### The wait must be specific, not generic

The response carries the remaining seconds and the client renders a **live
countdown on the button**, in both locales.

> "Wait 27 seconds" and "you are locked out" are the same fact and completely
> different products.

Latin figures in Arabic (see DESIGN-RULES), and both locales captured in the
walk-through.

### The lockout design assumes a human escape path

Geno is adding a support contact before launch. **The lockout is only humane
because someone can be reached when it goes wrong.** Recorded here so the
assumption is visible if it ever stops being true — a hard lock with no human
behind it is a different product decision from the one made here.

## The global send ceiling is a wallet fuse, not a capacity plan

`request-otp` looks nothing up, which is what closes AUTH-3 — and it means
anyone can cause an SMS to any number. Per-phone (3/10min) caps harassment of
one person; per-IP (10/10min) caps one source. **Neither caps the bill.**

So there is a third limiter: a global daily count of deliveries across all
phones and all IPs, from `OTP_GLOBAL_DAILY_SEND_LIMIT`.

**Sized ABOVE expected peak, deliberately.** It fails closed, so a tripped
ceiling is a full signup outage — which means it must sit where normal growth
never reaches it and a nuisance attacker has to spend real effort. At pilot
scale (five venues, a few hundred bookings a month) real traffic is a few
hundred sends a day including resends; the development default of 10,000 sits
20–50× above that. It is not a forecast of capacity and must not be tuned down
toward actual usage.

**Production has no default and fails at boot when unset**, on the
`TRUST_PROXY_HOPS` precedent. A fuse with no rating is not a fuse.

**Fails closed, with `otp_sending_unavailable` (503).** The alternative —
serve a challenge and quietly not deliver — is the decoy pattern wearing a
different hat: the diner is told a code was sent, waits, retries, and contacts
support about a phone they think is broken, while only the logs know why. An
honest outage beats a silent lie. It logs at `error` with a distinct
`[OTP GLOBAL SEND CEILING REACHED]` marker so a tripped fuse is never a silent
outage.

**Residual, accepted for now:** an attacker with many IPs can still burn up to
the daily ceiling. No per-IP hardening, reputation or adaptive limiting is
built. The ceiling bounds the loss; it does not prevent it.

## Order of work

Each step lands green before the next starts. Stop and report after 1 and 3.

1. **Close the login email-identifier hole.** Smallest, most dangerous,
   independent of everything else. ← **done**
2. **Channels + `reservation_confirmed` + per-channel delivery state**, with the
   delivery stub throwing under `NODE_ENV=production`.
3. **The verification flow:** token table, redeem endpoint, sweeper, and the
   rule that confirmations send only to a verified address.
4. **The optional email field** on `_PhoneStep`, `PATCH /v1/auth/me`, and the
   Account screen reading `/auth/me`.
5. **The post-booking ask** on the confirmation screen, with the device-local
   skip counter.
6. **Email as a second OTP DELIVERY CHANNEL** — see below. Not in this batch,
   but step 3 is shaped to accommodate it.

---

## Step 6 — email as a second OTP channel (later, and why step 3 must anticipate it)

The goal is to avoid paying for an SMS on every re-login. **No diner credential
is being introduced.** The credential remains "proves control of a channel we
verified"; the channel is simply email instead of SMS. The same six-digit code,
the same flow, byte-identical after delivery.

This does not contradict Decision 3. Decision 3 removes email from the
**password-login identifier match**, and it stays removed.

Load-bearing constraints:

- **(a)** Email OTP only when `emailVerifiedAt` is set. An unverified address
  that could originate a sign-in is **full account takeover**, not merely the
  data leak that forced the Decision 6 correction. This is why step 3 lands
  first, and it raises the stakes on step 3.
- **(b)** Phone stays mandatory and verified at sign-up, and stays the account's
  anchor. Venues call diners; a reservation without a reachable number is not a
  reservation. A diner with no email must never be worse off — a meaningful
  share of Egyptian diners have no email they actually read.
- **(c)** Because of (b), a diner signing in by email indefinitely can drift into
  holding a phone number that is no longer theirs while we and the venue both
  believe it is current. **Not built now**, but the step 3 token table is
  designed to carry a channel and a target so the same mechanism can later
  re-confirm a phone number. Logged as a new entry in the open-P0-gaps doc.
- **(d)** Email OTP shares the existing code generation, hashing, expiry,
  attempt-limiting, lockout and `OtpPurpose` discipline. No parallel
  implementation.
- **(e)** A sign-in via the email channel emits a notification to the account,
  through step 2's channel work. Free, and it makes a wrong sign-in visible
  early.
- **(f)** Rate limits are **per-account across both channels**, never
  per-channel, or adding email doubles an attacker's guessing budget on one
  account. Asserted by a test that exhausts the phone budget and then confirms
  the email channel is refused too.
- **(g)** An exhausted or slow SMS path should **offer the email channel as an
  alternative rather than a dead end** — but only for an account with
  `emailVerifiedAt` set, and it must not reveal whether an email is on file for
  an account that is not signed in. Designed here rather than bolted on later:
  the offer has to be part of the same indistinguishable response, which means
  the escape hatch cannot be a branch the caller can observe. Not built now.
