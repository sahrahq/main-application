# The Data API lockdown — what actually protects us

**Decision made:** 2026-08-01, as `20260801000000_lock_down_data_api`.
**Written down:** 2026-08-09, which is the point of this first paragraph.

The lockdown was the most security-consequential change in this repo and it
never had a decision doc. Its reasoning lived in a migration header, where it
could not be reviewed, could not be cited, and — as it turned out — could not
be checked. Two of the three things below were only discovered when the
silent-lapse sweep asked the database instead of reading that header.

---

## 1. What the problem was

Supabase auto-exposes every table in `public` over PostgREST at
`https://<ref>.supabase.co/rest/v1/<table>`, authorised by the **publishable
key**. That key ships inside the Flutter bundle; it is public by construction
and extractable from the APK.

Verified exploitable before the migration:

```
GET  /rest/v1/users          -> 200
GET  /rest/v1/reservations   -> 200
GET  /rest/v1/refresh_tokens -> 200
POST /rest/v1/users          -> reached a NOT NULL constraint (authorization passed)
```

SAHRA has exactly one database client: the NestJS API, connecting as `postgres`.
A public REST surface bypasses the reservation engine's locking and the
`Idempotency-Key` path entirely.

---

## 2. What we thought protected us

Two layers, "so re-granting one does not silently reopen access":

1. `REVOKE` privileges from `anon` / `authenticated`, plus
   `ALTER DEFAULT PRIVILEGES` for tables created later.
2. `ENABLE ROW LEVEL SECURITY` with no policies — deny-by-default.

---

## 3. What actually protects us

### ✅ The table-level REVOKE — works

`anon` and `authenticated` hold no privilege on any table we own. Verified
against `information_schema.role_table_grants`.

### ⚠ `REVOKE USAGE ON SCHEMA public` — **does nothing**

`has_schema_privilege('anon', 'public', 'USAGE')` is still true. The schema
belongs to `supabase_admin`, and a REVOKE issued by `postgres` can only remove
grants `postgres` made. **The statement reported success and changed nothing.**

Not a hole on its own: with no table privileges, `USAGE` grants the ability to
name objects and nothing else. It is called out because a line that reads like
a protection and does nothing is worse than an absent line — we would have
pointed at it in a review.

### ⚠ `ALTER DEFAULT PRIVILEGES` — narrower than it reads

Scoped to the issuing role. It covers tables created by `postgres`.
`supabase_admin` still holds default privileges granting `anon` everything on
tables **it** creates.

### 🔒 **TABLE OWNERSHIP BY `postgres` — this is the protection**

Stated plainly, because it is the sentence that was missing:

> **The thing keeping `anon` out of new tables is that `postgres` owns them.**
> Not the `REVOKE`, which cannot reach a future table. Not the
> `ALTER DEFAULT PRIVILEGES` on its own, which only applies because `postgres`
> is the creator. A table created by any other role arrives with `anon`
> holding `SELECT, INSERT, UPDATE, DELETE` on it, and no migration would look
> wrong.

That is now the load-bearing assertion in
`apps/api/test/schema-invariants.e2e-spec.ts`, labelled as such, and it is
permanent.

### ⚠ RLS — did not carry forward

Layer 2 covered the twelve tables named in the migration and nothing after
them. There is no `ALTER DEFAULT PRIVILEGES` equivalent for RLS, so five tables
created over the following three batches — `notifications`, `devices`,
`images`, `favorites`, `waitlists` — ran on one layer. Backfilled in
`20260809020000_no_silent_lapses`; asserted by `rls-coverage.e2e-spec.ts`.

---

## 4. `service_role`

Holds full privileges on all 24 tables and bypasses RLS. That is Supabase's
default and we have not changed it. The service key lives in `apps/api/.env`
and never reaches the app bundle, so it is not the exposure the publishable key
was — but it is a full-access path for anyone holding that key. **That is a
fact about key handling, not about the schema**, and it belongs in whatever
secrets review happens before launch.

---

## 5. The rule this leaves

A protection is only a protection if something can fail when it stops working.
Three of the five mechanisms above were believed for weeks on the strength of
a migration having run without error. Two of them were not doing what the file
said.

Every claim in this document is now asserted against the live catalogue by
`schema-invariants.e2e-spec.ts` and `rls-coverage.e2e-spec.ts` — including the
one we cannot fix, which is asserted as **still granted** so that nobody
mistakes it for closed.
