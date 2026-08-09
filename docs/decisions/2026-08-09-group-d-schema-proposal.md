# Group D schema — proposed, agreed, built

**Date:** 2026-08-09
**Status:** APPROVED with corrections, and BUILT — `20260809010000_menus_and_reviews`.
What changed between the proposal and the build is recorded in §5 at the bottom.
**Covers:** R-2.3 (menus), C-2.6 (venue detail: menus + reviews), C-4.4 (reviews)

Four tables: `menus`, `menu_categories`, `menu_items`, `reviews`. Doc 04
specifies all four. Where this deviates from doc 04, the deviation is named and
argued rather than made quietly.

---

## 0. Read this first — the design package has no reference for either screen

There are fourteen `.jsx` references in `docs/design/ui_kits/app/`. **Neither a
menu screen nor a reviews screen is among them.** What exists is:

- `VenueDetailScreen.jsx` lines 42–53 — a *four-item menu preview*: dish,
  category, price, and the label `EGP`. Above it, a "Full menu" affordance
  which is a `<div>` with `cursor:pointer` **and no `onClick`**. In the
  reference it opens nothing.
- `RatingStars.d.ts` — `{rating?, reviews?, size?, showValue?}`. Display only.
  **There is no interactive star input in the component library**, and no
  reference for one.

So building "menu + reviews" as screens means designing three surfaces with no
pixel truth to match: a full menu, a review list, and a review composer. That
is a different activity from every screen built so far, and it is the reason
this section is above the schema rather than below it.

The schema below does not depend on how that is resolved. It is separable, and
that is why it is worth agreeing first.

---

## 1. `menus` / `menu_categories` / `menu_items`

### 1.1 The shape, from doc 04

```sql
CREATE TYPE menu_kind AS ENUM ('food', 'drinks', 'ramadan', 'set');

CREATE TABLE menus (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  name_en       VARCHAR(80) NOT NULL,
  name_ar       VARCHAR(80) NOT NULL,
  kind          menu_kind NOT NULL DEFAULT 'food',
  pdf_key       TEXT,                       -- see §1.3
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
  created_at TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

CREATE TABLE menu_items (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id    UUID NOT NULL REFERENCES menu_categories(id) ON DELETE CASCADE,
  name_en        VARCHAR(120) NOT NULL,
  name_ar        VARCHAR(120) NOT NULL,
  description_en TEXT,
  description_ar TEXT,
  price          NUMERIC(12,2) NOT NULL,     -- see §1.2
  currency       CHAR(3) NOT NULL DEFAULT 'EGP',
  image_id       UUID REFERENCES images(id) ON DELETE SET NULL,
  dietary_tags   TEXT[] NOT NULL DEFAULT '{}',
  available      BOOLEAN NOT NULL DEFAULT TRUE,
  position       SMALLINT NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

-- doc 04, verbatim. The name is part of the contract.
CREATE INDEX idx_mi_cat ON menu_items (category_id, position);
CREATE INDEX idx_menus_rest ON menus (restaurant_id, position) WHERE active;
CREATE INDEX idx_mc_menu ON menu_categories (menu_id, position);
```

Three levels, kept. The reference draws a flat list, which tempts a
categories-only design — but R-2.3 and doc 04 both want a venue to hold a food
menu and a drinks menu, and Ramadan to be a menu you swap in as a unit rather
than a category sitting next to "Mezze". Collapsing the top level makes
`kind='ramadan'` unexpressible.

### 1.2 DEVIATION — `price NUMERIC(12,2)`, not doc 04's `NUMERIC(10,2)`

Two committed sources disagree. `CLAUDE.md` rule 5 says money is
`NUMERIC(12,2)` + `currency`, non-negotiable. Doc 04 §menu_items says
`NUMERIC(10,2)`.

**This is the first money column in the database.** There is no `payments`
table yet; the only numeric in the schema today is `restaurants.rating_avg
DECIMAL(3,2)`. So whichever width goes in here becomes the precedent every
later money column is copied from, and a mismatch between two money columns is
the kind of thing that surfaces as a silent overflow during a currency
conversion years later.

Proposing the rule over the doc, and recording doc 04 as having a local
inconsistency. `NUMERIC(10,2)` caps at 99,999,999.99, which is not a real
constraint on a plate of food — this is about one width everywhere, not about
capacity.

### 1.3 DEVIATION — `pdf_key`, not doc 04's `pdf_url`

Same reasoning as `images.url`, which also holds a base storage key rather than
a URL: the bucket, the CDN in front of it and the path convention are
deployment facts, and a URL stored in a row freezes all three into the data.
The API composes the public URL on read, exactly as `ImagesService` already
does.

