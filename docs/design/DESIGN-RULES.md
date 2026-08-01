# SAHRA — Design Rules (for Claude Code)

> Place this file at `docs/design/DESIGN-RULES.md` in the app repo. The root `CLAUDE.md` (owned by the technical blueprint) should link here. These rules govern ALL UI work.

## What the design files are
Everything under `docs/design/` (this design package) is a **high-fidelity HTML/JSX reference** — recreate it pixel-faithfully in the app's stack (Flutter). Do not ship the HTML. When this doc and the HTML disagree, the HTML wins; read the actual file.

## Build order

> **Component order OVERRIDDEN — see `docs/flutter/ENGINEERING-STANDARDS.md`.**
> The `core → venue → social → navigation → brand` grouping below is
> THEMATIC, not buildable. Reading the actual `.jsx` imports: `Mashrabiya`
> lives in `brand` — the group listed last — and `Skeleton`, `EmptyState` and
> `RestaurantCard` all depend on it, so building strictly by group stalls on
> the second component. `Icon` is a dependency of six others. Components are
> therefore built in three dependency waves, roots first. The grouping below
> stays correct as a way to *think* about the system; it is not a build
> sequence.

1. **Tokens first** — port `docs/tokens.json` into the app theme layer (light = root, dark = `themeNight` overrides). No screen work before this exists.
2. **Components** — port `components/` (core → venue → social → navigation → brand), matching the `.d.ts` APIs.
3. **Screens** — each screen from its file in `ui_kits/app/`, composed only from ported components + tokens.

## Hard rules (never violate)
- **Colors come from tokens only.** Never hardcode a hex in screen/widget code. Semantic aliases (`surface-page`, `text-body`, `accent`, `line`…) — not raw brand values — so dark theme works free.
- **Gold `#E0A96D` is accent/celebration only** — never a background wash, never a second primary, never body text on light (use `gold-dark` for text).
- **Cream `#FDFBF7`, never pure white.** Cards on light are `cream-card #FBF6EE`.
- **Dark theme is warm brown-black `#1A1310`** with terracotta undertone — never cool charcoal. Terracotta `#C64A2B` is used unmodified in both themes.
- **Full bilingual parity**: every screen supports `dir="rtl"` + Arabic strings. Fonts switch (Newsreader/Poppins ↔ Reem Kufi/IBM Plex Sans Arabic). Numerals stay Latin for prices/ratings.
- **44px minimum hit targets** on mobile.
- **No emoji in product UI.** Unicode ★ for ratings.
- **Icons**: SAHRA custom 1.6px line set (`components/core/Icon`); Lucide only as fallback for glyphs not yet drawn.
- **Type scale**: Display 40 / H1 32 / H2 24 / H3 18 / Body 16-14-13 / Caption 12 / Overline 11 uppercase +0.14em. Headline weight max 600. Serif (Newsreader/Reem Kufi) for display + venue names; sans for all UI.
- **Spacing**: 4px scale. **Radius**: sm 8 / md 12 / lg 16 / xl 24 / pill 999. **Shadows**: warm ink-tinted only; on dark, elevation = lighter surface, not shadow.
- **Motion**: 150–200ms ease-out; press scale .98; no bounces. Signature moments per motion spec in `HANDOFF.md` (splash, confirmation, save-heart, skeleton shimmer, pull-to-refresh lantern).

## Voice
Warm host, not a booking engine. One clear recommendation. Direct second person, sentence case; UPPERCASE only for overlines/micro-labels. Meta pattern: `★ 4.8 (312) · Levantine · $$$`.

## Screen → reference file map (`ui_kits/app/`)
Splash `SplashScreen.jsx` · Onboarding `Onboarding.jsx` · Sign-in `SignInScreen.jsx` · Discover `DiscoverScreen.jsx` (chips, featured, events row, offers, pull-to-refresh, review stars) · Search `SearchScreen.jsx` (OSM map, terracotta pins) · Venue detail `VenueDetailScreen.jsx` (menu + EGP pricing, offers) · Booking `BookingFlowScreen.jsx` (notify-me bells on sold-out slots) · Confirmation `ConfirmationScreen.jsx` (perforated reservation ticket) · My bookings `MyBookingsScreen.jsx` (Watching card, share, DiningTrail) · Saved `SavedScreen.jsx` · Profile `ProfileScreen.jsx` (loyalty points strip) · Occasion `OccasionScreen.jsx`. Operator: `ui_kits/operator/OperatorDashboard.jsx`. Run `ui_kits/app/index.html` to see everything live with Light/Dark + EN/عربي toggles.

## States
Every list screen implements: loading (Skeleton with mashrabiya shimmer), empty (EmptyState with lattice), error. No screen ships without all three.
