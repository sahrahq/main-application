-- SAHRA init migration.
-- Part A: tables/enums/indexes generated from prisma/schema.prisma.
-- Part B: the guards Prisma cannot express (partial + GIST/GIN indexes,
--         CHECK constraints, the EXCLUDE USING GIST anti-double-booking
--         constraint, and the triggers that maintain during/active).
-- Kept in ONE migration so a fresh database can never exist in a state where
-- reservation_tables lacks its exclusion constraint.
-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "citext";

-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "postgis";

-- CreateEnum
CREATE TYPE "user_status" AS ENUM ('pending', 'active', 'suspended', 'deleted');

-- CreateEnum
CREATE TYPE "verification_status" AS ENUM ('pending', 'verified', 'rejected');

-- CreateEnum
CREATE TYPE "restaurant_status" AS ENUM ('draft', 'pending_review', 'active', 'suspended', 'closed');

-- CreateEnum
CREATE TYPE "booking_mode" AS ENUM ('instant', 'request');

-- CreateEnum
CREATE TYPE "table_zone" AS ENUM ('indoor', 'outdoor', 'family', 'bar', 'private');

-- CreateEnum
CREATE TYPE "reservation_status" AS ENUM ('held', 'pending', 'confirmed', 'seated', 'completed', 'no_show', 'cancelled_by_user', 'cancelled_by_restaurant', 'expired');

-- CreateEnum
CREATE TYPE "reservation_source" AS ENUM ('app', 'walk_in', 'phone', 'waitlist', 'admin');

-- CreateEnum
CREATE TYPE "otp_purpose" AS ENUM ('phone_verify', 'login', 'password_reset');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" CITEXT,
    "phone" VARCHAR(20) NOT NULL,
    "password_hash" TEXT,
    "full_name" VARCHAR(120) NOT NULL,
    "avatar_url" TEXT,
    "locale" CHAR(2) NOT NULL DEFAULT 'ar',
    "status" "user_status" NOT NULL DEFAULT 'pending',
    "email_verified_at" TIMESTAMPTZ(6),
    "phone_verified_at" TIMESTAMPTZ(6),
    "no_show_count" SMALLINT NOT NULL DEFAULT 0,
    "referral_code" VARCHAR(10),
    "referred_by" UUID,
    "marketing_opt_in" BOOLEAN NOT NULL DEFAULT false,
    "deleted_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "family_id" UUID NOT NULL,
    "token_hash" CHAR(64) NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "replaced_by" UUID,
    "user_agent" TEXT,
    "ip" INET,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "otp_challenges" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "purpose" "otp_purpose" NOT NULL,
    "code_hash" CHAR(64) NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "attempts" SMALLINT NOT NULL DEFAULT 0,
    "consumed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_challenges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roles" (
    "id" SMALLSERIAL NOT NULL,
    "name" VARCHAR(30) NOT NULL,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_roles" (
    "user_id" UUID NOT NULL,
    "role_id" SMALLINT NOT NULL,
    "granted_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id","role_id")
);

