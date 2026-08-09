-- ═══════════════════════════════════════════════════════════════════════════
--  THE SILENT-LAPSE SWEEP
--
--  Group D found that `ENABLE ROW LEVEL SECURITY` had quietly become opt-in:
--  `ALTER DEFAULT PRIVILEGES` carried layer 1 of the Data API lockdown forward
--  to new tables automatically, and there is no equivalent for RLS, so layer 2
--  stopped applying three batches ago and nothing anywhere said so.
--
--  That shape generalises, so every other guarantee in this schema that depends
--  on somebody REMEMBERING was swept for. What the sweep found, and what this
--  migration does about it, is below. Everything it did NOT find is in
--  `docs/decisions/2026-08-09-silent-lapse-sweep.md`, because "nothing" is
--  worth knowing too.
--
--  The general rule from here: a guarantee is either enforced by the database
--  or asked of the database by a test. A guarantee written in a migration
--  comment and applied by hand is a guarantee with a half-life.
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
--  1. updated_at — THE ONE THAT WAS ACTUALLY WRONG
--
--  `updated_at` was maintained in two places, neither of them the database:
--
--    · Prisma's `@updatedAt`, which is APPLICATION-level. It sets the column on
--      `prisma.x.update()` and knows nothing about anything else.
--    · A hand-written `updated_at = now()` in each raw SQL UPDATE.
--
--  The reservation engine writes with `$executeRaw` throughout, because the
--  three-layer locking needs statements Prisma cannot express. Eight raw
--  UPDATEs touch `reservations`. **Two of them forgot:**
--
--    my-reservations.service.ts   SET cancellation_seen_at = now()
--    owner-cancellation.service.ts SET status = 'cancelled_by_restaurant', …
--
--  The second is the venue cancelling a booking — one of the most consequential
--  writes in the product — and it left `updated_at` reading from before the
--  cancellation. Nothing failed. Nothing could: the column is not read by any
--  test, and the value it holds is plausible.
--
--  So it stops being a convention. A BEFORE UPDATE trigger cannot be forgotten
--  by a statement that does not mention it, and Prisma writing the same value a
--  moment earlier is harmless — the trigger wins and they agree.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.sahra_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  -- Unconditional. A "only if the row actually changed" version sounds tidier
  -- and is wrong: an UPDATE that writes the same values is still a write, and
  -- the question `updated_at` answers is "when was this row last written",
  -- which is what a sync or an audit needs.
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ATTACHED BY ASKING THE CATALOG, not by listing the tables.
--
-- A hand-written list is the thing this whole migration exists to remove: it
-- would be correct today and one table behind on the day somebody adds one.
-- This loop covers exactly the tables that have the column, whatever they are.
--
-- It cannot cover tables created LATER — Postgres event triggers could, but
-- they need superuser and `postgres` is not one on Supabase. That gap is closed
-- by `schema-invariants.e2e-spec.ts`, which asks the database whether every
-- table with an `updated_at` column has this trigger on it.
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT c.relname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a ON a.attrelid = c.oid
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND a.attname = 'updated_at'
       AND a.attnum > 0
       AND NOT a.attisdropped
     ORDER BY c.relname
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_touch_updated_at ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_touch_updated_at BEFORE UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.sahra_touch_updated_at()', t);
  END LOOP;
END $$;

-- audit_logs is DELIBERATELY not in that set, and would not be even if it had
-- the column: `sahra_audit_is_append_only` rejects every UPDATE on it, so a
-- BEFORE UPDATE trigger there could only ever fire on its way to being
-- refused. Recorded because the absence otherwise looks like an oversight.


-- ═══════════════════════════════════════════════════════════════════════════
--  2. LAYER 1, RE-APPLIED — and the half of it that CANNOT be applied by us
--
--  The table-level REVOKE held: `anon` and `authenticated` have no privilege on
--  any table we own. Verified by asking `information_schema.role_table_grants`
--  rather than by re-reading the migration.
--
--  Two things it did NOT hold, both worth writing down:
--
--  a) `REVOKE USAGE ON SCHEMA public FROM anon, authenticated` DID NOTHING.
--     `has_schema_privilege('anon','public','USAGE')` is still true. The schema
--     is owned by `supabase_admin`, and a REVOKE issued by `postgres` can only
--     remove grants `postgres` made. Ours reported success and changed nothing.
--     It is not a hole on its own — with no table privileges, USAGE on the
--     schema grants the ability to name things and nothing else — but a
--     statement that silently does nothing is exactly what this sweep is for,
--     and it is now asserted rather than assumed.
--
--  b) `supabase_admin` still holds DEFAULT PRIVILEGES that grant `anon` full
--     access to tables IT creates. Ours are created by `postgres`, whose own
--     default ACLs no longer mention `anon`. So the rule that keeps us safe is
--     "every table in public is owned by postgres" — which nothing was
--     checking. It is now.
--
--  Re-running the REVOKE anyway: it is idempotent, and a table added by a
--  future migration that somehow acquired a grant is cheaper to revoke twice
--  than to reason about once.
-- ═══════════════════════════════════════════════════════════════════════════

REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

-- The three tables where `anon` DOES still have privileges are PostGIS's own:
-- `spatial_ref_sys`, `geometry_columns`, `geography_columns`. The lockdown
-- migration already recorded why they are left alone — they belong to the
-- extension, hold no SAHRA data, and are not ours to ALTER. Named in the test
-- as exemptions so the list cannot grow quietly.


-- ═══════════════════════════════════════════════════════════════════════════
--  3. Nothing else needed changing — see the decision doc for the full list
--
--  Checked and already correct, now each with a test that asks the database:
--
--    · every function we own pins `search_path` (5 of 5)
--    · no `double precision`, `real` or `money` column exists anywhere
--    · no `timestamp without time zone` column exists anywhere
--    · every `numeric` column is (12,2) except `restaurants.rating_avg`,
--      which is (3,2) and is a rating rather than money
--    · every index doc 04 names by name actually exists
--
--  And two of doc 04's blanket claims are simply FALSE, which the doc now says
--  instead of promising:
--
--    · `created_at/updated_at on every table` — 7 of 20 tables have no
--      `updated_at`, every one of them deliberately (append-only, seeded
--      lookup, or a row whose only mutable fields are trigger-maintained).
--    · `id UUID PK DEFAULT gen_random_uuid() on every table` — `audit_logs` is
--      a bigint sequence, `roles` a smallint lookup, and two join tables have
--      composite keys.
--
--  Pinned by name in the test, so an eighth table without `updated_at` has to
--  be a decision rather than an omission.
-- ═══════════════════════════════════════════════════════════════════════════
