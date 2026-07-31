# SAHRA Design System

SAHRA is a nightlife & dining discovery + booking app launching in Cairo: find "the vibe for tonight" — lounges, restaurants, events — and reserve a table. Consumer mobile app first (iPhone frames in the source design); bilingual Latin/Arabic.

## Sources
- `uploads/Sahra Logo.png` — cream "S" mark with crescent + star cutouts (transparent PNG, for dark backgrounds). Copied to `assets/logo.png`.
- `uploads/Screenshot 2026-07-21 112400.png` — two app screens (sign-in "Find The Vibe For Tonight"; Discover/Search with map, chips, featured venue card, bottom tabs). **The app runs on dark "Night" surfaces** — ground truth for the UI kit.
- `uploads/Poppins/` — full Poppins family (OFL). Self-hosted in `assets/fonts/`; replaces the earlier Inter placeholder.
- Colors given by Geno 2026-07-21 (Terracotta `#C85A32`, Gold `#E0A96D`, Cream `#FDFBF7`, Ink `#121212`); the terracotta was later refined to spiced-clay **`#C64A2B`** to sit warmer/redder than Resy's coral-orange. (Strategy book Ch. 2.5.1 lists an older placeholder palette — Geno's colors win.)

## CONTENT FUNDAMENTALS
- Voice: warm host, not a booking engine. SAHRA *recommends* — one clear suggestion, not a wall of options.
- Direct second person ("Find the vibe for tonight", "Book this table"), sentence case for body/buttons; UPPERCASE reserved for overlines and micro-labels (PHONE NUMBER, FEATURED).
- Short, confident lines; night-out energy without slang. No emoji in product UI.
- Bilingual: every string should read naturally in Arabic (Cairo font); numerals stay Latin for prices/ratings.
- Meta info pattern: `★ 4.8 (312) · Levantine · $$$` — middot-separated, rating first.

