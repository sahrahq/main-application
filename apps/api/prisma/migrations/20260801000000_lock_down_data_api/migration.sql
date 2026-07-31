-- Lock the PostgREST Data API out of the application schema.
--
-- WHY THIS IS CRITICAL
-- Supabase auto-exposes every table in `public` over PostgREST at
-- https://<ref>.supabase.co/rest/v1/<table>, authorized by the *publishable*
-- key. That key ships inside the Flutter bundle, so it is public by
-- construction — anyone can extract it from the APK.
--
-- Verified exploitable before this migration:
--   GET  /rest/v1/users             -> 200
--   GET  /rest/v1/reservations      -> 200
--   GET  /rest/v1/refresh_tokens    -> 200
--   POST /rest/v1/users             -> reached a NOT NULL constraint,
--                                      i.e. authorization passed
--
-- SAHRA does not use the Data API. Doc 03 has exactly one database client:
-- the NestJS API, connecting as `postgres` with the DB password. Every read
-- and write is supposed to go through the reservation engine's locking and
-- the Idempotency-Key path. A public REST surface bypasses all of it.
--
-- Two independent layers, so re-granting one does not silently reopen access:
--   1. REVOKE privileges from the anon / authenticated roles.
--   2. ENABLE ROW LEVEL SECURITY with no policies (deny-by-default).
-- `postgres` owns these tables and bypasses RLS, so the API is unaffected.

-- ── Layer 1: revoke ──────────────────────────────────────────────────────
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;
REVOKE USAGE ON SCHEMA public FROM anon, authenticated;

-- Future tables must not silently become public either.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

-- ── Layer 2: deny-by-default RLS ─────────────────────────────────────────
-- No CREATE POLICY anywhere: with RLS on and zero policies, every non-owner
-- role is denied. If RLS-scoped access is ever wanted (e.g. Supabase Realtime
-- on a read-only view), add narrow policies then — not now.
ALTER TABLE public.users              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_owners  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurants        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tables             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservation_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refresh_tokens     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_challenges     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._prisma_migrations ENABLE ROW LEVEL SECURITY;

-- NOTE: public.spatial_ref_sys is flagged by the advisor too, but it belongs
-- to the PostGIS extension and is not ours to alter. It holds only public
-- coordinate-system reference data — no SAHRA data — so it is left alone.

-- ── Pin function search_path (advisor: "Function Search Path Mutable") ────
-- Without a fixed search_path, a role able to create objects in an earlier
-- schema could shadow `tstzrange` or the table names and hijack the trigger.
-- Empty search_path + fully-qualified names removes the ambiguity entirely
-- (pg_catalog is always implicitly searched, so tstzrange still resolves).

CREATE OR REPLACE FUNCTION public.sahra_resv_table_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  r RECORD;
BEGIN
  SELECT starts_at, ends_at, status INTO r
  FROM public.reservations WHERE id = NEW.reservation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'reservation % not found', NEW.reservation_id;
  END IF;

  NEW.during := tstzrange(r.starts_at, r.ends_at, '[)');
  NEW.active := r.status IN ('held', 'pending', 'confirmed', 'seated');
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sahra_resv_propagate()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  UPDATE public.reservation_tables
     SET during = tstzrange(NEW.starts_at, NEW.ends_at, '[)'),
         active = NEW.status IN ('held', 'pending', 'confirmed', 'seated')
   WHERE reservation_id = NEW.id;
  RETURN NEW;
END;
$$;
