# The silent-lapse sweep

**Date:** 2026-08-09
**Trigger:** Group D found that `ENABLE ROW LEVEL SECURITY` had quietly become
opt-in. `ALTER DEFAULT PRIVILEGES` carried layer 1 of the Data API lockdown
forward to new tables automatically; RLS has no equivalent, so layer 2 stopped
applying three batches ago and five tables shipped on one layer.
**Instruction:** find every other guarantee that depends on somebody
*remembering* to apply it to new objects, and either make it automatic or ask
the database about it — never the migration files. Report even a nil result.

Everything below was found by querying the live catalogue, not by reading
migrations. The new guard is
`apps/api/test/schema-invariants.e2e-spec.ts` — **18 assertions**, every one of
which enumerates from `pg_class` / `information_schema` and then asserts a
property of every row it found.

---

## 1. WAS ACTUALLY WRONG — `updated_at`

**One finding, and it is the reason the sweep was worth doing.**

`updated_at` was maintained in two places, neither of them the database:

- Prisma's `@updatedAt`, which is application-level and blind to raw SQL.
- A hand-written `updated_at = now()` in each `$executeRaw`.

The reservation engine writes with `$executeRaw` throughout, because the
three-layer locking needs statements Prisma cannot express. **Eight raw UPDATEs
touch `reservations`. Two of them forgot:**

| statement | what it does |
|---|---|
| `my-reservations.service.ts` | `SET cancellation_seen_at = now()` |
| `owner-cancellation.service.ts` | the venue cancelling a booking |

The second is among the most consequential writes in the product, and it left
`updated_at` reading from *before* the cancellation. Nothing failed. Nothing
could: no test reads the column, and the value it held was entirely plausible.

**Fixed by making it impossible to forget.** `trg_touch_updated_at` is a
`BEFORE UPDATE` trigger on every table that has the column, attached by a
`DO` block that loops over the catalogue rather than over a list. A statement
that does not mention `updated_at` cannot skip it, and Prisma writing the same
value a moment earlier is harmless.

The trigger cannot cover tables created *later* — Postgres event triggers could,
but they need superuser and `postgres` is not one on Supabase. That residue is
what the test closes: it asks whether every table with the column has the
trigger, in both directions.

---

## 2. WAS SILENTLY A NO-OP — `REVOKE USAGE ON SCHEMA public`

The lockdown migration contains:

```sql
REVOKE USAGE ON SCHEMA public FROM anon, authenticated;
```

`has_schema_privilege('anon', 'public', 'USAGE')` is **still true**. The schema
belongs to `supabase_admin`; a REVOKE issued by `postgres` can only remove
grants `postgres` made. The statement reported success and changed nothing.

**Not fixed, because we cannot fix it — asserted as true instead.** With no
table privileges, USAGE on the schema grants the ability to name objects and
nothing more. The point of the assertion is that we now *know*: a migration line
that reads like a protection is recorded as decoration, and if it ever flips to
false, somebody with more privilege than us changed it.

**The rule that actually keeps `anon` out of new tables** turned out to be
"every table in public is owned by `postgres`", and nothing was checking that
either. `supabase_admin` still holds default privileges granting `anon` full
access to tables *it* creates; `postgres`'s own no longer mention `anon`. So
ownership is the load-bearing fact, and it is now asserted.

---

## 3. WAS FALSE IN THE DOCUMENT — two of doc 04's blanket claims

doc 04's header said `created_at/updated_at … on every table` and
`id UUID PK DEFAULT gen_random_uuid()` on every table. Neither is true, and
every exception is deliberate:

- **Seven tables have no `updated_at`**: `audit_logs` (append-only; a trigger
  refuses every UPDATE, so the column could never change), `roles` (seeded
  lookup), `reservation_tables` (mutable columns set by trigger from the
  parent), `user_roles` (granted once; a revoke is a DELETE), `favorites`
  (created or deleted, never updated), `refresh_tokens` (`revoked_at` is the one
  mutation), `notifications` (`read_at`/`sent_at` are the timestamps that
  matter).