## VISUAL FOUNDATIONS
- **Color**: **Terracotta `#C64A2B`** (spiced-clay, redder/earthier than a food-delivery orange and deliberately distinct from Resy's coral-orange) is the single primary fast-food orange (`#FF6B35`, owned by Talabat) and not steakhouse red. Gold `#E0A96D` = premium/celebratory highlights ONLY (never a second primary or background wash). Cream `#FDFBF7` replaces pure white (white reads clinical/SaaS). Ink `#121212` for text and dark surfaces.
- **One brand, two lighting conditions**: light (warm cream) and dark have FULL parity — neither is "the premium one" — and the terracotta accent is used **unmodified** in both. The dark theme is a **warm brown-black (`#1A1310`) with a terracotta undertone**, deliberately NOT the cool charcoal of Resy/OpenTable — it reads as SAHRA firelight, not a generic reservation-app grey. Ink `#121212` stays the light-theme text color.
- **Signature design language** (what makes SAHRA unlike any competitor — deliberately NOT the Resy/OpenTable/Tock dark-editorial formula):
  - **Mashrabiya lattice** — the Cairo carved-wood screen abstracted to an eight-point-star grid; a subtle texture on image placeholders, empty states, dividers and occasion backdrops. Distinctly Cairene. (`components/brand/Mashrabiya`)
  - **Dining trail** — past visits render as a connected string of lantern-dot nodes (newest glows gold), not a flat photo grid; SAHRA's product is connected memories, not isolated bookings. (`components/brand/DiningTrail`, in My bookings · Past)
  - **Gold with meaning** — gold glow appears only at real moments: the booking confirmation, and the evening of the reservation ("Tonight" gets a gold ring). Never persistent chrome.
  - **Custom Cairo-dining icons** — one uniform 1.6px line family built from tea glass, mezze plate, lantern and shisha (plus matching UI glyphs), replacing generic library icons. (`components/core/Icon`)
- **Two surface worlds, full parity**: the app ships in both *Day* (warm cream — cards are cream-card `#FBF6EE`, never pure white) and *Night* (warm brown-black `#1A1310`→`#31251C`, terracotta undertone — never charcoal). Neither is "the premium one"; the same terracotta accent is used unmodified in both. Airbnb-warm, photography-led, broadly inviting — not gatekept. Both driven by the same semantic aliases via `.theme-night`.
- **Photography-led**: venues are shown through generous, rounded imagery. Placeholders are a single restrained warm-neutral frame with a faint image cue (not decorative multicolor gradients) — every `Photo`/`RestaurantCard` accepts a real `src`/`image`, so dropping in real venue photography is the intended finished state. Text over imagery gets a bottom protection gradient (warm ink → transparent).
- **Type**: an **editorial serif + geometric sans** pairing — the "menu" voice. **Newsreader** (serif) for headlines, venue names and hero display; **Poppins** for all UI, labels, body, buttons. Arabic gets its **own matching pairing**: **Reem Kufi** (calligraphic, distinctly Cairene) for Arabic display/headings and **IBM Plex Sans Arabic** (refined, professional, weight-matched to Poppins) for Arabic UI & body — replacing the generic Cairo so Arabic feels first-class, not a fallback. Headline weight tops out at 600, tracking −0.01em (Latin). Scale: Display 40 / H1 32 / H2 24 / H3 18 / Body 16-14-13 / Caption 12 / Overline 11 uppercase +0.14em.
- **Spacing**: 4px base scale (4–96). Generous padding; screens breathe.
- **Radius**: sm 8 / md 12 / lg 16 / xl 24 / pill 999. Chips & primary CTAs on mobile are pill or md; cards lg.
- **Elevation**: 3 warm ink-tinted shadows (no pure-black shadows). On Night surfaces elevation is mostly *lighter surface color*, not shadow.
- **Cards**: light = white, 1px `--border`, radius-lg, shadow-1; night = raised surface `--night-raised`, 1px `--night-border`, no heavy shadow.
- **Imagery**: warm, low-light photography of venues; images sit in rounded-lg containers; text over imagery gets a bottom protection gradient (ink → transparent).
- **Motion**: subtle — 150-200ms ease-out fades/slides; buttons scale 0.98 on press; no bounces.
- **Hover**: darker fill (terracotta→terracotta-dark); ghost/tertiary get tint backgrounds. Press: scale .98.
- **Transparency/blur**: none observed; overlays use solid warm darks.

## ICONOGRAPHY
- **Custom SAHRA icon set** (`components/core/Icon`) — one uniform 1.6px line hand. The signature family is drawn from Cairo dining culture: `tea` (istikan glass), `mezze` (shared plate), `lantern`, `shisha`; matching UI glyphs (search, heart, user, map-pin, clock, calendar, check, `spark`, etc.) share the same weight so the whole app reads as one voice. `spark` is the gold/celebratory glyph. Unknown names fall back to Lucide (CDN) — those rare fallbacks are ~2px and slightly heavier; flagged so they can be drawn into the custom set later.
- The logo has two variants: `assets/logo.png` (cream, for dark/terracotta surfaces) and `assets/logo-terracotta.png` (terracotta `#C64A2B`, for light surfaces). Onboarding and SignInScreen pick automatically based on theme.On light surfaces, use the typed SAHRA wordmark.
- Unicode ★ is used for ratings; no emoji.

## Index
- `styles.css` → `tokens/colors.css`, `tokens/typography.css` (@font-face Poppins + Cairo import), `tokens/spacing.css`
- `assets/` — logo.png, fonts/ (Poppins TTFs + OFL)
- `guidelines/` — foundation specimen cards (Design System tab)
- `docs/` — developer handoff: tokens.json (light + night), HANDOFF.md (component APIs, theming, motion specs, feature notes), DESIGN-RULES.md (implementation rules for Claude Code — goes in the app repo)
- `templates/` — consumer starting points: discover, search, venue-detail, booking, confirmation, operator, reminder-email
- `components/` (each: .jsx + .d.ts + .prompt.md; one card html per directory)

### Components
- `core/` — Button, Chip, Badge, Input, Icon, Skeleton/SkeletonCard (mashrabiya shimmer loading)
- `venue/` — RestaurantCard, RatingStars, BookingWidget
- `social/` — Avatar, AvatarStack, EmptyState
- `navigation/` — TabBar, SearchBar
- `ui_kits/operator/` — OperatorDashboard (SAHRA for Restaurants: tonight's bookings, guest notes, floor snapshot)
- `ui_kits/app/` — full consumer app (light + dark parity, EN + AR with mirror-flip toggle): SplashScreen (branded launch motion), Onboarding, SignInScreen, DiscoverScreen, SearchScreen, VenueDetailScreen, BookingFlowScreen, ConfirmationScreen, MyBookingsScreen, SavedScreen, ProfileScreen, OccasionScreen, plus Photo helper + MapCard + interactive index.html router with Light/Dark + EN/عربي toggles
- `components/brand/` — Mashrabiya (signature lattice), DiningTrail (lantern-dot memory trail)
- `SKILL.md` — agent skill entry point

## Intentional additions
- Lucide CDN icons (no brand set exists yet).
- Night-theme token scope (derived from the app screenshot, not a written spec).

## Not yet covered (v2)
AI concierge UI; loyalty program beyond the Profile points strip (tiers, redemption flow); operator analytics.

---

## Local import notes (added when importing into the SAHRA app repo)

Everything above is the design package's own README, verbatim. The notes below describe the **two** places the local layout differs from it, and are the only edits made on import.

1. **The three handoff docs are flattened one level up.** The package keeps them in its own `docs/` subfolder; here they sit at the root of `docs/design/` so the paths `CLAUDE.md` already references resolve:

   | Package path | Path in this repo |
   |---|---|
   | `docs/DESIGN-RULES.md` | `docs/design/DESIGN-RULES.md` |
   | `docs/HANDOFF.md` | `docs/design/HANDOFF.md` |
   | `docs/tokens.json` | `docs/design/tokens.json` |

   So where the Index above says "`docs/` — developer handoff", read "the root of `docs/design/`".

2. **`components/` and `templates/` stay at the root of `docs/design/`**, not under `ui_kits/`. `CLAUDE.md` originally guessed `ui_kits/components/*.html` and `ui_kits/templates/*.html`; the real package puts them at the root, `styles.css` and every `.jsx` import resolves against that, and `_ds_manifest.json` / `_adherence.oxlintrc.json` hardcode those paths. `CLAUDE.md` was corrected to match the package rather than the reverse.

Two other things worth knowing when reading the package:

- The **`_`-prefixed files are machine-generated by the Claude Design app**, not hand-authored design docs: `_ds_manifest.json` is the compiled card/token/font index (it lists all 73 light + 7 night tokens with their resolved values — the fastest authoritative reference for the Flutter theme mapping), `_ds_bundle.js` is the compiled component bundle the preview HTML loads, and `_adherence.oxlintrc.json` is the lint contract. The oxlint rules are React-specific, so they **document** the component prop contracts and the no-raw-hex / no-raw-px rule for the Flutter work rather than linting it.
- The first bullet under **VISUAL FOUNDATIONS** has a dropped clause in the source ("is the single primary fast-food orange (`#FF6B35`, owned by Talabat) and not steakhouse red"). Read it as *"is the single primary — **not** fast-food orange (#FF6B35, owned by Talabat), and not steakhouse red."* Left verbatim rather than silently rewritten; worth fixing upstream in the design project.
