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

CREATE OR REPLACE FUNCTION sahra_resv_table_sync()
RETURNS TRIGGER AS $$
DECLARE
  r RECORD;
BEGIN
  SELECT starts_at, ends_at, status INTO r
  FROM reservations WHERE id = NEW.reservation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'reservation % not found', NEW.reservation_id;
  END IF;

  NEW.during := tstzrange(r.starts_at, r.ends_at, '[)');
  NEW.active := r.status IN ('held', 'pending', 'confirmed', 'seated');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_resv_table_sync ON reservation_tables;
CREATE TRIGGER trg_resv_table_sync
  BEFORE INSERT OR UPDATE OF reservation_id ON reservation_tables
  FOR EACH ROW EXECUTE FUNCTION sahra_resv_table_sync();

-- When a reservation's status or window changes, push it down to its
-- allocations. Cancelling/expiring flips active=false, which releases the
-- exclusion slot and frees the table for the next booker.
CREATE OR REPLACE FUNCTION sahra_resv_propagate()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE reservation_tables
     SET during = tstzrange(NEW.starts_at, NEW.ends_at, '[)'),
         active = NEW.status IN ('held', 'pending', 'confirmed', 'seated')
   WHERE reservation_id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_resv_propagate ON reservations;
CREATE TRIGGER trg_resv_propagate
  AFTER UPDATE OF status, starts_at, ends_at ON reservations
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status
     OR OLD.starts_at IS DISTINCT FROM NEW.starts_at
     OR OLD.ends_at   IS DISTINCT FROM NEW.ends_at)
  EXECUTE FUNCTION sahra_resv_propagate();
