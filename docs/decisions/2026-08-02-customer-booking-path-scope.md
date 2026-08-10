# 2026-08-02 — What the customer booking path ships, and what it deliberately does not

**Status:** decided
**Scope:** `apps/customer_app` — Search, Venue detail, Book, Confirmation
**Reference:** `docs/design/ui_kits/app/{Search,VenueDetail,BookingFlow,Confirmation}Screen.jsx`

---

## The rule applied throughout

Where the reference draws something the platform has no data for, the element
is **omitted**, not filled with plausible content. A restaurant page that
invents its own menu prices is worse than one that has no menu section: the
first is wrong and looks right, the second is incomplete and looks incomplete.

Each omission below names the requirement it belongs to and its priority, so
"when does this arrive" has an answer rather than a shrug.

## Omitted because the data source does not exist

| Reference element | Requirement | Why not now |
|---|---|---|
| Hero photo, gallery, card thumbnails | R-2.2, P0 | No image table in the schema. `SahraPhoto` draws the reference's OWN no-image state — a mashrabiya-latticed well — so every screen looks deliberate rather than broken |
| Menu section with EGP prices | R-2.3, P0 | No menu tables |
| "Nour & 11 friends have been here" | C-3.8, P2 | No social graph |
| "Sunset offer — 20% off" | R-4.2, P1 | No promotions |
| "Featured tonight" badge | C-2.5, P1 | Editorial/paid placement has no source |
| Table number on the ticket | — | The confirm response carries no table. Allocation is the engine's business and can change before service (doc 05 §2 combination fallback); a table number on a ticket is a promise the platform has not made |

## Omitted because the feature is P1/P2

| Reference element | Requirement | Note |
|---|---|---|
| Map view, venue map card | C-2.4, **P1** | The reference's `MapCard` is Leaflet over OpenStreetMap. Flutter has no map without `flutter_map` or `google_maps_flutter`, and **neither is in the doc 08 stack table**. Adding a dependency for a P1 feature during a P0 build is the wrong trade |
| "Notify me" bells on sold-out slots | C-3.6, **P1** | `/waitlists` does not exist, so a bell would be a promise nothing keeps. `Env.enableWaitlist` gates it |
| Collections / Lists / Events chips | C-2.5 P1, events P2 | A chip that filters nothing is worse than an absent one. Only `Tonight` ships, wired to the real availability filter |
| Add to calendar, Invite friends | C-3.7 / C-3.8 | A button that does nothing is worse than no button |

## Built, and not in the reference

**`GET /v1/restaurants/:idOrSlug`** — doc 06 §3 specifies it; it did not exist.
Without it a "restaurant detail" screen has to invent a description, an
address, opening hours and a phone number, because search returns a teaser and
availability returns times. Test-first: `test/public-restaurant.e2e-spec.ts`.

Two behaviours there are security, not presentation:

- A venue that is not `active` is **404, never 403**. A 403 confirms the row
  exists, which turns the endpoint into an enumeration oracle for competitors'
  unlaunched venues.
- **No authentication.** Guest browsing to the booking button is C-1.6.

It is **snake_case on the wire**, matching the search result item in the same
doc section rather than the camelCase the owner endpoints use. These two
responses describe the same entity — a diner tapping a search result lands on
this — and a client that switches naming convention halfway through one concept
needs two mappers for one restaurant. The wider camel/snake inconsistency in
the API is real and is NOT made worse by this; splitting the one entity that
appears in both shapes would be.

## Known gaps, stated rather than hidden

**`neighborhood` is not bilingual.** It is a single `VARCHAR(80)`, so the
database holds one spelling and it is the Latin one — `Zamalek` appears on a
fully Arabic screen. CLAUDE.md rule 5 is *bilingual by column*
(`name_en`/`name_ar`); this column predates that. The client does NOT paper
over it with a lookup table: a hardcoded list of Cairo neighbourhoods in the
app would drift from what owners actually type. **The fix is a migration to
`neighborhood_en` / `neighborhood_ar`**, plus seed, search-doc, both response
DTOs and the Flutter mapping. Not done here; it is a schema change and this was
a screen task.

**"Tonight" uses the device's date.** The API wants `YYYY-MM-DD` in the
restaurant's timezone, and the client cannot know that before it has searched.
For an Egypt-first app the device is on Africa/Cairo and the two agree; a diner
searching from Europe at 23:30 asks about the wrong day. The correct answer is
a server-side `tonight` filter. Noted rather than faked, because guessing a
timezone is precisely how the 2–3 hour Cairo error gets in.

**Booking REQUIRES an account** — decided 2026-08-02, C-1.6.

Browsing stays fully open: search, venue detail and real availability need no
token. The wall goes up at the booking ACTION and not before it, so a guest can
see exactly what they would be signing up for.

Why an identity is not optional: without one the diner cannot see the booking
again, cannot cancel it, and cannot be told when the venue cancels — the
CANCEL-1 notice has nobody to reach. Neither we nor the restaurant can tell a
repeat diner from a serial no-show, and "is this guest a regular?" is one of
the things venues are actually buying. Sign-up is phone + OTP, about thirty
seconds; that is the friction accepted for the whole customer relationship.

**The client half is a returning-user flow, not just a gate.** A guest who taps
a slot must go to sign-in and come back TO THAT SAME SLOT, with their date and
party size intact. Losing their place turns a thirty-second sign-up into an
abandoned booking. Built with the sign-in screen; round trip asserted there.

Walk-in and phone bookings (R-3.2) stay anonymous — they enter through
`WalkInsService`, not this controller, and the constraint below exempts them by
source rather than by making the column nullable-and-hoped-for.

**Paging is not wired.** `next_cursor` is carried into the domain and unused.
Page two has **not** been availability-filtered (the post-filter covers the
first page only), so "load more" needs a decision about what the results mean
before it needs code.
