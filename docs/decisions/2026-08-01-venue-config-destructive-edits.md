# Venue configuration: a config edit can never silently break a booking

**Date:** 2026-08-01
**Status:** Accepted
**Applies to:** R-2.4 (hours/shifts), R-2.5 (tables) — doc 06 §4 lines 102–103

---

## Context

The reservation engine reads `tables` and `shifts`, but nothing created them.
Every test inserted them with raw SQL, so the entire suite passed while **no
real restaurant could configure a venue at all**. That is a gap the tests
structurally could not see: the engine had its inputs, they just arrived by a
route no user has.

These two tables are also not ordinary config. A table is the thing a confirmed
reservation is *standing on*, and a shift is the only statement of when the
restaurant is open. An owner editing them can invalidate a promise the
restaurant already made to a diner — who finds out at the door.

## Decision

Every destructive edit checks for **live future bookings** first
(`held`/`pending`/`confirmed`/`seated`, `starts_at > now()`), and the platform
never resolves the conflict on the owner's behalf.

### Tables

| Edit | Behaviour |
|---|---|
| Retire (`active: false`) with future bookings | **409 `table_has_future_reservations`** — doc 06 §4 line 103 states this explicitly |
| Delete with future bookings | **409**, same code — a delete is a retirement that also destroys evidence |
| `maxCapacity` down / `minCapacity` up past a booked party | **409 `capacity_conflict_with_reservations`** |
| Widen capacity, rename, change zone/priority/combinable | Always allowed — describes the table, does not affect whether the booking can be honoured |

`DELETE` has three outcomes, because "delete" means different things:

- **future live bookings** → 409, nothing happens.
- **never used at all** → hard delete. Frees the name, which is what an owner
  fixing a typo actually wants.
- **used, but all settled** → deactivated, not deleted. Those
  `reservation_tables` rows are last month's covers; a hard delete would either
  fail on the foreign key or erase history the restaurant is owed.

Every 409 carries `affected_reservations`, `reservation_ids` and
`earliest_reservation_at` — a refusal the owner cannot act on is just an
obstacle.

### Shifts / hours

Narrowing hours past a live future booking is **refused** with
`bookings_outside_new_hours`, naming the bookings.

With `?force=true` the owner's decision is honoured: **the hours change and the
bookings are kept**, returned in `reservationsOutsideHours` so somebody can
call those guests.

**Nothing is ever auto-cancelled.** The restaurant made that promise; the
platform cannot unmake it. A diner arriving to find their confirmed booking
silently gone is worse than any amount of configuration friction. Tested
directly: after a forced narrowing, the reservation is still `confirmed` and
still holds its table allocation.

Also enforced: exactly one of `dayOfWeek` / `specificDate`; no zero-length
shifts; and **no overlapping shifts on the same day** — each shift carries its
own turn-time table, so two covering the same minute would leave the engine
picking one arbitrarily.

## A real engine bug this surfaced

`AvailabilityService.shiftFor` used `findFirst` — the grid honoured **exactly
one shift per day**. R-2.4 requires multiple ("Opening hours per weekday;
multiple shifts"), and lunch + dinner with a closed afternoon is the normal
Cairo pattern.

Shipping the config API without fixing this would have given owners a screen
where adding a lunch shift silently did nothing. `shiftsFor` now returns all
active shifts for the day and the grid is built across each — with its own turn
time, since a 90-minute lunch and a 120-minute dinner are different products.
Date-specific rows still supersede the weekly pattern entirely, or a holiday
would open the restaurant twice.

*Test:* `MULTIPLE shifts per weekday both produce slots — lunch AND dinner`,
which also asserts the gap between them stays closed.

## Explicitly NOT built: Ramadan mode

R-2.4 also specifies Ramadan mode — "iftar seating pegged to Maghrib time,
sohour slots until 3:00", auto-adjusting daily with sunset. It is **P0 and
still outstanding.**

`is_ramadan` is persisted so the data model is ready, and a test asserts the
flag round-trips *and* that it currently anchors nothing. It needs a
prayer-time source and a daily recompute of shift bounds — a different feature
from CRUD, and half-building it would produce iftar slots at the wrong hour,
which is worse than not having them.

## Consequences

- A restaurant can now be configured end to end through the API: create →
  tables → hours → submit → approve → bookable.
- Owners cannot fix a mistake that has bookings on it without dealing with
  those bookings. That friction is deliberate and is the point.
- `POST /owner/restaurants/:id/reservations` (walk-ins, R-3.2) is still
  missing, so a party seated off the platform is still invisible to the engine.