**Nothing in Group D uploads a PDF.** The column exists because R-2.3 calls the
PDF fallback out as mattering in Cairo — many venues have only a paper or PDF
menu — and adding the column later is another migration. The upload path is the
same admin/manual one as venue photos, and it is *more* constrained than that:
`sharp` does not process PDFs, so there are no renditions, no dimensions and no
`images` row. It is bytes in a bucket with a key on the menu.

On the client, a menu with a `pdf_key` and no items renders one control that
hands the public URL to the phone's browser via `url_launcher` — the same
handoff shape agreed for maps. The bucket is public (`SupabaseImageStorage`),
so no signing is involved.

### 1.4 PROPOSED ADDITION — a vocabulary CHECK on `dietary_tags`

Doc 04 says `TEXT[]` and stops there. Left open, `halal`, `Halal`, `HALAL` and
`حلال` are four different tags, and the client silently drops the ones it has
no copy for — the venue screen already skips unknown amenity keys rather than
render a raw database value at a diner.

That means a typo does not fail; it **disappears at render time**, which is the
worst available failure mode. Proposing the vocabulary as a schema fact:

```sql
ALTER TABLE menu_items ADD CONSTRAINT menu_items_dietary_vocabulary
  CHECK (dietary_tags <@ ARRAY[
    'vegetarian','vegan','gluten_free','nut_free','dairy_free',
    'spicy','contains_alcohol'
  ]::TEXT[]);
CREATE INDEX idx_mi_dietary ON menu_items USING GIN (dietary_tags);
```

**The list itself is a product call, not an engineering one**, and it is the
one thing in this document I would most like corrected. Notably absent:
`halal`, because in Cairo it is the default rather than a distinguishing tag,
and tagging it would imply the untagged items are not. `contains_alcohol` is
the inverse that actually carries information, and it pairs with the existing
`alcohol_free` amenity.

### 1.5 PROPOSED ADDITION — position uniqueness, deferrable

```sql
ALTER TABLE menu_items ADD CONSTRAINT menu_items_position_unique
  UNIQUE (category_id, position) DEFERRABLE INITIALLY DEFERRED;
```

Same invariant as `idx_images_position_unique`: two items cannot both claim
slot 3, because then the order depends on whatever the planner feels like.

**DEFERRABLE, unlike the images one, and that difference is deliberate.** An
owner dragging item 7 above item 3 in a forty-item menu writes a batch of
position updates that transiently collide. A plain unique index rejects the
whole reorder; a deferred constraint checks at COMMIT, when the batch is
consistent again. Menus get a reorder UI in the management app (R-2.3); images
do not have one yet, which is the only reason `images` got away with the
stricter form. **When an image reorder UI is built, that index needs the same
treatment** — noted here because that is exactly the kind of thing that gets
discovered by an owner instead.

---

## 2. `reviews`

### 2.1 The shape, from doc 04

```sql
CREATE TYPE review_status AS ENUM ('published', 'pending_moderation', 'rejected', 'removed');

CREATE TABLE reviews (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id  UUID NOT NULL UNIQUE REFERENCES reservations(id) ON DELETE RESTRICT,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  restaurant_id   UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,

  rating          SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  food_rating     SMALLINT CHECK (food_rating     BETWEEN 1 AND 5),
  service_rating  SMALLINT CHECK (service_rating  BETWEEN 1 AND 5),
  ambience_rating SMALLINT CHECK (ambience_rating BETWEEN 1 AND 5),

  body            TEXT,
  status          review_status NOT NULL DEFAULT 'published',

  owner_reply     TEXT,
  owner_replied_at TIMESTAMPTZ(6),

  created_at      TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

CREATE INDEX idx_reviews_rest ON reviews (restaurant_id, status, created_at DESC);
CREATE INDEX idx_reviews_user ON reviews (user_id, created_at DESC);
```

### 2.2 `reservation_id NOT NULL UNIQUE` is the entire product

C-4.4's note reads: *"Verified-only reviews are a trust wedge vs. Google Maps
noise."* That wedge is one column. NOT NULL means there is no review without a
visit; UNIQUE means one review per visit.

Writing it down because the pressure to relax it is predictable and will arrive
framed as growth: *a venue with two reviews looks dead, let people review
without booking, just for the launch*. The moment `reservation_id` becomes
nullable, SAHRA's reviews are Google Maps' reviews with fewer of them.

`ON DELETE RESTRICT`, not CASCADE — a reservation with a review attached is not
a row anything should be able to quietly delete.

### 2.3 The eligibility rule is a SERVICE rule, and that is the weak point

C-4.4 says a review requires a **seated** reservation. In the enum that means
`seated` or `completed`; a `no_show` or a cancellation must not qualify.

This is **not** enforceable in the schema, and I would rather say so than
pretend. A CHECK cannot read another table. The composite-FK trick
(`UNIQUE(id, status)` on reservations, then a two-column FK from reviews) does
work, but it makes an *unrelated* later write fail: once a review exists, an
owner correcting a reservation to `no_show` gets a foreign-key error from a
table they have never heard of.

