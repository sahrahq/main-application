# sahra_api_client

Typed SAHRA API client, **generated** from the OpenAPI document the running
backend produces. Never hand-written.

```
apps/api (real controllers)
   │  pnpm openapi:export          ← boots AppModule, asks Nest for the document
   ▼
apps/api/openapi.json              ← COMMITTED. A schema change is a reviewable diff.
   │  dart run tool/generate_client.dart
   ▼
lib/src/generated/{models,api}.g.dart   ← COMMITTED. Not gitignored, not formatted.
```

## What it guarantees

Three failures, in the order they happen:

| # | Drift | Fails at | How |
|---|---|---|---|
| 1 | A controller changed, nobody re-exported | **CI** | `pnpm openapi:export --check` boots the app and diffs, printing the first differences |
| 2 | The spec changed, nobody regenerated | **CI** | `dart test` in this package regenerates in memory and diffs |
| 3 | The client changed, a screen still calls the old shape | **the compiler** | a renamed field, removed endpoint or changed type is a Dart compile error **at the call site** |

Guarantee 3 is the one this package exists for. A 404 or a null-check crash
found by a user in a screen is the failure mode being designed out.

### There is no `Map<String, dynamic>` escape hatch

`tool/generate_client.dart` **throws** on an operation whose success response
has a body with no schema:

```
POST /v1/x returns a body with no schema.
Add @ApiOkResponse({ type: ... }) to the controller. This generator will not
emit `dynamic`.
```

There is no flag to disable it, because the first endpoint that gets an
exception becomes the pattern. Adding an endpoint without a response DTO fails
the build.

The one place a map is emitted is a schema the spec itself declares as
`type: object` — `defaultTurnMinutes` is genuinely a map of party-band to
minutes. That is an honest type for a declared free-form object, not a fallback
for a missing one.

## What it does NOT guarantee

**OpenAPI describes shapes, not semantics.** A developer reading only this
client would reasonably assume the three things below are safe. They are not.

### 1. `slot_taken` must be re-checked at hold time

A slot returned by `availability` or `search` is **already stale by the time it
is rendered.** Availability is derived, never stored (doc 05 §1), and the
booking engine decides under a per-restaurant advisory lock at the moment of
the write.

Creating a hold can and will return **409 `slot_taken`** for a time the client
just displayed. That is correct behaviour, not an error condition to suppress.
Every booking flow must handle it and offer alternatives — never a silent
failure, never a retry loop that hides it.

The type system cannot express this. `createHold` returns
`ReservationResponse` and its signature says nothing about the 409.

### 2. `next_available` is a hint, never bookable

`SearchResultResponse.next_available` is a list of **local `HH:MM` strings and
nothing else.** It deliberately carries no absolute instant, precisely so no
client can pass one to a booking call.

To book, call `GET /v1/restaurants/{id}/availability` and use a slot's
`startsAt` — the absolute UTC instant. `time` is what a diner reads;
`startsAt` is what the server accepts. A client that reconstructs an instant
from `next_available` and a guessed timezone will book the wrong hour, and in
Cairo that is a 2–3 hour error depending on the date.

### 3. Search is a discovery layer, never the source of truth

`/v1/restaurants/search` is Meilisearch plus an availability post-filter over
**the first page only**. It answers "which venues match", not "what is free".

- A result WITH `next_available` had availability computed at request time —
  see (1) about how long that stays true.
- A result on page two has **not** been availability-filtered at all.
- The index can lag behind Postgres. Staleness there costs recall (a venue
  shows up late), never correctness — but a venue's rating, price or name in a
  search result comes from Postgres at request time, not from the index.

Never treat a search result as confirmation that a table exists.

## Usage

```dart
final api = SahraApi(myTransport);          // SahraTransport, injected

final slots = await api.getSlots(id: venueId, date: '2026-08-10', partySize: '2');
final hold  = await api.createHold(
  body: CreateHoldDto(restaurantId: venueId, startsAt: slots.slots.first.startsAt, partySize: 2),
  idempotencyKey: const Uuid().v4(),
);
```

`SahraTransport` is a port, not Dio. This package is pure Dart: the app
supplies a Dio-backed implementation carrying the auth, locale, retry and
idempotency interceptors from doc 07 §3, and tests supply a fake with no
socket. The transport returns the decoded JSON body and **throws** on an error
response; the app's failure mapper turns the doc 06 §1 envelope into a
`Failure` (ENGINEERING-STANDARDS §7).

## Regenerating

```bash
cd apps/api && pnpm openapi:export        # after any controller or DTO change
cd packages/sahra_api_client && dart run tool/generate_client.dart
```

Both are checked in CI. Neither output is gitignored, and
`lib/src/generated/` is excluded from `dart format` — formatting generated
output makes it differ from what the generator produced, which the drift check
then correctly reports as tampering. That one was learned the hard way with
`tokens.g.dart`.
