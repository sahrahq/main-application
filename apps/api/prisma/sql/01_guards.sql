-- SAHRA — database guards Prisma's schema language cannot express.
--
-- Apply AFTER the Prisma migration that creates the tables. The canonical way
-- is to fold this into the init migration:
--     pnpm prisma migrate dev --create-only --name init
--     cat prisma/sql/01_guards.sql >> prisma/migrations/<ts>_init/migration.sql
--     pnpm prisma migrate dev
-- Or apply standalone with: pnpm exec prisma db execute --file prisma/sql/01_guards.sql
--
-- Every object here is specified in docs/blueprint/04-database-design.md.
-- Index names are load-bearing — do not rename (DEVELOPMENT.md §5).

-- ─────────────────────────────────────────────────────────── extensions ──
CREATE EXTENSION IF NOT EXISTS pgcrypto;    -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;      -- case-insensitive users.email
CREATE EXTENSION IF NOT EXISTS postgis;     -- restaurants.location
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- required to mix = and && in EXCLUDE

-- ───────────────────────────── indexes Prisma can't declare (doc 04 §2) ──

-- Partial: availability filters almost always scan only live restaurants.
CREATE INDEX IF NOT EXISTS idx_restaurants_active
  ON restaurants (status)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_restaurants_location
  ON restaurants USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_restaurants_cuisines
  ON restaurants USING GIN (cuisines);

-- Partial: the allocator only ever considers active tables.
CREATE INDEX IF NOT EXISTS idx_tables_rest_capacity
  ON tables (restaurant_id, max_capacity)
  WHERE active;

-- Partial: THE availability workhorse. Keeps the planner on tonight's live
-- rows instead of years of completed history.
CREATE INDEX IF NOT EXISTS idx_resv_active
  ON reservations (restaurant_id, starts_at)
  WHERE status IN ('held', 'pending', 'confirmed', 'seated');

-- Partial: drives the 60 s hold-expiry sweeper (doc 05 §4).
CREATE INDEX IF NOT EXISTS idx_resv_hold_expiry
  ON reservations (hold_expires_at)
  WHERE status = 'held';

-- ──────────────────────────────────────────────── CHECK constraints ──────

ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_locale_check,
  ADD  CONSTRAINT users_locale_check CHECK (locale IN ('ar', 'en'));

ALTER TABLE restaurants
  DROP CONSTRAINT IF EXISTS restaurants_price_band_check,
  ADD  CONSTRAINT restaurants_price_band_check
       CHECK (price_band IS NULL OR price_band BETWEEN 1 AND 4);

ALTER TABLE tables
  DROP CONSTRAINT IF EXISTS tables_capacity_check,
  ADD  CONSTRAINT tables_capacity_check
       CHECK (min_capacity <= max_capacity AND max_capacity <= 30);

ALTER TABLE reservations
  DROP CONSTRAINT IF EXISTS reservations_party_size_check,
  ADD  CONSTRAINT reservations_party_size_check CHECK (party_size BETWEEN 1 AND 50);

ALTER TABLE reservations
  DROP CONSTRAINT IF EXISTS reservations_time_check,
  ADD  CONSTRAINT reservations_time_check CHECK (ends_at > starts_at);

-- doc 04: "exactly one of day_of_week / specific_date set"
ALTER TABLE shifts
  DROP CONSTRAINT IF EXISTS shifts_dow_xor_date,
  ADD  CONSTRAINT shifts_dow_xor_date
       CHECK ((day_of_week IS NULL) <> (specific_date IS NULL));

ALTER TABLE shifts
  DROP CONSTRAINT IF EXISTS shifts_dow_range,
  ADD  CONSTRAINT shifts_dow_range
       CHECK (day_of_week IS NULL OR day_of_week BETWEEN 0 AND 6);

-- ═════════════════════════════════════════════════════════════════════════
--  LAYER 3 OF ANTI-DOUBLE-BOOKING (doc 05 §3)
--
--  Layers 1 and 2 (advisory lock + transactional re-check) live in
--  application code. This is the backstop: if they ever regress, the INSERT
--  fails loudly with 23P01 instead of double-booking a table silently.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE reservation_tables
  DROP CONSTRAINT IF EXISTS no_table_overlap;

