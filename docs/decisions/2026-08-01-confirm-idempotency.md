# 2026-08-01 — `reservations.confirm_idempotency_key`

**Status:** accepted, implemented
**Affects:** `apps/api/prisma/schema.prisma`, reservations module

## Context

`06-api-design.md` §1 requires an `Idempotency-Key` on every mutating request,
and names holds, confirms and payments explicitly. `04-database-design.md`
gives `reservations` a single `idempotency_key UUID UNIQUE`.

Hold and confirm are two separate requests, made at different times, with
different client-generated keys. One column cannot dedupe both: a confirm
writing its key over the hold's would make the *hold* replayable, which is
precisely the operation that must never run twice — a replayed hold allocates
a second table.

## Decision

Add `confirm_idempotency_key UUID UNIQUE NULL` to `reservations`.

- `idempotency_key` → dedupes `POST /reservations/holds`
- `confirm_idempotency_key` → dedupes `POST /reservations/holds/:id/confirm`

Nullable because walk-in and phone reservations entered by staff (doc 06 §4)
never pass through a confirm step.

Replaying a confirm key returns the existing reservation unchanged. Confirming
an already-confirmed reservation with a *different* key is a
409 `invalid_status_transition`, not a silent success — the client is out of
sync and should be told.

## Note on the confirm transition itself

The state change is a single conditional UPDATE:

```sql
UPDATE reservations SET status = 'confirmed', hold_expires_at = NULL, ...
 WHERE id = $1 AND status = 'held' AND hold_expires_at > now()
```

The guard is evaluated by Postgres under the row lock, not by application code
against a value read moments earlier. `05-reservation-engine.md` §4 requires
that an expired hold can never be confirmed; a read-then-write would leave
exactly the window between the read and the write for the expiry sweeper to
land in. `affected rows = 0` then distinguishes "it lapsed" (`hold_expired`)
from "someone else moved it" (`invalid_status_transition`).

Covered by `test/booking-loop.e2e-spec.ts`, including a case that ages a hold
past its expiry *without* changing its status — the exact sweeper race.

## Consequences

- Doc 04's `reservations` table should be amended to include the column.
- Two unique indexes on `reservations` rather than one. Both are on nullable
  columns and only written once per reservation, so the cost on the hot path
  is negligible.