- **Three tables have a non-UUID PK**: `audit_logs` (bigint sequence), `roles`
  (smallint lookup), plus two composite join keys.

Adding seven columns nobody reads to make a sentence true would be the wrong
repair. The document now says what is true, and the exception lists are pinned
by name in the test — so an eighth table without `updated_at` has to be a
decision rather than an omission.

---

## 4. WAS A CONTRACT DEVIATION NOBODY HAD SEEN — one index name

CLAUDE.md rule 3: *"Follow the DB schema exactly, **including index names**."*
Nothing verified it. The test now extracts every `idx_*` doc 04 names — 23 of
them — and checks each against `pg_indexes`.

**One mismatch on a table that exists.** doc 04 §notifications asks for:

```
idx_notif_user_unread(user_id, created_at DESC) WHERE read_at IS NULL
```

The schema has `idx_notifications_user` on `(user_id, created_at DESC)` — a
different name, and not partial.

**Recorded rather than built.** Nothing in the API reads `read_at` at all — the
notifications *read* half is Group G — so creating it now would be an index
Postgres maintains on every insert for a query nobody makes. It goes in with
Group G, under doc 04's name. The exemption carries that reason and the test
fails if the index appears without the note being removed.

Five other names belong to tables that do not exist yet (`payments` ×3,
`loyalty_transactions`, `restaurant_subscriptions`), each recorded with *which*
table is missing — because "the table isn't there" and "we decided against it"
are different facts and only one of them is temporary.

---

## 5. CHECKED AND ALREADY CORRECT — now asserted anyway

Every one of these was right. None of them was checked, which is the same
position RLS was in on the day before it wasn't.

| guarantee | state | now asserted by |
|---|---|---|
| Every function we own pins `search_path` | 5 of 5 correct | `pg_proc.proconfig` |
| No `double precision` / `real` / `money` column anywhere | none exist | `information_schema.columns` |
| Every `numeric` is `(12,2)` | 2 of 2, one named exception | ditto, exception asserted still real |
| No `timestamp without time zone` | none exist | ditto |
| `anon`/`authenticated` hold no grant on our tables | correct | `role_table_grants` |
| RLS on every table we own | correct since Group D | `rls-coverage.e2e-spec.ts` |

`restaurants.rating_avg` is the one numeric exception at `(3,2)` — a rating
between 0 and 5, not money. Widening it to `(12,2)` would assert that a venue
could be rated 9,999,999,999.

---

## 6. LOOKED AT AND DELIBERATELY LEFT

**Seven foreign keys have no index on the referencing column** —
`favorites.restaurant_id`, `menu_items.image_id`,
`restaurant_owners.verified_by`, `restaurants.owner_id`,
`user_roles.granted_by`, `users.referred_by`, `waitlists.user_id`.

Not swept up, because **no document promises it**. This sweep is for guarantees
that were *stated* and then quietly stopped applying; "every FK should have an
index" is a performance heuristic nobody committed to, and inventing a rule
during a sweep for broken rules is how a sweep turns into a redesign. Postgres
needs such an index for the parent's DELETE and for joins in that direction —
`favorites.restaurant_id` is the one that would be felt first, on a venue
leaving the platform. Worth its own look; not this pass.

**`service_role` holds full privileges on all 24 tables.** Supabase's default,
and it bypasses RLS. The service key lives in `apps/api/.env` and never reaches
the app bundle, so it is not the exposure the publishable key was — but it is a
full-access path for anyone holding that key, which is a fact about key handling
rather than about the schema.

---

## 7. The rule this leaves behind

> A guarantee is either enforced by the database or asked of the database by a
> test. A guarantee written in a migration comment and applied by hand has a
> half-life.

And the corollary that made this sweep find anything: **a test must enumerate
from the catalogue, never from a list beside the test.** A guard handed the
things to check only ever checks the things somebody remembered — which is the
original failure, one level up.