ALTER TABLE reservation_tables
  ADD CONSTRAINT no_table_overlap
  EXCLUDE USING GIST (table_id WITH =, during WITH &&)
  WHERE (active);

-- ───────────────── keep `during` and `active` honest via triggers ────────
-- `during` and `active` are denormalized from the parent reservation so the
-- exclusion constraint has something to range over. Application code must
-- never set them by hand — these triggers own both columns.

-- ═══════════════════════════════════════════════════════════════════════════
--  THESE TWO FUNCTIONS ARE OWNED BY THE MIGRATIONS. THIS FILE ASSERTS, NEVER
--  DEFINES.
--
--  INCIDENT 7, 2026-08-10. This file used to carry its own
--  `CREATE OR REPLACE FUNCTION sahra_resv_table_sync()` and
--  `sahra_resv_propagate()` — copies of the versions in
--  `20260731000000_init`. `20260801000000_lock_down_data_api` later re-created
--  both WITH `SET search_path = ''` to close the advisor's "Function Search
--  Path Mutable" finding. This file runs AFTER `prisma migrate deploy`, and
--  `CREATE OR REPLACE FUNCTION` replaces the WHOLE definition — including the
--  SET clause. So the guards file silently un-pinned both functions every
--  time it ran.
--
--  Any environment provisioned in the documented order — `migrate deploy`
--  then this file — ended up with mutable `search_path` on both reservation
--  triggers. That includes production. The dev database passes only by an
--  accident of the order its own history happened to run in: the guards were
--  applied there BEFORE the lockdown migration, so the pin survived.
--
--  `schema-invariants.e2e-spec.ts` has asserted this correctly for weeks and
--  never once ran against a database built in the documented order.
--
--  THE COPIES ARE DELETED RATHER THAN SYNCHRONISED. Two files owning one
--  definition IS the defect; making them match repairs today and guarantees
--  the same divergence the first time someone edits one and not the other.
--  The bodies here were also the pre-lockdown ones, using unqualified
--  `reservations` — which cannot work under `search_path = ''` anyway.
-- ═══════════════════════════════════════════════════════════════════════════

DO $guard$
DECLARE
  bad text;
BEGIN
  SELECT string_agg(want.name, ', ' ORDER BY want.name) INTO bad
    FROM (VALUES ('sahra_resv_table_sync'), ('sahra_resv_propagate')) AS want(name)
   WHERE NOT EXISTS (
     SELECT 1
       FROM pg_proc p
       JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = want.name
        AND EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) c
                     WHERE c LIKE 'search_path=%')
   );

  IF bad IS NOT NULL THEN
    RAISE EXCEPTION
      'Missing or search_path-unpinned trigger function(s): %. They are created by '
      '20260731000000_init and pinned by 20260801000000_lock_down_data_api. Run '
      '`prisma migrate deploy` before this file. Do NOT re-add definitions here — '
      'this file un-pinned them for weeks by doing exactly that (Incident 7).', bad;
  END IF;
END
$guard$;

DROP TRIGGER IF EXISTS trg_resv_table_sync ON reservation_tables;
CREATE TRIGGER trg_resv_table_sync
  BEFORE INSERT OR UPDATE OF reservation_id ON reservation_tables
  FOR EACH ROW EXECUTE FUNCTION sahra_resv_table_sync();

-- When a reservation's status or window changes, push it down to its
-- allocations. Cancelling/expiring flips active=false, which releases the
-- exclusion slot and frees the table for the next booker.
-- (Definition deleted — see the Incident 7 block above. Owned by
-- 20260731000000_init, pinned by 20260801000000_lock_down_data_api, and
-- asserted present-and-pinned by the DO block above before either trigger is
-- attached.)

DROP TRIGGER IF EXISTS trg_resv_propagate ON reservations;
CREATE TRIGGER trg_resv_propagate
  AFTER UPDATE OF status, starts_at, ends_at ON reservations
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status
     OR OLD.starts_at IS DISTINCT FROM NEW.starts_at
     OR OLD.ends_at   IS DISTINCT FROM NEW.ends_at)
  EXECUTE FUNCTION sahra_resv_propagate();