-- CreateTable
CREATE TABLE "restaurant_owners" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "business_name" VARCHAR(160) NOT NULL,
    "tax_id" VARCHAR(40),
    "verification_status" "verification_status" NOT NULL DEFAULT 'pending',
    "verified_at" TIMESTAMPTZ(6),
    "verified_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "restaurant_owners_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "restaurants" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_id" UUID NOT NULL,
    "slug" VARCHAR(80) NOT NULL,
    "name_en" VARCHAR(160) NOT NULL,
    "name_ar" VARCHAR(160) NOT NULL,
    "description_en" TEXT,
    "description_ar" TEXT,
    "cuisines" TEXT[],
    "phone" VARCHAR(20),
    "email" VARCHAR(160),
    "website" TEXT,
    "address_en" TEXT,
    "address_ar" TEXT,
    "neighborhood" VARCHAR(80),
    "city" VARCHAR(80) NOT NULL DEFAULT 'Cairo',
    "location" geography(Point, 4326) NOT NULL,
    "price_band" SMALLINT,
    "amenities" JSONB,
    "policies" JSONB,
    "booking_mode" "booking_mode" NOT NULL DEFAULT 'instant',
    "slot_interval_min" SMALLINT NOT NULL DEFAULT 30,
    "pacing_limit" SMALLINT,
    "rating_avg" DECIMAL(3,2) NOT NULL DEFAULT 0,
    "rating_count" INTEGER NOT NULL DEFAULT 0,
    "status" "restaurant_status" NOT NULL DEFAULT 'draft',
    "timezone" VARCHAR(40) NOT NULL DEFAULT 'Africa/Cairo',
    "deleted_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "restaurants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shifts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "restaurant_id" UUID NOT NULL,
    "name_en" VARCHAR(60) NOT NULL,
    "name_ar" VARCHAR(60) NOT NULL,
    "day_of_week" SMALLINT,
    "specific_date" DATE,
    "opens_at" TIME(6) NOT NULL,
    "closes_at" TIME(6) NOT NULL,
    "spans_midnight" BOOLEAN NOT NULL DEFAULT false,
    "default_turn_minutes" JSONB NOT NULL,
    "is_ramadan" BOOLEAN NOT NULL DEFAULT false,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "shifts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tables" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "restaurant_id" UUID NOT NULL,
    "name" VARCHAR(30) NOT NULL,
    "min_capacity" SMALLINT NOT NULL,
    "max_capacity" SMALLINT NOT NULL,
    "zone" "table_zone" NOT NULL DEFAULT 'indoor',
    "combinable_with" UUID[],
    "priority" SMALLINT NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "tables_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reservations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(8) NOT NULL,
    "restaurant_id" UUID NOT NULL,
    "user_id" UUID,
    "guest_name" VARCHAR(120),
    "guest_phone" VARCHAR(20),
    "party_size" SMALLINT NOT NULL,
    "starts_at" TIMESTAMPTZ(6) NOT NULL,
    "ends_at" TIMESTAMPTZ(6) NOT NULL,
    "status" "reservation_status" NOT NULL DEFAULT 'held',
    "source" "reservation_source" NOT NULL DEFAULT 'app',
    "special_requests" TEXT,
    "occasion" VARCHAR(40),
    "seating_pref" "table_zone",
    "hold_expires_at" TIMESTAMPTZ(6),
    "idempotency_key" UUID,
    "cancelled_at" TIMESTAMPTZ(6),
    "cancel_reason" TEXT,
    "version" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "reservations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reservation_tables" (
    "reservation_id" UUID NOT NULL,
    "table_id" UUID NOT NULL,
    "during" tstzrange NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "reservation_tables_pkey" PRIMARY KEY ("reservation_id","table_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "users_referral_code_key" ON "users"("referral_code");

-- CreateIndex
CREATE INDEX "idx_users_status" ON "users"("status");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "idx_refresh_user" ON "refresh_tokens"("user_id");

-- CreateIndex
CREATE INDEX "idx_refresh_family" ON "refresh_tokens"("family_id");

-- CreateIndex
CREATE INDEX "idx_refresh_expiry" ON "refresh_tokens"("expires_at");

-- CreateIndex
CREATE INDEX "idx_otp_user_purpose" ON "otp_challenges"("user_id", "purpose");

-- CreateIndex
CREATE INDEX "idx_otp_expiry" ON "otp_challenges"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "roles_name_key" ON "roles"("name");

-- CreateIndex
CREATE INDEX "idx_user_roles_role" ON "user_roles"("role_id");

-- CreateIndex
CREATE UNIQUE INDEX "restaurant_owners_user_id_key" ON "restaurant_owners"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "restaurants_slug_key" ON "restaurants"("slug");

-- CreateIndex
CREATE INDEX "idx_restaurants_status_neighborhood" ON "restaurants"("status", "city", "neighborhood");

-- CreateIndex
CREATE INDEX "idx_shifts_rest_dow" ON "shifts"("restaurant_id", "day_of_week");

-- CreateIndex
CREATE INDEX "idx_shifts_rest_date" ON "shifts"("restaurant_id", "specific_date");

-- CreateIndex
CREATE UNIQUE INDEX "tables_restaurant_id_name_key" ON "tables"("restaurant_id", "name");

-- CreateIndex
CREATE UNIQUE INDEX "reservations_code_key" ON "reservations"("code");

-- CreateIndex
CREATE UNIQUE INDEX "reservations_idempotency_key_key" ON "reservations"("idempotency_key");

-- CreateIndex
CREATE INDEX "idx_resv_rest_time" ON "reservations"("restaurant_id", "starts_at");

-- CreateIndex
CREATE INDEX "idx_resv_user" ON "reservations"("user_id", "starts_at" DESC);

-- CreateIndex
CREATE INDEX "idx_restable_table" ON "reservation_tables"("table_id");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_referred_by_fkey" FOREIGN KEY ("referred_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "otp_challenges" ADD CONSTRAINT "otp_challenges_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_granted_by_fkey" FOREIGN KEY ("granted_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "restaurant_owners" ADD CONSTRAINT "restaurant_owners_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "restaurant_owners" ADD CONSTRAINT "restaurant_owners_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "restaurants" ADD CONSTRAINT "restaurants_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "restaurant_owners"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shifts" ADD CONSTRAINT "shifts_restaurant_id_fkey" FOREIGN KEY ("restaurant_id") REFERENCES "restaurants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tables" ADD CONSTRAINT "tables_restaurant_id_fkey" FOREIGN KEY ("restaurant_id") REFERENCES "restaurants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reservations" ADD CONSTRAINT "reservations_restaurant_id_fkey" FOREIGN KEY ("restaurant_id") REFERENCES "restaurants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reservations" ADD CONSTRAINT "reservations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reservation_tables" ADD CONSTRAINT "reservation_tables_reservation_id_fkey" FOREIGN KEY ("reservation_id") REFERENCES "reservations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reservation_tables" ADD CONSTRAINT "reservation_tables_table_id_fkey" FOREIGN KEY ("table_id") REFERENCES "tables"("id") ON DELETE RESTRICT ON UPDATE CASCADE;



-- ═══════════════════════════════════════════════════════════════════════════
--  PART B — guards (source of truth: prisma/sql/01_guards.sql)
-- ═══════════════════════════════════════════════════════════════════════════
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
