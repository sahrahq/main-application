# Admin impersonation is out of scope

**Date:** 2026-08-09
**Decided by:** the product owner, unprompted, on reading the admin-surface estimate
**Status:** removed from A-1. Not deferred, not behind a flag, not scheduled.

## What was removed

`docs/blueprint/02-functional-requirements.md` A-1 read:

> User management: search, view, suspend/ban, role assignment, **impersonate-for-support (audited)**

The last clause is gone. A-1 is now user management without the ability to
become a user.

## Why

In the product owner's words:

> It is the single highest-blast-radius capability in the product, it exists to
> make support easier for a support team that does not exist yet, and every
> account it can enter is a real diner's. […] I would rather answer a support
> email by hand.

Three things in that worth keeping separate, because they are independent
arguments and any one of them would be sufficient:

1. **Blast radius.** An impersonation endpoint is, by construction, a
   credential-issuing endpoint that skips the credential. Every protection the
   auth system has — OTP possession, rate limits, refresh rotation, the replay
   grace window — exists to establish that the person holding a session is the
   person who owns the account. Impersonation is a supported path around all of
   it. The auth surface currently has exactly one way in, and that is worth
   more than the convenience.

2. **It serves a team that does not exist.** A-10 (support dashboard) is P1 and
   unbuilt; there are no support staff. Building the most dangerous capability
   in the admin surface first, for nobody, is how it ends up in production
   untested and unwatched.

3. **The accounts are real people's.** Not test data, not tenant records. A
   diner's booking history, phone number, and saved places.

## What we do instead

Answer support by hand, from the data an admin can already see: the user
record, their reservations, and the audit log. If that turns out not to be
enough to resolve a real ticket, that is the evidence that would reopen this —
a specific ticket that could not be answered, not a general sense that it would
be handy.

## If it is ever revisited

It does not come back as a line item in a batch. It needs, as conditions and
not as suggestions:

- **Its own decision doc**, superseding this one, naming what changed.
- **Its own audit trail** — every impersonated session recorded with the admin,
  the target, the reason, and the duration, in `audit_logs`, written before the
  session is issued rather than after.
- **Consent or notification for the account being entered.** The diner finds
  out. Either they approve it in advance, or they are told it happened.
- A **scoped, short-lived, read-only** session by default. An impersonated
  session that can make a booking or change a phone number is a different and
  larger decision again.

None of that is designed here, deliberately. Designing it now is the first step
toward building it.

## Consequence for the estimate

The admin surface was estimated at **6–9 batches**, with impersonation called
out as deserving a batch and a decision doc of its own. That estimate stands at
**6–9 minus roughly one** — call it **5–8** — with the caveat that the
impersonation batch was never the uncertain part of the range.
