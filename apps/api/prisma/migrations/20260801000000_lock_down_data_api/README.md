# ⚠ READ THIS BEFORE CITING `migration.sql` IN A SECURITY REVIEW

Annotated **2026-08-09**, after the silent-lapse sweep. `migration.sql` is
untouched and stays untouched — Prisma stores a SHA-256 of every applied
migration, and editing one makes `migrate dev` report the schema as modified
under you. A note beside the file is the only way to annotate it without
rewriting history in the sense the tooling cares about.

## One of the statements in this migration does nothing

```sql
REVOKE USAGE ON SCHEMA public FROM anon, authenticated;   -- line 30
```

`has_schema_privilege('anon', 'public', 'USAGE')` is **still true**.

The `public` schema belongs to `supabase_admin`. A `REVOKE` issued by
`postgres` can only remove grants `postgres` itself made, so this removed
nothing. **It reported success.**

It is not a hole by itself — with no table privileges, `USAGE` on a schema buys
the ability to *name* objects and nothing more. It is on this page because a
line that reads like a protection, reports success, and does nothing is worse
than an absent line: it buys false confidence, and it is exactly the sort of
thing somebody points at in a security review.

## And this one is narrower than it reads

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;          -- lines 33–38
```

`ALTER DEFAULT PRIVILEGES` is scoped to **the role that issues it**. This
covers tables created by `postgres`. `supabase_admin` still holds default
privileges granting `anon` everything on tables *it* creates.

## So what is actually keeping `anon` out of new tables?

**Table ownership by `postgres`.** Nothing else.

`postgres`'s own default ACLs no longer mention `anon`, so a table it creates
arrives closed. A table created by any other role arrives **open**, and no
migration file would look wrong.

That check is the load-bearing one and it is asserted permanently in
`apps/api/test/schema-invariants.e2e-spec.ts`:

> `every table in public is owned by postgres` — **THE LOAD-BEARING CHECK**

## What DID work

- The table-level `REVOKE` (lines 27–29). `anon` and `authenticated` hold no
  privilege on any table we own — verified against
  `information_schema.role_table_grants`, not against this file.
- Layer 2, RLS — but only for the twelve tables named here. It did **not**
  carry forward, and five tables created later shipped without it for three
  batches. Backfilled in `20260809020000_no_silent_lapses`, and now asserted by
  `rls-coverage.e2e-spec.ts`.

## Full reasoning

`docs/decisions/2026-08-09-data-api-lockdown.md`
