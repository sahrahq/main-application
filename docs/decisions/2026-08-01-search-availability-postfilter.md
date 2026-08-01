# Discovery search: availability is post-filtered from the live engine, never cached in the index

**Date:** 2026-08-01
**Status:** Accepted
**Applies to:** `GET /restaurants/search` — doc 06 §3
**Decided by:** product owner, explicitly

---

## Context

doc 06 §3 specifies `/restaurants/search` as "Meilisearch + availability
post-filter", and its response item carries `next_available`. Two ways to build
that:

1. **Post-filter with real slots.** Meilisearch matches; the live
   AvailabilityService then decides which results actually have a table.
2. **Text-only search now**, `next_available` later.

Option 2 is much cheaper: option 1 costs an availability computation per
result, and availability is a query per slot per venue.

## Decision

**Option 1.** A result with no `next_available` means the diner taps through
and finds nothing bookable — the worst failure mode in a reservation app, and
the one search exists to prevent. Shipping text-only search would also break
the doc 06 response contract and guarantee a rework.

Three constraints were made explicit and are each held by a test in
`apps/api/test/search.e2e-spec.ts`:

### 1. Availability is computed for the first page only

Page size is `SEARCH_PAGE_SIZE = 20` (doc 06 §1: `?limit=20&cursor=...`).
Results the diner cannot see yet cost nothing; later pages compute on request.

*Test:* `computes availability for at most one page (20)`.

Consequence, accepted deliberately: a page can return **fewer than 20 results**
once venues with nothing free are dropped. The cursor therefore advances by
index position, not by results returned — re-deriving it from the survivors
would silently re-serve or skip venues.

### 2. `next_available` comes from AvailabilityService — the same code path a hold uses

It is never read from a field cached in the Meilisearch document. Availability
is derived, never stored (doc 05 §1), so a cached slot is a promise the engine
never made. The index document type (`search.port.ts`) has no availability
field at all, which makes the mistake unrepresentable rather than merely
forbidden.

*Test:* `adds next_available from AvailabilityService when a window is asked for`
asserts every advertised time is one the AvailabilityService itself returns.

### 3. A stale `next_available` is not trusted at booking time

Search shows a hint, not an offer. Creating a hold re-validates under the
per-restaurant lock, and a slot taken in between yields `slot_taken` — never a
silent failure.

`next_available` deliberately carries only local `HH:MM` strings and **no
absolute instant**, so no client can treat one as directly bookable; to book,
the client calls `/restaurants/:id/availability` for real `starts_at` values.

*Test:* `a stale next_available still fails safe at booking time`.

---

## Supporting decisions

### The index decides WHICH; Postgres decides WHAT

Only `id` is read back from a Meilisearch hit. Every displayed field —
name, price band, rating — is re-read from Postgres for the page, under
`status = 'active' AND deleted_at IS NULL`.

This makes index staleness cost **recall, never correctness**: a venue
suspended a second ago and still sitting in the index simply vanishes from
results. The index can lag; it can never resurrect a dead listing or show a
price that changed last week.

*Test:* `renders display fields from POSTGRES, not from the indexed document`.

### Indexing is a consequence of an admin decision, not a condition of it

`AdminRestaurantsService.approve/reject` syncs the index **after** the
transaction commits, inside a `try/catch` that logs. A search server being down
must never stop an admin putting a venue live, and an index write must never
hold a database transaction open across a network call.

Drift is reconciled by `pnpm reindex`, which also removes documents for venues
that are no longer active — the half a naive "re-add everything" reindex skips.

### No Meilisearch client library

`meilisearch@0.60` is ESM-only; the API is a CommonJS Nest build. Rather than
pin a two-year-old client or move the whole service's module system, the
adapter calls the REST API with `fetch` — six endpoints, behind
`RestaurantIndexPort`, which is what the port is for. The stack table
(`DEVELOPMENT.md` §2) is unchanged and no dependency was added.

### Search unavailable is a 503, never an empty list

Both the Meilisearch adapter and the disabled adapter throw
`503 search_unavailable` on query. There is no honest empty result for "search
is not running" — returning `[]` would tell the diner no restaurant in Cairo
matches, which a client would happily cache.
