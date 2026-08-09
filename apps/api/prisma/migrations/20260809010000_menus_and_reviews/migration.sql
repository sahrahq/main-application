-- ═══════════════════════════════════════════════════════════════════════════
--  GROUP D — menus (R-2.3) and reviews (C-4.4), plus an RLS backfill
--
--  Agreed shape: docs/decisions/2026-08-09-group-d-schema-proposal.md.
--  Three deviations from doc 04, each argued there and repeated at its column:
--    · price is NUMERIC(12,2), not (10,2)      — CLAUDE.md rule 5 wins
--    · pdf_key holds a storage key, not a URL  — same as images.url
--    · rating_avg syncs in a TRIGGER, not async — recompute, never increment
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════════
--  0. RLS BACKFILL — five tables shipped without layer 2
--
--  `20260801000000_lock_down_data_api` built two independent layers, and said
--  why in its own header: "so re-granting one does not silently reopen
--  access."
--
--    Layer 1  REVOKE + ALTER DEFAULT PRIVILEGES   — covers future tables
--    Layer 2  ENABLE ROW LEVEL SECURITY, no policies — does NOT
--
--  `ALTER DEFAULT PRIVILEGES` is why layer 1 kept working automatically. There
--  is no equivalent for RLS, so every table created after that migration has
--  been running on one layer. Observed against the live database rather than
--  inferred from the migration files:
--
--    SELECT relname, relrowsecurity FROM pg_class c
--      JOIN pg_namespace n ON n.oid = c.relnamespace
--     WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity;
--
--    devices  favorites  images  notifications  waitlists
--
--  `devices` holds FCM tokens; `favorites` and `waitlists` hold which diner
--  wants what, where, and when. Not an open door — layer 1 still refuses
--  anon and authenticated — but the second layer is exactly what is supposed
--  to be there when the first one is wrong, and it was not.
--
--  Enforced from now on by `rls-coverage.e2e-spec.ts`, which asks the
--  database rather than reading this file.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.images        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waitlists     ENABLE ROW LEVEL SECURITY;


-- ═══════════════════════════════════════════════════════════════════════════
--  1. MENUS — R-2.3, C-2.6
-- ═══════════════════════════════════════════════════════════════════════════

-- doc 04 §menus, verbatim. 'ramadan' is not decoration: R-2.6 wants a menu a
-- venue swaps in as a UNIT for a month, which is the whole reason this table
-- exists above `menu_categories` rather than being collapsed into it.
CREATE TYPE menu_kind AS ENUM ('food', 'drinks', 'ramadan', 'set');

