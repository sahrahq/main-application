# CLAUDE.md — SAHRA (unified: technical blueprint + design system)

Claude Code reads this file automatically at the start of every session in this repo. It is the single entry point. There is exactly ONE CLAUDE.md in this repo (this one). The design package's own rules live at `docs/design/DESIGN-RULES.md` and are referenced from here — do not create a second CLAUDE.md.

---

## What SAHRA is

A Resy-class restaurant reservation platform for Egypt/MENA. Two Flutter apps, one shared NestJS backend, full bilingual Arabic (RTL) + English.
- `apps/customer_app` — diners: discover, book, waitlist, reviews, loyalty. iOS + Android.
- `apps/management_app` — restaurant owners + staff, plus a role-gated admin section. Android-first.

## Two sources of truth — read the right one

| You are building… | Read first |
|---|---|
| Anything backend: schema, API, reservation logic, auth, payments | `docs/blueprint/` (technical blueprint) — start at `docs/blueprint/00-blueprint-index.md` |
| Anything visual: a screen, a component, colors, spacing, theming | `docs/design/DESIGN-RULES.md` (design contract), then the specific screen reference in `docs/design/ui_kits/app/*.jsx` |
| How to set up / work in this repo | `DEVELOPMENT.md` at the repo root |

The blueprint tells you *what the app does and how the data works*. The design package tells you *exactly how every screen looks*. You need both for any user-facing feature.

## Non-negotiable TECHNICAL rules

1. **Never allow a double-booking.** Every reservation write goes through the three-layer prevention in `docs/blueprint/05-reservation-engine.md` (per-restaurant lock → transactional re-check → `EXCLUDE USING GIST` DB constraint). Write the concurrency stress test before building on top of it.
2. **`Idempotency-Key` is REQUIRED on any mutation that creates or commits a reservation, or issues credentials.** It is **not yet universal** — as of 2026-08-02, 3 of 25 mutations carry the header (the three that create or commit a reservation). `POST /auth/refresh` meets the requirement by a different mechanism, being replay-safe in `TokenService.rotate` rather than key-based, because the credential it would key on IS the request body. Do not read the older wording of this rule ("every API mutation is idempotent") as a description of the system: it was aspirational, it was 12% true, and the gap survived for weeks precisely *because* the rule sounded like a guarantee and nobody checked. The remaining 21 are listed in `docs/decisions/2026-08-02-open-p0-gaps.md` (IDEM-1); `apps/api/src/shared/api/idempotency-contract.spec.ts` pins both lists, so a 26th mutation cannot be added without a decision. Contract: `docs/blueprint/06-api-design.md` §1.
3. **Follow the DB schema exactly**, including index names — `docs/blueprint/04-database-design.md`.
4. **Contract-first API:** NestJS decorators generate the OpenAPI spec; Flutter models are generated from it into `packages/sahra_api_client`. Never hand-write a model that talks to the API.
5. **Bilingual by column** (`name_en`/`name_ar`); money is `NUMERIC(12,2)` + `currency` (default EGP), never floats.
6. **Admin lives inside `management_app`**, role-gated — there is no separate admin app.

## Non-negotiable DESIGN rules (full detail in `docs/design/DESIGN-RULES.md`)

1. **Colors, type, spacing, radii come ONLY from the design tokens** in `docs/design/tokens.json` (79 light + 13 night). Never hardcode a hex value or a raw pixel spacing in a widget — map tokens into the Flutter theme in `packages/sahra_design_system` and reference the theme.
2. **Every screen supports RTL** (Arabic). Use `EdgeInsetsDirectional` / `Alignment.*Start/*End` — never hardcode left/right. Test every screen in both directions.
3. **Every screen supports light AND dark mode** (the 7 night tokens define the dark overrides).
4. **Minimum 44px touch targets** on every interactive element.
5. **Match the reference precisely.** When the written rules are ambiguous, open the actual reference file (`docs/design/ui_kits/app/<Screen>Screen.jsx`) and read the real values — it is the source of pixel truth. To see it running with Light/Dark + EN/عربي toggles, open `docs/design/ui_kits/app/index.html`.
6. Copy (all user-facing text) exists in both EN and AR — pull from the design references, don't invent strings.

