-- ═══════════════════════════════════════════════════════════════════════════
--  GROUP C — favorites (C-2.7) and waitlists (C-3.6)
--
--  `waitlists` is COPIED FROM doc 04 §waitlists, field for field, including
--  both index names and the UNIQUE. `favorites` appears in doc 04 only as an
--  ER-diagram edge — USERS ||--o{ FAVORITES — with no field table, so the NAME
--  comes from the document and the columns are designed here. Reported as a
--  gap in the schema doc rather than resolved by inventing a different name.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────── favorites ──
--
-- A saved venue. Deliberately thin: an id, who, which, and when.
--
-- NO `position` COLUMN, and that is a decision. `SavedScreen.jsx` shows one
-- list in reverse-chronological order, and a manual ordering nobody asked for
-- would need a reorder UI, a drag handle, and a uniqueness constraint — three
-- things to build and maintain for a list that is usually under twenty rows.
-- Newest first is what the reference draws.
CREATE TABLE favorites (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

-- SAVING TWICE IS SAVING ONCE. Without this, a double tap on a slow connection
-- puts the same venue in the list twice, and the second row is invisible to
-- the diner and undeletable through the UI, which only knows about one.
CREATE UNIQUE INDEX idx_favorites_unique ON favorites (user_id, restaurant_id);

-- The read: "my saved places, newest first". One index serves it entirely.
CREATE INDEX idx_favorites_user ON favorites (user_id, created_at DESC);

-- ON DELETE CASCADE on both sides, deliberately. A deleted account's saves are
-- not data anybody wants (C-1.7 is coming and this is one less thing for it to
-- sweep), and a venue that leaves the platform must not leave rows pointing at
-- a restaurant no read can resolve.

-- ─────────────────────────────────────────────────────────────── waitlists ──

CREATE TYPE waitlist_status AS ENUM ('waiting', 'offered', 'converted', 'expired', 'cancelled');

CREATE TABLE waitlists (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  desired_date  DATE NOT NULL,

  -- The range the diner will actually accept. NOT the whole evening: a
  -- notification offering 22:30 to somebody who said 19:00–20:00 is worse than
  -- no notification, because it trains them to ignore the next one.
  window_start  TIMESTAMPTZ(6) NOT NULL,
  window_end    TIMESTAMPTZ(6) NOT NULL,

  party_size    SMALLINT NOT NULL,
  status        waitlist_status NOT NULL DEFAULT 'waiting',

  -- Set when a table frees and this entry is offered it. C-3.6 says the claim
  -- window is 10 minutes.
  offer_expires_at TIMESTAMPTZ(6),

  -- doc 04: "loyalty tier boost later". Zero for everyone today; the column
  -- exists because the ordering it will change is being written now, and
  -- retrofitting a sort key is worse than carrying an unused one.
  priority      SMALLINT NOT NULL DEFAULT 0,

  created_at    TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

-- doc 04, verbatim: the names are part of the contract.
CREATE INDEX idx_wait_rest_date ON waitlists (restaurant_id, desired_date, status);

-- doc 04: "partial on status='offered' for expiry sweep". The sweeper reads
-- only offers that have run out, so the index is the shape of that question.
CREATE INDEX idx_wait_offered_expiry ON waitlists (offer_expires_at)
  WHERE status = 'offered';

-- doc 04: "UNIQUE(restaurant_id, user_id, desired_date) prevents duplicates."
--
-- A PARTIAL unique, and the deviation is deliberate and narrow. Taken
-- literally, the committed constraint means a diner who joins a waitlist,
-- cancels, and changes their mind an hour later is refused — permanently, for
-- that venue on that date. The intent is "no two LIVE entries", so the index
-- covers the live statuses only and a settled row stops blocking.
CREATE UNIQUE INDEX idx_wait_no_duplicates
  ON waitlists (restaurant_id, user_id, desired_date)
  WHERE status IN ('waiting', 'offered');

-- A window that ends before it starts can never be satisfied, and would sit in
-- the queue forever being skipped by every sweep.
ALTER TABLE waitlists
  ADD CONSTRAINT waitlists_window_ordered CHECK (window_end > window_start);

ALTER TABLE waitlists
  ADD CONSTRAINT waitlists_party_size_sane CHECK (party_size BETWEEN 1 AND 50);

-- An offer with no expiry is an offer nothing can reclaim — the claim window
-- IS the feature (C-3.6, 10 minutes), so the two states are tied together.
ALTER TABLE waitlists
  ADD CONSTRAINT waitlists_offer_has_expiry
  CHECK ((status = 'offered') = (offer_expires_at IS NOT NULL));