So: enforced in `ReviewsService`, with a test per non-eligible status. It is
the one invariant in Group D held by code rather than by the database, and it
is listed here so that fact is visible rather than discovered.

### 2.4 DECISION NEEDED — `status` defaults to `published`

Proposing `published`. The alternative, `pending_moderation`, means every
review waits for a moderator, and A-10 (support) and A-3 (moderation) are both
P1 and unbuilt. A queue with nobody reading it does not moderate reviews; it
silently never publishes any, and the diner who wrote one watches it vanish.

The anti-abuse argument is already answered by §2.2: only a diner who actually
sat at the table can write one, which is a stronger filter than any moderation
queue. `pending_moderation` then means what its name says — a state a *report*
moves a review into — rather than the front door.

**This is a product call and I am proposing, not deciding.**

### 2.5 PROPOSED ADDITION — tie the reply to its timestamp

```sql
ALTER TABLE reviews ADD CONSTRAINT reviews_reply_has_timestamp
  CHECK ((owner_reply IS NULL) = (owner_replied_at IS NULL));

ALTER TABLE reviews ADD CONSTRAINT reviews_body_length
  CHECK (body IS NULL OR char_length(btrim(body)) BETWEEN 1 AND 2000);
```

Same shape as `waitlists_offer_has_expiry`. A reply with no timestamp renders
as a reply from no time; a timestamp with no reply is a row that says a
restaurant answered when it did not.

`body` is **nullable** — doc 04 does not say so, and stars-only reviews are the
majority on every platform that allows them. What is banned is a body that is
present and empty, which is what a stray submit produces.

### 2.6 DEVIATION — recompute `rating_avg` in a TRIGGER, not asynchronously

Doc 04: *"`rating_avg`/`rating_count` on restaurants (recomputed async on review
events)."*

Proposing a trigger that runs a full recompute:

```sql
UPDATE restaurants SET
  rating_avg   = COALESCE((SELECT AVG(rating) FROM reviews
                           WHERE restaurant_id = r AND status = 'published'), 0),
  rating_count =          (SELECT COUNT(*)    FROM reviews
                           WHERE restaurant_id = r AND status = 'published')
WHERE id = r;
```

Three reasons:

1. **Recompute, never increment.** An increment is not idempotent: two reviews
   landing together produce two jobs that both read the stale count, and the
   rating drifts permanently with no way to notice. A full recompute over an
   indexed aggregate is correct under any concurrency and any number of
   retries.
2. **The async window is visible to exactly the wrong person.** A diner who has
   just posted a review and sees the venue's rating unchanged concludes it did
   not save.
3. **Async costs a queue, a job, a retry policy and three tests** for an
   aggregate over a table that will hold tens of rows per restaurant. Review
   volume is orders of magnitude below booking volume; this is not where write
   throughput is at risk.

Nothing in the booking path writes to `restaurants`, so the row lock this takes
cannot contend with the reservation engine. Worth stating explicitly since
"don't touch anything the booking path touches" is the standing rule.

### 2.7 NOT IN GROUP D — review photos

C-4.4 says "1–5 stars + text + photos". `image_owner_type` already includes
`'review'`, so this costs no enum migration when it comes.

It is out of scope because of a constraint already agreed, quoted from
`docs/decisions/2026-08-09-hand-rolled-multipart.md`: the parser **"handles
ADMIN-AUTHENTICATED input only and must never be reused for an unauthenticated
or diner-facing upload path"**. A diner uploading a photo of their dinner is
precisely the diner-facing upload path that boundary exists to refuse.

Per that same decision, review photos are the trigger to revisit the `multer`
dependency — not to extend the hand-rolled parser. That is a dependency
decision that needs asking, and it is not being smuggled into a schema batch.

### 2.8 NOT IN GROUP D, and a gap in doc 04 — `review_reports`

C-4.4 wants a report flow and A-3 wants a report queue. **Doc 04 has no table
for either.** Reporting needs `review_reports(id, review_id, reporter_user_id,
reason ENUM, note, status, resolved_by, resolved_at)` plus
`UNIQUE(review_id, reporter_user_id)` so one person cannot brigade a review
alone.

Not proposing it now: it is P1, it is admin-surface work, and — as with
impersonation — a queue with no reader is not moderation. Recorded so it is a
known gap rather than an oversight.

---

## 3. What this adds up to

| | |
|---|---|
| New tables | 4 |
| New enums | 2 (`menu_kind`, `review_status`) |
| Enum changes to existing types | **none** — `image_owner_type` already has `menu_item` and `review` |
| Doc 04 deviations | 3 (price width, `pdf_key`, trigger-not-async) |
| Additions beyond doc 04 | 4 (dietary vocabulary, deferred position unique, reply-pair CHECK, body-length CHECK) |
| Invariants held by code rather than the DB | 1, named in §2.3 |

