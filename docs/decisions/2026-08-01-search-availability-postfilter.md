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

## Cross-script and franco-Arabic matching

Franco-Arabic ("Arabizi") — Latin letters plus digits for the Arabic sounds
Latin has no letter for (7 = ح, 3 = ع, 5 = خ, 2 = ء) — is a **primary input
mode** on an Egyptian phone keyboard, not a fallback.

Meilisearch typo tolerance does not cover this. It operates within a script,
and even in Latin `ma7shy` → `mahshi` is two edits on a six-character word,
where Meilisearch allows one.

Both sides are therefore reduced to a shared **consonant skeleton**
(`transliterate.ts`). This is not a trick: Arabic script already omits short
vowels, so كشري carries k-sh-r and every romanisation — koshary, koshari,
kushari — carries those same consonants and differs only in the vowels nobody
agrees on.

Three things this required getting right:

- **ق is genuinely two-valued.** Cairene drops it to a glottal stop (قهوة →
  "ahwa") while the same letter is a hard k in طارق → "Tarek". Neither reading
  can be forced, so the **index stores both** and the query commits to the one
  its own spelling implies. A name without ق costs exactly one entry.
- **Digraphs need single-character tokens.** خ and a literal k+h sequence
  (قهوة) must not collide, so kh/sh/gh map to single internal characters.
- **The skeleton pass uses `matchingStrategy: 'all'`.** Meilisearch's default
  `last` drops query words from the end until something matches, which on a
  lossy key is a trapdoor: "zzz no such venue" reduces to `sc fn nhr`, relaxes
  to `sc`, and matches سوشي. A skeleton must match completely or not at all.

Skeletons live in their own `translit` attribute, ranked **last** among
searchable attributes and with typo tolerance disabled, so cross-script recall
never displaces an exact match. Query tokens shorter than two consonants are
dropped — one consonant matches half the city.

The two passes (as typed, then phonetic) are separate queries in one
multi-search round trip, because a skeleton is a *different string* from what
the diner typed; no index configuration can make "koshary" match the key `kcr`.
Literal hits are merged first.

## Outage must be visible

"No restaurants matched" and "search is broken" are different facts, and a
diner shown an empty list believes the first. Both adapters throw
**503 `search_unavailable`** on query — never `[]`.

The nastier outage is not a refused connection but a server that accepts the
socket and never answers: an un-timed `fetch` waits forever while the request
holds a worker, and the diner sees a spinner rather than an error. Every
request carries an `AbortSignal.timeout` (default 8s).

*Tests:* `THROWS 503 search_unavailable when the server is unreachable`,
`is distinguishable from a genuine zero-result search`,
`search being UNCONFIGURED also fails loudly, not silently empty`,
`does NOT hang when the server accepts the connection and never replies`.

### Known deviation: the error envelope

doc 06 §1 specifies `{ "error": { "code", "message", "message_ar", ... } }`.
There is no global exception filter in the API yet, so errors currently
serialise as a bare `{ code, message, message_ar }` with the right HTTP status.
The status and `code` are what a client branches on, so outage is
distinguishable today — but the envelope is **not** doc 06 shaped, and this
affects every endpoint, not just search. Tracked as its own task.

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
