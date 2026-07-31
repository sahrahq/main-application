# 2026-07-31 — Auth token storage

**Status:** accepted (revised 2026-08-01), implemented
**Affects:** `apps/api/prisma/schema.prisma`, `apps/api/src/modules/auth/`

## Context

`docs/blueprint/06-api-design.md` §2 and `09-security-and-scalability.md` §1.1
specify auth behaviour that needs state:

- *"Access JWT 15 min (RS256, kid-rotated keys) / refresh token 30 d, rotating
  with reuse detection — a replayed old refresh token revokes the whole token
  family"*
- *"Device binding: refresh tokens tied to device records; 'log out all
  devices' supported"*
- *"phone OTP hashed in Redis, 5-min TTL, 5 attempts, per-phone and per-IP
  rate limits"*

`04-database-design.md` defines no table for refresh tokens.

## Decision

### 1. `refresh_tokens` table — ADDED

Reuse detection is not implementable statelessly: recognising that an
already-rotated token was replayed requires remembering that it existed and
was superseded. A 30-day lifetime rules out Redis as the system of record — a
single flush would sign out every user on the platform.

Columns: `token_hash` (SHA-256, unique), `family_id`, `expires_at`,
`revoked_at`, `replaced_by`, `user_agent`, `ip`.
Indexes: `idx_refresh_user`, `idx_refresh_family`, `idx_refresh_expiry`.

**Only the SHA-256 digest is stored.** A dump of this table cannot be replayed
against the API. Asserted by a test that greps the column for the raw token.

`family_id` groups every token descended from one login. Presenting a revoked
token revokes the entire family: the legitimate client and a thief cannot both
hold a live token after a rotation, and we cannot tell which is asking — so
both are ended. The victim re-authenticates; the attacker gets nothing.

### 2. `otp_challenges` table — REJECTED

**This was proposed and then withdrawn.** The first draft of this record added
an `otp_challenges` table. Re-reading doc 09 §1.1 showed the blueprint had
already decided the question: OTP lives in **Redis**, 5-minute TTL.

Redis is right here for reasons beyond convention:
- A 5-minute secret in Postgres accumulates dead rows and needs a cleanup job
  to delete what Redis discards for free.
- The per-phone and per-IP limits that block SMS-pumping fraud are sliding
  windows — native in Redis, awkward in SQL.

The table was created empty, never written to, and dropped in
`20260801010000_drop_otp_challenges`. **OTP endpoints are therefore blocked on
Redis** (Docker/WSL2), and are not part of the first auth cut.

### 3. HS256 instead of RS256 — DEVIATION, revisit before production

Doc 09 §1.1 says RS256 with kid-rotated keys. Shipped as **HS256**.

RS256 exists so that a party which must *verify* a token need not hold the key
that *signs* it. SAHRA is a modular monolith (doc 03): exactly one service
issues and verifies, so there is no second party and asymmetry buys nothing
today. HS256 avoids keypair generation, JWKS hosting and rotation machinery
that would have no consumer.

**Revisit when any of these becomes true** — at which point RS256 + a JWKS
endpoint is required, and the access-token TTL means migration costs one
15-minute window:
- a second service needs to verify tokens without the signing secret
- tokens must be verified outside our infrastructure
- the monolith is split (doc 09's scaling stages)

## Alternatives rejected

- **Stateless JWT refresh tokens.** No revocation, no reuse detection —
  contradicts doc 06 §2 outright.
- **Refresh tokens in Redis.** 30-day lifetime; a flush logs out everyone.
- **Reusing an existing table.** Nothing in doc 04 fits, and putting token
  columns on `users` breaks the one-row-per-session that multi-device
  revocation needs.

## Consequences

- `refresh_tokens` exists and doc 04 does not describe it. **Doc 04 should be
  amended.**
- Expired rows need periodic pruning (a BullMQ job, once Redis lands).
- A rotation bug signs users out rather than silently granting access — the
  correct direction to fail.
- `devices` (doc 04) is not yet wired to `refresh_tokens`; `user_agent`/`ip`
  carry the binding for now. Full device binding lands with the devices module.
