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

### 3. HS256 instead of RS256 — approved deviation

Doc 09 §1.1 originally said RS256 with kid-rotated keys. Shipped as **HS256**,
approved 2026-08-01. `09-security-and-scalability.md` §1.1 has been amended so
the blueprint and the code agree — neither should be read as authoritative
while contradicting the other.

RS256 exists so a party that must *verify* a token need not hold the key that
*signs* it. SAHRA is a modular monolith (doc 03): exactly one service issues
and verifies, so there is no second party. HS256 avoids keypair generation,
JWKS hosting and rotation machinery with no consumer.

#### Exact triggers that force the switch to RS256

Any **one** of these is sufficient. On any of them, RS256 + kid-rotated keys +
a published JWKS endpoint becomes mandatory before the change ships:

1. **A second service verifies tokens.** Any process other than `apps/api`
   validating an access token — a worker, a BFF, an extracted microservice, an
   API gateway doing JWT validation at the edge. Sharing an HS256 secret with a
   second service means every holder can also *mint* admin tokens.
2. **Any external or third-party API consumer verifies our tokens.** A partner
   integration, a public API, a restaurant POS vendor — anyone outside our
   trust boundary. Handing them an HS256 secret hands them token forgery.
3. The monolith is split, per doc 09's scaling stages (implied by 1, listed
   separately because it is the likeliest route there).

**Cost of switching:** one 15-minute access-token window. Refresh tokens are
opaque and unaffected, so no user is signed out.

**Not a trigger:** more instances of `apps/api` behind a load balancer. Same
service, same trust boundary, same secret from the same manager.

#### Secret handling requirements (enforced in code)

- **≥ 256 bits.** HS256 is a symmetric MAC: the secret *is* the ability to mint
  valid tokens for any user, and a short one is brute-forceable offline from a
  single captured token.
- **From the platform secrets manager** — AWS Secrets Manager / SSM Parameter
  Store (doc 10) — injected as an environment variable at task start.
- **`.env` is local development only.** A `.env` present in production means
  the key is in the build artifact.

Enforced by `src/shared/config/secrets.validation.ts`, called from `bootstrap()`
before the app can serve traffic. In `NODE_ENV=production` it **throws** on a
secret that is absent, under 256 bits, a known placeholder, or accompanied by a
`.env` file. Outside production it warns instead, so local work is not blocked.
Six unit tests cover it. A policy that lives only in a document is not a
control.

### 4. Password login is PERMANENT, not scaffolding

Asked directly during review: is the password path temporary until Redis/OTP
lands? **No. It is a permanent, first-class login method.** Checked against the
blueprint rather than assumed:

| Source | Says |
|---|---|
| `02-functional-requirements.md` **C-1.1** | "Sign up / login with email + password (verified email)" — **P0** |
| `02-functional-requirements.md` **C-1.2** | "**Phone OTP login (SMS/WhatsApp)**" — **P0**, "Phone is the primary identity in Egypt" |
| `02-functional-requirements.md` **C-1.4** | "Password reset via email/OTP; rate-limited" — **P0** |
| `06-api-design.md` §2 | `/auth/login` accepts `{identifier, password}` **or** `{phone}` → OTP |
| `04-database-design.md` | `password_hash TEXT NULLABLE (social/OTP-only)` |

Both are P0. C-1.4 specifying password *reset* as P0 only makes sense if
passwords persist. The nullable `password_hash` is the schema encoding the same
thing: some accounts are OTP-only, others carry a password, and both are valid
states forever.

**So the shape is: three permanent login methods (password, phone OTP, social),
with phone OTP as the primary for Egypt — not password-until-OTP-arrives.**

Safe to build screens and flows on the password path. It is not going to be
removed. What is *not* yet true:

- **Phone OTP does not exist yet** (blocked on Redis) — so today an account is
  created with `status: pending` and can log in with a password, but its phone
  is unverified. `register` already returns `otpRequired: true` so clients can
  be written against the final contract now.
- **Social login (C-1.3) is not built.** `/auth/social` from doc 06 §2 is
  unimplemented.

The only genuinely temporary thing is the *gap*: verification not being
enforced between register and first use. When OTP lands, `pending` accounts
gain a real transition to `active`, and any flow that assumes a verified phone
must check `status` rather than merely "has an account".

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