## 4. What I need agreed before writing the migration

1. §0 — how the three reference-less surfaces get built, or whether they wait.
2. §1.2 — `NUMERIC(12,2)` over doc 04's `(10,2)`, setting the precedent.
3. §1.4 — the dietary vocabulary list.
4. §2.4 — reviews default to `published`.
5. §2.6 — trigger instead of async recompute.


---

## 5. What the product owner changed, and what it cost

Approved as proposed, with two additions and one instruction.

### 5.1 The dietary vocabulary gained two entries

`shellfish` and `contains_pork`, by the same rule the list was already built
on — **mark the exception, never the default**:

> `contains_pork` — the exception worth marking, not the default. Some venues
> in tourist areas and some Coptic-owned kitchens serve it, and a diner who
> needs to avoid it should not have to ask a waiter.
>
> `shellfish` — a common allergy and Egyptian menus are full of it. Nut-free
> and dairy-free are in the list; shellfish is at least as load-bearing.

Final list, in the CHECK constraint and in `menu_copy.dart`, with
`dietary_vocabulary_test.dart` reading the migration on disk and failing if the
two ever drift:

    vegetarian · vegan · gluten_free · nut_free · dairy_free
    shellfish · spicy · contains_alcohol · contains_pork

### 5.2 The code-held invariant, in the owner's words

> "only a seated diner may review" enforced in code, not the database, and
> flagged rather than dressed up as enforced.

That sentence is now in `review-eligibility.ts`, which is the single definition
both `POST /reviews` and the bookings list's `can_review` flag call. Attacked
from three directions:

- `menus-reviews.e2e-spec.ts` attempts a review from **every** one of the seven
  non-eligible statuses, over HTTP.
- `review-eligibility.spec.ts` covers the time half, which an e2e test cannot
  reach without waiting for a meal to end.
- A cross-check asks the reservation what it predicts, then attempts the review,
  and fails if the two disagree — which is what would catch the rule being
  reimplemented on either side.

### 5.3 The gallery, from our own findings

> `VenueProfile.images` is fetched and only the first entry is drawn […]
> correct at every layer, absent on screen.

Built. `GalleryStrip` draws everything after the hero.

### 5.4 `review_reports` — SCHEDULED, not open

The owner's reason for upgrading it from "known gap" to "scheduled":

> published-by-default with no way to report is the combination that hurts

**Cost: half a batch, and it is not migration-heavy.** One table, one diner
endpoint, one unique index:

```sql
review_reports(
  id, review_id FK, reporter_user_id FK,
  reason ENUM('spam','abusive','not_my_visit','wrong_venue','other'),
  note TEXT, status ENUM('open','upheld','rejected'),
  resolved_by FK NULL, resolved_at TIMESTAMPTZ NULL,
  UNIQUE(review_id, reporter_user_id)
)
```

The UNIQUE is the whole design: one person cannot brigade a review alone.

What makes it half a batch rather than one is that the **queue** is not in it.
Reporting is diner-facing and cheap; reading the queue is A-3, admin-surface
work, and it belongs with the rest of the admin batch. Building the report
button without the queue is deliberate and is the same trade as the waitlist's
join-without-notify: the report is recorded, and until a moderator exists it is
recorded for the moderator who will.

**ACCEPTED ON THESE TERMS**, in the product owner's words, and they go in the
service docblock when it is built so nobody later reads it as half-finished:

> `review_reports` without a queue is accepted on the same terms as the
> waitlist's join-without-notify: **recording with no reader, deliberately**,
> with the reader arriving in A-3.

`WaitlistService` already carries the equivalent sentence — *"Nothing here
offers anybody a table"* — and it is the reason nobody has since mistaken the
missing half for a bug. The report service gets the same treatment: a docblock
that says the queue is A-3, that a report is recorded and read by nobody until
then, and that this is a decision rather than a gap.

**Order confirmed:** the silent-lapse sweep → the location half-batch →
`review_reports` → G.

### 5.5 Two things found while building that were not in the proposal

**Five tables had no row-level security.** `notifications`, `devices`, `images`,
`favorites`, `waitlists` — every table created after the lockdown migration.
`ALTER DEFAULT PRIVILEGES` carried layer 1 forward automatically; there is no
equivalent for RLS, so layer 2 silently stopped applying. Backfilled in this
migration and now enforced by `rls-coverage.e2e-spec.ts`, which asks `pg_class`
rather than reading the migration files.

**The OpenAPI exporter failed silently.** `logger: false` meant a
dependency-resolution error exited 1 with nothing on either stream. Now
`['error', 'warn']`.
