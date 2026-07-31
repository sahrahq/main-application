# 2026-07-31 — `refresh_tokens` and `otp_challenges` tables

**Status:** accepted, implemented in the init migration
**Affects:** `apps/api/prisma/schema.prisma`, auth module

## Context

`docs/blueprint/06-api-design.md` §2 specifies behaviour that needs persistent
state the schema doc does not define:

- *"Refresh via rotating refresh tokens (30 d, revocable, reuse-detection)"*
- *"reuse → revoke family, 401"*
- `/auth/verify-otp` with *"5 attempts → 429"*

`docs/blueprint/04-database-design.md` defines no table for either. Rotation
with family revocation cannot be implemented statelessly: detecting that an
already-rotated token was replayed requires remembering that it existed and
that it was superseded. Likewise, capping OTP attempts requires a counter that
survives across requests.

This is a gap in doc 04, not a disagreement with it — so per CLAUDE.md
("before deviating from the committed schema… stop and ask") it is logged here
rather than silently absorbed.

## Decision

Two tables, both keyed to `users` with `ON DELETE CASCADE`:

**`refresh_tokens`** — `token_hash` (SHA-256, `CHAR(64)`, unique), `family_id`,
`expires_at`, `revoked_at`, `replaced_by`, `user_agent`, `ip`.
Indexes: `idx_refresh_user`, `idx_refresh_family`, `idx_refresh_expiry`.

**`otp_challenges`** — `purpose` (`phone_verify | login | password_reset`),
`code_hash` (SHA-256), `expires_at`, `attempts`, `consumed_at`.
Indexes: `idx_otp_user_purpose`, `idx_otp_expiry`.

Both store **only a SHA-256 digest**, never the raw token or code. A dump of
either table cannot be replayed against the API — the usable secret exists only
on the client and, briefly, in the SMS.

`family_id` groups every token descended from one login. On presentation of a
token already marked revoked, the whole family is revoked: that pattern means
either an attacker replayed a stolen token or the legitimate client did, and
neither case should leave a working session.

## Alternatives rejected

- **Stateless JWT refresh tokens.** No server record means no revocation and no
  reuse detection — it contradicts doc 06 §2 outright.
- **Redis-only storage.** Refresh tokens live 30 days; a Redis flush would sign
  out every user on the platform. Redis is right for the OTP *rate limit*
  window, wrong as the system of record for sessions.
- **Reusing an existing table.** Nothing in doc 04 fits, and overloading
  `users` with token columns breaks the one-row-per-session requirement that
  multi-device revocation needs.

## Consequences

- Two tables exist that doc 04 does not describe. **Doc 04 should be amended**
  to include them so the blueprint stays the source of truth.
- Expired rows need periodic pruning (a BullMQ job, once Redis is available).
- A rotation bug now signs users out rather than silently granting access —
  the correct direction to fail.
