-- ═══════════════════════════════════════════════════════════════════════════
--  IMAGES (doc 04 §"images (polymorphic media)")
--
--  Built to the COMMITTED SPEC, not to the shape the Group B audit proposed.
--  That audit said `restaurant_images`; doc 04 says one polymorphic `images`
--  table serving restaurants, menu items, reviews and users, with the index
--  named `idx_images_owner`. CLAUDE.md rule 3 — follow the schema exactly,
--  including index names — so the document wins and the difference is reported
--  rather than quietly resolved in favour of the newer idea.
--
--  Polymorphic is also the right call on its own terms: reviews with photos
--  (C-4.4) and menu items with photos are both coming, and three near-identical
--  tables is how a codebase ends up with three near-identical upload paths.
--
--  ── WHAT `url` HOLDS, AND WHY IT IS NOT A URL ─────────────────────────────
--
--  The BASE STORAGE KEY, not a fetchable address:
--
--      restaurants/<restaurant-id>/<image-id>
--
--  The three renditions are named from it by convention — `/160.webp`,
--  `/400.webp`, `/1200.webp` — and the API composes the public URLs in its
--  response. The column keeps its committed name; only its content is narrower
--  than "any URL".
--
--  The alternative was three more columns, and it is worse. Adding a fourth
--  size later would be a migration and a backfill for every row; with a
--  convention it is a config change and a re-run of the resizer over the
--  originals we kept. A schema should not have to change because a phone got
--  a bigger screen.
--
--  ── AND WHAT IS DELIBERATELY UNUSED ───────────────────────────────────────
--
--  `blurhash` ships NULL and stays in the table. `flutter_blurhash` was
--  declined (doc 08 §5): a designed empty state plus explicit `width`/`height`
--  already gives no-layout-jump and something to look at while loading. The
--  column is committed schema, so it is created; dropping it would be a
--  deviation to save four bytes a row.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TYPE image_owner_type AS ENUM ('restaurant', 'menu_item', 'review', 'user');
CREATE TYPE image_status     AS ENUM ('processing', 'ready', 'rejected');

CREATE TABLE images (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_type  image_owner_type NOT NULL,
  owner_id    UUID             NOT NULL,

  -- Base storage key. See the header.
  url         TEXT             NOT NULL,

  blurhash    VARCHAR(50),

  -- THE ORIGINAL'S DIMENSIONS, and they are load-bearing rather than metadata.
  -- Every image in the app reserves its box from this aspect ratio before a
  -- byte arrives, so a list does not reflow as photos land — which on a Cairo
  -- mobile connection is the difference between a screen you can tap and one
  -- that moves under your thumb.
  width       INTEGER          NOT NULL,
  height      INTEGER          NOT NULL,

  position    SMALLINT         NOT NULL DEFAULT 0,
  is_cover    BOOLEAN          NOT NULL DEFAULT false,
  status      image_status     NOT NULL DEFAULT 'processing',

  created_at  TIMESTAMPTZ(6)   NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ(6)   NOT NULL DEFAULT now()
);

-- doc 04: `idx_images_owner(owner_type, owner_id, position)`. The name is part
-- of the contract, not an implementation detail.
CREATE INDEX idx_images_owner ON images (owner_type, owner_id, position);

-- ── ONE COVER PER OWNER, ENFORCED BY POSTGRES ──────────────────────────────
--
-- `is_cover` is a boolean on every row, so nothing in the column definition
-- stops two rows claiming it. The venue hero reads "the cover", and with two
-- covers it reads whichever the planner returned first — a hero that changes
-- between page loads with no code anywhere to blame.
--
-- A partial unique index says it once, in the only place that cannot be
-- bypassed by a new code path.
CREATE UNIQUE INDEX idx_images_one_cover
  ON images (owner_type, owner_id)
  WHERE is_cover;

-- Ordering within one owner is a UI contract: "first is first". Two images at
-- position 3 sort arbitrarily, which is the same class of bug as two covers.
CREATE UNIQUE INDEX idx_images_position_unique
  ON images (owner_type, owner_id, position);

-- Dimensions must be real. A zero or a negative makes the aspect-ratio box
-- above divide by zero or reserve nothing, and the CHECK is cheaper than the
-- defensive branch it saves in every client.
ALTER TABLE images
  ADD CONSTRAINT images_dimensions_positive
  CHECK (width > 0 AND height > 0);

ALTER TABLE images
  ADD CONSTRAINT images_position_non_negative
  CHECK (position >= 0);

-- `updated_at` is maintained by Prisma's `@updatedAt`, matching every other
-- table in this schema. There is no `sahra_touch_updated_at` trigger to hang
-- it on, and inventing one here would leave this table maintained differently
-- from its neighbours for no gain.