## Build order (do NOT jump straight to screens)

The design package build order and the technical build order compose like this:

1. **Backend core first** (Dev A): schema → auth → reservation engine (+ its concurrency test) → restaurant/admin endpoints → OpenAPI spec + generated client. Per `DEVELOPMENT.md` §11.
2. **Design foundation** (Dev B), in this exact order — same order the design system was built:
   1. **Tokens/theme** — map `docs/design/tokens.json` into `packages/sahra_design_system` (light + dark, LTR + RTL). Nothing visual is built before this.
   2. **Shared components** — build the 16 components from `docs/design/components/` (core, venue, social, navigation, brand) as reusable widgets in `sahra_design_system`. Each has a `.d.ts` declaring its exact prop contract — match it.
   3. **Screens** — build each screen from its `.jsx` reference in `docs/design/ui_kits/app/`, composing the components, wired to the real API via `sahra_api_client`. (The only HTML in `ui_kits/` is `index.html`, the live preview router — not a screen source.)

One screen per Claude Code prompt — e.g. *"Implement the Discover screen in Flutter, matching `docs/design/ui_kits/app/DiscoverScreen.jsx` exactly, per docs/design/DESIGN-RULES.md, using tokens/components from packages/sahra_design_system."* This keeps fidelity high; "build the whole app" does not.

## Feature scope reminder (MVP first)

Ship the core loop before extras: register → search → book → owner sees it. The design package includes screens for notify-me/waitlist, menu, offers, events, sharing, **loyalty**, and map — several of these are P1/P2 per `docs/blueprint/02-functional-requirements.md`. Build the screen when its feature's turn comes; don't wire loyalty or events before booking works end-to-end.

## End of every work batch — WALK THE APP, and a test that walks it for you

Added 2026-08-02, after this happened:

> Sign-in, my bookings and reservation detail were built, golden-tested in four
> cells each, accessibility-checked, viewport-checked, and shipped with **461
> passing tests**. Nothing in the app routed to any of them. There was no way to
> reach your account from anywhere in the product. It was found by the product
> owner opening Chrome.

**A screen that passes its own test and cannot be reached is indistinguishable
from a screen that does not exist.** That is the UI form of "a capability that
is never called is indistinguishable from one that does not exist"
(`docs/flutter/ENGINEERING-STANDARDS.md`), and no per-screen test can catch it,
because every per-screen test begins by constructing the screen.

Two things are now required, and neither substitutes for the other.

**(a) Walk it yourself, at the end of every batch.** Launch the app and go
through it as a diner: cold open → browse → search → tap a slot → sign in →
enter the code → see the reservation → **then find it again from the home
screen**. Screenshot every step, **in Arabic and in English**, and give the
product owner the file paths.

Not a written account of what should happen — pictures of what does. If a step
is impossible because something is not built, **that is the finding and it goes
at the top of the report**, not in a footnote. `apps/customer_app/RUNNING.md`
has the launch commands and says where the OTP code appears.

**(b) The journey test** — `apps/customer_app/test/journey/`. One automated
test from cold launch with no session to a confirmed reservation visible in the
bookings list, through the real router and the real navigation. It navigates
**only by tapping what is on screen**: no `context.go`, no route constants, no
provider pokes, no constructing a screen directly. The moment it is allowed a
shortcut it stops being able to detect a missing one.

It must fail if any screen becomes unreachable **while every individual screen
still passes its own test**. Verified by deleting the Bookings tab: 103 golden,
194 accessibility and 168 viewport tests all stayed green; only the journey
test noticed.

## When to stop and ask

- Before deviating from the committed schema, API contract, or a design token value.
- Before hardcoding any color/spacing instead of using a token.
- Before adding a dependency not in the stack table (`DEVELOPMENT.md` §2).
- Before touching reservation locking logic without its concurrency test passing.
- Before shipping a screen that isn't RTL-tested and dark-mode-tested.