CREATE TABLE menus (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,

  name_en       VARCHAR(80) NOT NULL,
  name_ar       VARCHAR(80) NOT NULL,
  kind          menu_kind NOT NULL DEFAULT 'food',

  -- A STORAGE KEY, NOT A URL — the deviation from doc 04's `pdf_url`, and the
  -- same call `images.url` already makes. The bucket, the CDN in front of it
  -- and the path convention are deployment facts; a URL in a row freezes all
  -- three into the data. The API composes the public address on read.
  --
  -- R-2.3 calls the PDF fallback out as mattering in Cairo, where plenty of
  -- venues have only a paper or PDF menu. NOTHING IN GROUP D UPLOADS ONE. It
  -- cannot reuse the image pipeline either: `sharp` does not process PDFs, so
  -- there are no renditions, no dimensions and no `images` row. It is bytes in
  -- a bucket with a key on this row, put there the same manual admin way venue
  -- photos are.
  pdf_key       TEXT,

  position      SMALLINT NOT NULL DEFAULT 0,
  active        BOOLEAN NOT NULL DEFAULT TRUE,

  created_at    TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

CREATE TABLE menu_categories (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_id    UUID NOT NULL REFERENCES menus(id) ON DELETE CASCADE,

  name_en    VARCHAR(80) NOT NULL,
  name_ar    VARCHAR(80) NOT NULL,
  position   SMALLINT NOT NULL DEFAULT 0,

  created_at TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

CREATE TABLE menu_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id    UUID NOT NULL REFERENCES menu_categories(id) ON DELETE CASCADE,

  name_en        VARCHAR(120) NOT NULL,
  name_ar        VARCHAR(120) NOT NULL,
  description_en TEXT,
  description_ar TEXT,

  -- NUMERIC(12,2), NOT doc 04's (10,2).
  --
  -- Two committed sources disagreed and CLAUDE.md rule 5 wins: "money is
  -- NUMERIC(12,2) + currency, never floats". THIS IS THE FIRST MONEY COLUMN IN
  -- THE DATABASE — before it, the only numeric anywhere was
  -- restaurants.rating_avg — so whatever width lands here is what every later
  -- money column gets copied from. `payments.amount`, deposits, settlement,
  -- commission: all of them should read (12,2) and none of them should need
  -- this argument again.
  --
  -- Not about capacity. (10,2) caps at 99,999,999.99, which is not a real
  -- constraint on a plate of food. It is about one width everywhere, because
  -- the failure mode of two widths is a silent truncation on a copy between
  -- them, years from now, in a currency conversion nobody is watching.
  price          NUMERIC(12,2) NOT NULL,
  currency       CHAR(3) NOT NULL DEFAULT 'EGP',

  -- doc 04. Polymorphic `images` has no FK back, so this is the one direction
  -- that CAN be a real foreign key, and is. SET NULL rather than CASCADE: a
  -- deleted photo must not delete the dish.
  image_id       UUID REFERENCES images(id) ON DELETE SET NULL,

  dietary_tags   TEXT[] NOT NULL DEFAULT '{}',
  available      BOOLEAN NOT NULL DEFAULT TRUE,
  position       SMALLINT NOT NULL DEFAULT 0,

  created_at     TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

-- doc 04, verbatim: "position-ordered fetch per parent". The name is part of
-- the contract (CLAUDE.md rule 3).
CREATE INDEX idx_mi_cat ON menu_items (category_id, position);

-- The two reads doc 04 does not name but the venue page makes on every open:
-- a restaurant's live menus, and a menu's categories, both already ordered.
CREATE INDEX idx_menus_rest ON menus (restaurant_id, position) WHERE active;
CREATE INDEX idx_mc_menu    ON menu_categories (menu_id, position);

-- ── the dietary vocabulary, as a schema fact ────────────────────────────────
--
-- doc 04 says TEXT[] and stops. Left open, `gluten_free`, `Gluten_Free` and
-- `glutenfree` are three tags, and the client SILENTLY DROPS the ones it has
-- no copy for — the venue screen already skips unknown amenity keys rather
-- than show a diner a raw database value. So a typo would not fail; it would
-- disappear at render time, which is the worst available failure mode and the
-- one this repo keeps finding.
--
-- WE MARK THE EXCEPTION, NEVER THE DEFAULT. `halal` is deliberately absent:
-- in Cairo it is the default, and tagging it would imply the unmarked dishes
-- are not — both wrong and insulting. `contains_pork` and `contains_alcohol`
-- are the inverses that actually carry information, for the tourist-area and
-- Coptic-owned kitchens that do serve them, so a diner who needs to avoid
-- either does not have to ask a waiter.
--
-- `shellfish` sits with `nut_free` and `dairy_free` as an allergy tag rather
-- than a preference; Egyptian menus are full of it.
ALTER TABLE menu_items ADD CONSTRAINT menu_items_dietary_vocabulary
  CHECK (dietary_tags <@ ARRAY[
    'vegetarian',
    'vegan',
    'gluten_free',
    'nut_free',
    'dairy_free',
    'shellfish',
    'spicy',
    'contains_alcohol',
    'contains_pork'
  ]::TEXT[]);

-- "every item that is vegan", without reading the table.
CREATE INDEX idx_mi_dietary ON menu_items USING GIN (dietary_tags);

-- Free is legitimate — bread, water, the mint tea that comes with the bill.
-- Negative is not.
ALTER TABLE menu_items ADD CONSTRAINT menu_items_price_not_negative
  CHECK (price >= 0);

-- ── ordering, and why these are DEFERRABLE ──────────────────────────────────
--
-- Two rows cannot both claim slot 3; otherwise the order of a menu is whatever
-- the planner feels like that morning.
--
-- DEFERRABLE INITIALLY DEFERRED, unlike `idx_images_position_unique`, and the
-- difference is deliberate. An owner dragging item 7 above item 3 writes a
-- batch of position updates that transiently collide. A plain unique index
-- rejects the whole reorder; a deferred constraint checks at COMMIT, when the
-- batch is consistent again. Menus get a reorder UI in the management app
-- (R-2.3); images do not have one yet, which is the only reason the stricter
-- form there has not bitten. WHEN AN IMAGE REORDER UI IS BUILT, that index
-- needs this treatment — noted here because otherwise it gets discovered by an
-- owner instead of by us.
ALTER TABLE menus ADD CONSTRAINT menus_position_unique
  UNIQUE (restaurant_id, position) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE menu_categories ADD CONSTRAINT menu_categories_position_unique
  UNIQUE (menu_id, position) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE menu_items ADD CONSTRAINT menu_items_position_unique
  UNIQUE (category_id, position) DEFERRABLE INITIALLY DEFERRED;


-- ═══════════════════════════════════════════════════════════════════════════
--  2. REVIEWS — C-4.4
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TYPE review_status AS ENUM ('published', 'pending_moderation', 'rejected', 'removed');

CREATE TABLE reviews (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- ══ THE ENTIRE PRODUCT IS THIS COLUMN ══
  --
  -- C-4.4's own note: "Verified-only reviews are a trust wedge vs. Google Maps
  -- noise." NOT NULL means there is no review without a visit; UNIQUE means one
  -- review per visit.
  --
  -- Written down because the pressure to relax it is predictable and will
  -- arrive framed as growth — "a venue with two reviews looks dead, let people
  -- review without booking, just for the launch". The moment this is nullable,
  -- SAHRA's reviews are Google Maps' reviews with fewer of them.
  --
  -- RESTRICT, not CASCADE: a reservation with a review attached is not a row
  -- anything should be able to quietly delete.
  reservation_id  UUID NOT NULL UNIQUE REFERENCES reservations(id) ON DELETE RESTRICT,

  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  restaurant_id   UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,

  rating          SMALLINT NOT NULL,
  food_rating     SMALLINT,
  service_rating  SMALLINT,
  ambience_rating SMALLINT,

  -- NULLABLE, which doc 04 does not say. Stars-only reviews are the majority
  -- on every platform that allows them, and forcing prose gets prose worth
  -- nothing. What is banned below is a body that is PRESENT AND EMPTY, which
  -- is what a stray submit produces.
  body            TEXT,

  -- DEFAULT 'published'. The alternative, 'pending_moderation', means every
  -- review waits for a moderator, and A-3 (moderation) and A-10 (support) are
  -- both P1 and unbuilt. A queue with nobody reading it does not moderate
  -- reviews — it silently never publishes any, and the diner who wrote one
  -- watches it vanish with no explanation.
  --
  -- The anti-abuse argument is already answered by `reservation_id` above:
  -- only somebody who actually sat at the table can write one, which is a
  -- stronger filter than any queue. 'pending_moderation' therefore means what
  -- its name says — a state a REPORT moves a review into — rather than the
  -- front door.
  status          review_status NOT NULL DEFAULT 'published',

  owner_reply     TEXT,
  owner_replied_at TIMESTAMPTZ(6),

  created_at      TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

-- doc 04, verbatim, both of them.
CREATE INDEX idx_reviews_rest ON reviews (restaurant_id, status, created_at DESC);
CREATE INDEX idx_reviews_user ON reviews (user_id, created_at DESC);

ALTER TABLE reviews ADD CONSTRAINT reviews_rating_range
  CHECK (rating BETWEEN 1 AND 5);

-- Sub-ratings are optional but, when given, are on the same scale. A 0 or a 7
-- here would render as a broken star row rather than an error.
ALTER TABLE reviews ADD CONSTRAINT reviews_sub_ratings_range
  CHECK (
    (food_rating     IS NULL OR food_rating     BETWEEN 1 AND 5) AND
    (service_rating  IS NULL OR service_rating  BETWEEN 1 AND 5) AND
    (ambience_rating IS NULL OR ambience_rating BETWEEN 1 AND 5)
  );

-- doc 04: "body TEXT ≤ 2000 chars". btrim so that a body of spaces is the
-- empty body it actually is.
ALTER TABLE reviews ADD CONSTRAINT reviews_body_length
  CHECK (body IS NULL OR char_length(btrim(body)) BETWEEN 1 AND 2000);

-- The same shape as `waitlists_offer_has_expiry`. A reply with no timestamp
-- renders as a reply from no time; a timestamp with no reply says a restaurant
-- answered when it did not.
ALTER TABLE reviews ADD CONSTRAINT reviews_reply_has_timestamp
  CHECK ((owner_reply IS NULL) = (owner_replied_at IS NULL));

ALTER TABLE reviews ADD CONSTRAINT reviews_reply_not_blank
  CHECK (owner_reply IS NULL OR char_length(btrim(owner_reply)) BETWEEN 1 AND 2000);


-- ═══════════════════════════════════════════════════════════════════════════
--  3. rating_avg / rating_count — RECOMPUTE, NEVER INCREMENT
--
--  doc 04 says "recomputed async on review events". This is a trigger, and the
--  deviation is the point:
--
--  1. AN INCREMENT IS NOT IDEMPOTENT. Two reviews landing together produce two
--     jobs that both read the stale count. The rating drifts, permanently,
--     with nothing anywhere that would notice — the exact failure that never
--     gets found. A full recompute over an indexed aggregate is correct under
--     any concurrency and any number of retries.
--  2. THE ASYNC WINDOW IS VISIBLE TO EXACTLY THE WRONG PERSON. A diner who has
--     just posted a review and sees the venue's rating unchanged concludes it
--     did not save.
--  3. Async costs a queue, a job, a retry policy and three tests, for an
--     aggregate over tens of rows per restaurant. Review volume is orders of
--     magnitude below booking volume.
--
--  IT CANNOT CONTEND WITH THE RESERVATION ENGINE. This takes a row lock on
--  `restaurants`. The booking path — advisory lock, allocate, insert
--  reservation_tables, EXCLUDE constraint — writes to `reservations` and
--  `reservation_tables` and never to `restaurants`. The only writers of that
--  table are owner venue config and admin approval, both of which are already
--  serialized against each other by the same row lock and neither of which is
--  on a booking's critical path.
--
--  `SET search_path = ''` with fully-qualified names, per the advisor fix in
--  `20260801000000_lock_down_data_api`: without it, a role able to create
--  objects in an earlier schema could shadow the table names and hijack this.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.sahra_apply_restaurant_rating(target UUID)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  UPDATE public.restaurants SET
    rating_avg = COALESCE((
      SELECT ROUND(AVG(rating), 2) FROM public.reviews
       WHERE restaurant_id = target AND status = 'published'
    ), 0),
    rating_count = (
      SELECT COUNT(*) FROM public.reviews
       WHERE restaurant_id = target AND status = 'published'
    )
  WHERE id = target;
END;
$$;

CREATE OR REPLACE FUNCTION public.sahra_reviews_rating_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  -- On UPDATE with an unchanged restaurant_id, OLD and NEW are the same row and
  -- the first call covers both. The second fires only when a review MOVES
  -- between restaurants, which nothing does today — but a recompute that
  -- silently left the old venue's average carrying a review it no longer has
  -- would be undetectable, and this is two lines.
  IF TG_OP <> 'INSERT' THEN
    PERFORM public.sahra_apply_restaurant_rating(OLD.restaurant_id);
  END IF;

  IF TG_OP = 'INSERT'
     OR (TG_OP = 'UPDATE' AND NEW.restaurant_id IS DISTINCT FROM OLD.restaurant_id) THEN
    PERFORM public.sahra_apply_restaurant_rating(NEW.restaurant_id);
  END IF;

  RETURN NULL;  -- AFTER trigger: the return value is ignored.
END;
$$;

-- STATEMENT-level would be cheaper and is wrong: it cannot see which
-- restaurants were touched.
--
-- UPDATE is in the list because `status` moving to 'removed' or 'rejected'
-- must take the review back out of the average — moderation that leaves the
-- rating where it was has not moderated anything.
CREATE TRIGGER sahra_reviews_rating_sync
  AFTER INSERT OR UPDATE OR DELETE ON reviews
  FOR EACH ROW EXECUTE FUNCTION public.sahra_reviews_rating_sync();


-- ═══════════════════════════════════════════════════════════════════════════
--  4. Layer 2 for the four tables this migration creates
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.menus           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews         ENABLE ROW LEVEL SECURITY;
