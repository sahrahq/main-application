# Location — the capability, and the promise it was approved under

**Date:** 2026-08-09
**Scope:** C-2.2's distance filter, C-2.3's distance sort. **No new screen.**
**Dependency:** `geolocator`, approved after asking. Recorded in doc 08 §5.

---

## 1. Why it was a half-batch and not a feature

The API has served this since search shipped: `lat`, `lng`, `radius_km`,
`sort=distance`, and a `distance_km` on every result. Nothing on the server
changed. The whole half-batch is one plugin behind one port, one control, and
the plumbing between them.

Distance was deliberately left out of the filter sheet in Group F, for a reason
worth repeating because it is the reason this shipped in this order:

> A distance filter ranking against a location we do not have would be a
> control that quietly does nothing.

## 2. The promise

> *"Distance matters more in Cairo than almost anywhere, so I want the distance
> filter and sort, but I don't want a permission prompt in the app before
> there's a reason for one."*

That is a negative guarantee, which makes it the hard one to keep and the hard
one to test — a screen that renders correctly renders correctly whether or not
a dialog fired behind it.

**It is kept by shape, not by discipline.** `DinerLocation.build()` returns
null and asks nothing. The dialog cannot appear unless something calls
`request()`, and the filter sheet's "near me" toggle is the only caller in the
app.

**And it is checked by counting.** `location_test.dart`'s fake location source
increments a counter on every `current()` — the only method that can raise the
dialog. Two assertions read that counter as zero: after a real search has run,
and after the filter sheet has been opened. "No prompt" is an integer rather
than an intention. Verified by making `build()` ask, which fails that test by
name.

## 3. The rest of the scope, and where each clause lives

| Clause | Enforced by |
|---|---|
| One-shot position, never a stream | `GeolocatorLocationSource` is the only importer of the package and calls one method |
| Coarse accuracy — a neighbourhood, not a doorway | `ACCESS_COARSE_LOCATION` alone in the manifest, so FINE is not available to ask for |
| Asked on use | `DinerLocation.build()` asks nothing; one caller of `request()` |
| No background location | No `ACCESS_BACKGROUND_LOCATION`, no `NSLocationAlwaysUsageDescription` |
| Not stored | In memory for the session; leaves only as query parameters |

`LocationAccuracy.low` is also the faster choice — roughly a second against
several for `high`, and it does not wake the GPS radio. On a Cairo phone at 8pm
that is the difference between a filter that feels instant and one the diner
abandons. An 8-second timeout, because a location request with no timeout hangs
indoors and a spinner that never resolves is worse than "we could not find you".

## 4. Refusal is a first-class state, four times over

`LocationOutcome` has four failure values and the sheet has four sentences,
because three of them cannot be fixed by tapping again:

- **`denied`** — declined this time. Asking again is legitimate.
- **`deniedForever`** — the OS will not show the dialog again. "Try again"
  would be an instruction that cannot work, so the copy points at the phone's
  settings instead.
- **`serviceDisabled`** — location is off device-wide. Not about us, and not
  something a permission prompt fixes. Checked BEFORE requesting permission,
  because granting permission and then getting no position reads as the app
  being broken after the diner said yes.
- **`unavailable`** — the platform errored or timed out.

**The toggle follows the position, not the tap.** A diner who taps "near me"
and then declines gets the switch back where it was and a line saying why —
not a filter that is on, changes nothing, and has to be discovered to be
useless.

**"Nearest first" is absent until there is a position, not present and
disabled.** A disabled control invites the question "why"; an absent one is
answered by the distance filter directly above it.

`Filters/near-me` and `Filters/location-refused` are both in the screen
registry, so both states are pictured in four cells and checked at every
viewport — including 320×568 at 200% text, where the sheet is now taller than
the screen and scrolls.

## 5. What is NOT here

**No radius slider.** `kNearMeRadiusKm` is 5, fixed. The reference has no
slider, and a diner choosing between 3km and 5km in a city where a 3km trip can
take forty minutes is choosing badly with confidence. The number is a judgement,
stated as one in `search_sort.dart`: wide enough to keep Zamalek, Downtown and
Garden City in one another's results, narrow enough that "near me" is not the
whole city.

**No map.** Knowing where somebody is and drawing a map are separate decisions.
C-2.4 still has no map package and Group H is an address plus a handoff to the
phone's own map app.

**No client-side distance.** `VenueSummary.distanceKm` is whatever the server
computed. Deriving it here would need the venue's coordinates and a haversine of
our own, and two implementations of one distance is two answers on one screen.

## 6. One thing that changed underneath

The filter sheet gained two sections and became taller than the 800×600 default
test surface. Six existing tests started failing with *"derived an Offset that
would not hit test"* — which reads as a broken button and is a viewport smaller
than the sheet. Every tap in `filter_sheet_test.dart` now scrolls first, which
is also what a diner does, so the test exercises the path they take rather than
one that worked only while the sheet was short.
