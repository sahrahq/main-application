# SAHRA Flutter — Engineering Standards

**Status:** proposed, awaiting sign-off
**Applies to:** `apps/customer_app`, `apps/management_app`, `packages/sahra_design_system`
**Read with:** `docs/blueprint/07-flutter-architecture.md` (the architecture decision),
`docs/design/DESIGN-RULES.md` (the visual contract), `CLAUDE.md` (both, condensed)

---

## Why this document exists

Nobody is going to review this code line by line. So a rule that depends on
someone remembering it is not a rule — it is a hope. Every standard below is
either **enforced by a test, a lint, or the compiler**, or it is explicitly
marked as one a human has to hold.

Each section states its enforcement in a fixed shape:

> **Enforced by:** …
> **Cannot be enforced:** …

The second line is the important one. A standard that claims total automation
is lying, and the parts it cannot check are exactly where defects will live.

Nothing here is built yet. This is the bar, agreed before the first component,
because changing it after forty exist is a rewrite.

---

## 0. The enforcement inventory

Everything below runs in one command — `melos run verify`, or the CI job in §8.

| # | Rule | Mechanism | Strength |
|---|---|---|---|
| 1 | No hardcoded user-facing strings | source scan test | strong |
| 1 | ARB parity ar ⇄ en | test over ARB files | **total** |
| 2 | Four screen states | shared widget + source scan | strong |
| 2 | Error states are actionable | **non-nullable `onRetry`** | **compiler** |
| 3 | 4 goldens per component | registry coverage test | **total** |
| 4 | 44pt targets, labels, contrast | `flutter_test` accessibility guidelines | **total** |
| 4 | 200% text scale | render test, overflow throws | strong |
| 5 | No hardcoded colours/spacing/radii | source scan test | strong |
| 6 | Layer dependency rules | import scan test | **total** |
| 6 | One state library | banned-import test | **total** |
| 7 | Every backend code has a message | scan API source ⇄ ARB | **total** |
| 7 | Offline handled | **sealed class exhaustiveness** | **compiler** |
| 8 | analyze clean, tests green | CI, fatal-infos | **total** |

"Strong" means a source scan that catches the shape people actually write.
"Total" means it cannot be evaded without deleting the test.

---

## 1. Localization from day one

**Arabic is the primary locale. English is second.** Not "supported" —
primary. `supportedLocales.first` is `ar`, which is what Flutter falls back to
when the device locale matches nothing.

**No user-facing string literal appears in a widget. Ever.** All copy lives in
`lib/localization/app_ar.arb` and `app_en.arb` (doc 07 §3), reached through
the generated `AppLocalizations`.

Copy is not invented. It is pulled from the design references
(`docs/design/ui_kits/app/*.jsx`), which carry both languages
(DESIGN-RULES.md).

### Numerals

Prices, ratings, times and party sizes use **Latin digits in both locales**
(DESIGN-RULES.md: "Numerals stay Latin for prices/ratings"). Use
`SahraTypography.numeric(style)`, which already pins the Latin face and tabular
figures. Formatting is the caller's job — `NumberFormat` with an explicit
`'en'` locale, never the ambient one.

> **Enforced by:** `test/i18n/no_hardcoded_strings_test.dart` — scans every
> `.dart` file under `lib/`, strips comments, and fails on a string literal
> passed to a user-facing position: `Text(...)` first positional,
> `label:`, `labelText:`, `hintText:`, `helperText:`, `errorText:`, `title:`,
> `subtitle:`, `tooltip:`, `semanticsLabel:`, `content:`.
> Plus `test/i18n/arb_parity_test.dart` — every key in `app_en.arb` exists in
> `app_ar.arb` and vice versa, no value is empty, and no Arabic value is
> byte-identical to its English counterpart (which is how an untranslated
> placeholder ships).
>
> **Cannot be enforced:** whether the Arabic is *good* Arabic. A machine can
> prove a key exists and differs; it cannot prove it reads naturally to a Cairo
> diner or matches the warm-host voice in DESIGN-RULES.md. **A native speaker
> must review the ARB files before launch.** Nor can a source scan catch a
> string assembled at runtime (`'Table ' + n.toString()`) — the scan sees no
> literal in a flagged position. Treat concatenation into user-facing text as a
> code smell; the reviewer is the only guard.
>
> **Escape hatch:** `// i18n-exempt: <reason>` on the line above. CI prints the
> total count of exemptions on every run, so growth is visible rather than
> quiet.

---

## 2. Four states, one pattern

Every screen that loads anything implements **loading, empty, error, content**.
Not three. DESIGN-RULES.md already requires this ("No screen ships without all
three" — plus content), and the design package supplies the visuals: `Skeleton`
with mashrabiya shimmer for loading, `EmptyState` with lattice for empty.

The pattern is defined **once**, in `shared/widgets/sahra_async_view.dart`:

```dart
SahraAsyncView<List<Restaurant>>(
  value: ref.watch(searchResultsProvider),
  onRetry: () => ref.invalidate(searchResultsProvider),   // required
  isEmpty: (r) => r.isEmpty,
  empty: (context) => EmptyState(...),
  content: (context, restaurants) => ...,
);
```

Three properties of this signature matter more than its convenience:

- **`onRetry` is non-nullable.** An error state with no way forward is a dead
  end, and a dead end is now a *compile error* rather than a review comment.
  That is the strongest enforcement available and it costs nothing.
- **`isEmpty` is required** for collection types. Otherwise "empty" silently
  renders as content — an empty list under a heading, which reads as breakage.
- **Loading is skeleton-shaped, not a spinner.** The design package's
  `Skeleton` mirrors the content it is replacing, so the screen does not jump.

An error state shows a **bilingual message from the failure mapper (§7)**, never
an exception's `toString()`.

> **Enforced by:** `test/architecture/async_view_test.dart` — scans
> `features/**/presentation/**` and fails on a raw `.when(`, `.maybeWhen(`, a
> bare `CircularProgressIndicator`, or `AsyncValue` pattern-matched anywhere
> other than inside `SahraAsyncView`. Plus the compiler, via `required
> VoidCallback onRetry`.
>
> **Cannot be enforced:** whether the empty state is *helpful*. A test can
> prove `EmptyState` was rendered; it cannot prove the copy tells a diner what
> to do next instead of saying "No results". Judgement stays human.

---

## 3. Golden tests — 4 per component

**Every component in `sahra_design_system` ships four goldens:**

| | Light | Dark |
|---|---|---|
| **العربية (RTL)** | ✔ | ✔ |
| **English (LTR)** | ✔ | ✔ |

This is the mechanism by which visual quality is reviewed without reading code,
so it is not optional and it is not sampled.

One helper generates all four from one call:

```dart
goldenMatrix('Button/primary', (context) => SahraButton(label: ..., onPressed: () {}));
// → goldens/button_primary.ar.light.png, .ar.dark.png, .en.light.png, .en.dark.png
```

Components with meaningful variants (Button primary/secondary/ghost/disabled,
Badge by tone, Skeleton by shape) get a matrix **per variant**, named in the
same scheme.

### The trap that makes goldens worthless

Flutter's test renderer has no fonts by default and draws every glyph as a
box. Goldens taken that way are stable, diffable, and prove nothing — worse,
they would hide the exact bug the font work in `f9a6283` fixed.

`test/flutter_test_config.dart` therefore loads the bundled families
(Poppins, IBM Plex Sans Arabic, Reem Kufi, Newsreader) before any test runs. A
guard test asserts a rendered Arabic string is **not** blank-box width, so a
regression in font loading fails loudly rather than silently.

Goldens are generated and compared **on CI's Linux container only** — font
rasterization differs across platforms, and a macOS-generated golden will fail
on Linux for reasons that have nothing to do with the design.

> **Enforced by:** `test/golden/golden_coverage_test.dart` — reads the
> component registry (every widget exported from
> `sahra_design_system/lib/src/components/`) and fails if any lacks four golden
> files, or if a golden file exists with no owning component (a rename left
> orphans). CI runs goldens without `--update-goldens`, so a pixel change is a
> failure.
>
> **Cannot be enforced:** whether a golden is *correct*. The machine catches
> *change*, never *wrongness* — the first version of every golden must be
> eyeballed by a human, in both locales, once. After that it is a ratchet.
> Goldens also say nothing about animation, scroll behaviour, or gesture
> response.

---

## 4. Accessibility

Four requirements, three of which Flutter can check natively.

**Touch targets ≥ 44pt.** `SahraRules.minTouchTarget` exists and is already
wired into every button theme. Use it; never write `44`.

**Semantic label on every interactive element.** An icon-only button with no
label is invisible to a screen reader — and SAHRA is icon-heavy (custom 1.6px
line set, no text labels on the tab bar).

**Contrast.** The palette is warm and low-contrast by design; `ink-faint` on
`cream-card` is exactly the kind of pairing that looks refined and fails WCAG.
Checked rather than assumed.

**200% text scale must not break the app.** Egyptian users on mid-range
Androids run large text more than the average. A screen that overflows at 2×
is broken for them, and overflow is silent in release builds.

> **Enforced by:** `test/a11y/guidelines_test.dart` — for every component and
> every key screen, `await expectLater(tester, meetsGuideline(...))` against
> `androidTapTargetGuideline`, `iOSTapTargetGuideline`,
> `labeledTapTargetGuideline` and `textContrastGuideline`. These ship in
> `flutter_test`; no dependency is added.
> Plus `test/a11y/text_scale_test.dart` — renders each key screen under
> `MediaQuery(data: ...copyWith(textScaler: TextScaler.linear(2.0)))` in both
> locales and asserts `tester.takeException()` is null. A `RenderFlex`
> overflow throws in debug, so this catches it.
>
> **Cannot be enforced:** whether a semantic label is *meaningful*
> (`labeledTapTargetGuideline` accepts "button"), the **order** a screen reader
> traverses, focus management across navigation, or contrast of text drawn over
> a photograph — `textContrastGuideline` cannot evaluate that and skips it.
> **A manual TalkBack/VoiceOver pass on the booking flow is required before
> launch** and is not replaceable by any test here.

---

## 5. Zero hardcoded design values

The design system is the only source of colour, spacing, radius, elevation and
type. This already holds inside `sahra_design_system`; the same scanner must
cover the apps.

Banned in `lib/`: `Color(0x…)`, `Colors.*`, `Color.fromARGB/RGBO`, a bare
number inside `EdgeInsets*`/`BorderRadius*`/`Radius.circular`/`SizedBox`, and
any `fontFamily:` string. Also banned, for RTL: `EdgeInsets.only(left:/right:)`,
`EdgeInsets.fromLTRB`, `Alignment.centerLeft` and friends, `BorderRadius.only`.

The existing `no_hardcoded_values_test.dart` is promoted out of the design
system into `packages/sahra_lints/` (a plain Dart package, no dependencies) and
invoked by each app's test suite, so all three surfaces share one definition of
the rule.

> **Enforced by:** `packages/sahra_lints` source scanner, run from every
> package's test suite. `lib/src/generated/**` is the only exempt path.
>
> **Cannot be enforced:** a value laundered through a variable —
> `const brand = 0xFFC64A2B;` in one file, used in another. The scanner also
> bans bare `0xFF…` int literals to narrow this, but a determined developer can
> still route around it. It also cannot tell a *correct* token from a *wrong*
> one: using `surfaceSunken` where the reference says `surfaceCard` is a golden
> diff, not a lint.

---

## 6. State management and structure

**Riverpod 2 with codegen. Clean Architecture, feature-first, MVVM inside each
feature.** This is not a fresh decision — doc 07 §1 and §3 already made it, with
the comparison against MVC/MVP/MVVM/Bloc written out. Restating it here so the
enforcement has something to point at:

- **Riverpod over Bloc** because it unifies DI and state in one graph,
  `AsyncNotifier` maps exactly onto the four states in §2, auto-dispose
  prevents the leaks a marketplace app accumulates, and test overrides are one
  line (doc 07 §3, §5).
- **Clean Architecture** because the domain layer stays pure Dart — the
  booking state machine is the highest-risk logic in the product and must be
  unit-testable without a widget tree (doc 07 §4 targets ~100% on it).
- **Feature-first** so `restaurants/`, `reservations/`, `owner_console/` can be
  worked in parallel without merge collisions.

Structure is doc 07 §2 verbatim. **Do not invent a variant.**

doc 07's own pragmatic rule stands: trivial CRUD screens may call repositories
directly and skip a formal use-case class. **The rule that does not bend is
"domain logic never lives in widgets."**

> **Enforced by:** `test/architecture/layers_test.dart` — parses imports and
> fails when: `domain/` imports anything from `package:flutter`, `data/` or
> Riverpod; `presentation/` imports `data/` (it may only see `domain/`); or a
> feature imports another feature's internals rather than its `domain/`.
> Plus `test/architecture/banned_imports_test.dart` — `flutter_bloc`,
> `get_it`, `provider`, `mobx`, `redux` are compile-time absent and
> import-time banned, so "just this once" cannot start a second system.
>
> **Cannot be enforced:** whether a notifier is doing too much, or whether a
> use case is genuinely domain logic rather than a pass-through. Layering is
> checkable; cohesion is not.

---

## 7. Network layer and error mapping

**Every backend error is mapped to a user-facing message exactly once, in one
file.** Not per screen. Not per feature.

The chain is fixed:

```
doc 06 §1 envelope  →  Failure (sealed)  →  failureMessage(Failure, l10n)  →  UI
{ error: { code, message, message_ar, details, request_id } }
```

- A **Dio interceptor** parses the envelope and throws a typed
  `ApiException(code, requestId, details)`. No screen ever sees a `DioException`.
- **`Failure` is a Dart 3 `sealed class`**: `NetworkFailure`, `OfflineFailure`,
  `AuthFailure`, `ConflictFailure`, `ValidationFailure`, `ServerFailure`,
  `UnknownFailure`.
- **`failureMessage()` is the single translation point**, keyed by the backend
  `code`, reading from ARB. The server's `message`/`message_ar` are a
  *fallback* for an unrecognised code, never the primary path — the client
  owns its own copy and tone.
- `request_id` is attached to every error report and shown in the error state's
  fine print, so a diner can quote it to support (§ error-envelope decision
  record).
- **`ValidationFailure` carries `details[{field, issue}]` through to the form**,
  so the offending field is highlighted rather than a banner appearing above an
  unchanged form.

### Offline is a case, not an exception

Egyptian connectivity is the reason doc 07 §3 puts Drift and an outbound
mutation queue in the architecture. Therefore:

- `OfflineFailure` is a **first-class member of the sealed hierarchy**, so
  every `switch` over `Failure` must handle it — and Dart 3 makes a missing
  branch a **compile error**. Offline cannot be forgotten; it can only be
  deliberately handled.
- Reads are stale-while-revalidate from Drift with a visible "showing saved
  results" state — not a blank error screen.
- The owner console queues mutations offline (doc 07 §3: "tonight's book must
  survive a dead router"). **The customer app does not queue bookings.** A
  booking that syncs later is a promise the engine never made — `slot_taken`
  exists precisely because availability is decided server-side, at the moment
  of the write.

> **Enforced by:** `test/network/error_code_coverage_test.dart` — extracts
> every `code: '…'` literal from `apps/api/src/**` (**43 distinct codes
> today**) and asserts each has an ARB key in both locales. A backend code
> added without client copy fails the Flutter suite. This is the one test that
> makes the two halves of the repo verify each other.
> Plus the compiler, for offline exhaustiveness.
>
> **Cannot be enforced:** whether the message is the *right* message. The test
> proves `slot_taken` has copy; only a human can judge that "That time has just
> been taken — here are three others" beats "Conflict". The scan also only sees
> literal codes in the API source; a code built dynamically would be missed
> (none are today, and adding one should be rejected in review).

---

## 8. CI

One workflow, blocking on `main` and on every PR:

```yaml
- dart run tool/generate_tokens.dart --check     # tokens.g.dart is current
- flutter analyze --fatal-infos --fatal-warnings # zero tolerance
- flutter test                                   # unit + widget + architecture
- flutter test --tags golden                     # goldens, Linux container only
- dart format --set-exit-if-changed .
- (apps/api) pnpm test && pnpm test:e2e          # the backend suite already in place
```

`analyze` runs with `--fatal-infos`. An info-level lint that is allowed to
linger is a lint that will be ignored forever.

`analysis_options.yaml` extends `flutter_lints` and additionally enforces
`prefer_const_constructors`, `require_trailing_commas`,
`avoid_dynamic_calls`, `unawaited_futures`, and
`use_build_context_synchronously` — the last one being the async-gap bug that
actually crashes Flutter apps in production.

> **Enforced by:** branch protection. If CI is not required to merge, none of
> this document is real.
>
> **Cannot be enforced:** CI proves the rules pass, not that the rules are the
> right rules. This document should be revisited once, after roughly the tenth
> screen, when it is clear which rule is carrying its weight and which is only
> generating noise.

---

## What no test in this document catches

Stated plainly, because these are where the defects will be:

1. **Arabic that is grammatical but wrong in register.** Needs a native
   speaker, once, over the full ARB.
2. **A golden that is stable and ugly.** Needs one human pass per component.
3. **Screen-reader flow.** Needs a manual TalkBack/VoiceOver run on the booking
   path.
4. **RTL that mirrors but reads wrong** — a back chevron pointing the correct
   way geometrically and the wrong way idiomatically. Goldens catch it only if
   someone looks at the `ar` variant.
5. **Whether the app feels like a warm host or a booking engine.** That is the
   product, and no assertion reaches it.

---

# Setup-day results — what breaking the guards proved

The harness was built and then deliberately broken, once per guard. **Three
real defects surfaced on day one**, all in the first component. Recording them
here because each is a standing risk for the remaining fifteen.

## The guards were not all working

**`labeledTapTargetGuideline`, `iOSTapTargetGuideline` and
`androidTapTargetGuideline` all SKIP a semantics node that has no tap action.**

`SahraButton` used `Semantics(excludeSemantics: true)`, which stripped the
InkWell's tap action along with the child's label. Consequences, in order of
severity:

1. A screen reader would announce the button and **be unable to activate it**.
2. All three guidelines skipped it and reported green. The a11y harness was
   passing on checks that never ran.

Removing the semantic label — the deliberate break — still passed, which is
how this was found rather than shipped.

**The standard now has a guard on the guards.** `a11yMatrix` walks the
semantics tree and asserts a tappable node exists BEFORE asserting anything
about it, so a vacuous pass is impossible. Components that legitimately have no
tap action are listed explicitly in `nonInteractiveGoldens` — listed, not
inferred, because "this one has no tap action" is exactly the excuse a broken
component would offer.

Merging matters too: the label sat on one node and the tap action on another.
`MergeSemantics` puts both on the node a screen reader actually reads.

## 44 is not enough on Android

Once the guideline was really running, `androidTapTargetGuideline` failed.
DESIGN-RULES.md says "44px minimum" — that is the **iOS** figure. Material
requires **48dp**.

`SahraRules.minTouchTarget` is now **48**. It satisfies both, the design rule
states a minimum so exceeding it is not a deviation, and Android is where most
Egyptian users are — `management_app` is Android-first per CLAUDE.md.

## The terracotta accent fails WCAG AA as text

`textContrastGuideline` measured the secondary button's label at **4.45:1** on
cream, against AA's 4.5. On the night surface it is **3.86:1**.

| pair | ratio | |
|---|---|---|
| terracotta on cream | 4.45 | ✗ |
| terracotta on night | 3.86 | ✗ |
| terracotta-dark on cream | 6.14 | ✓ |
| terracotta-light on night | 5.69 | ✓ |
| white on terracotta (primary fill) | 4.76 | ✓ |
| ink on gold | 8.98 | ✓ |

The accent is correct as a FILL behind white. It is not correct as text. A new
semantic, `accentOnSurface`, resolves to `terracotta-dark` on light and
`terracotta-light` on dark — composing existing tokens, not inventing values,
and following the precedent DESIGN-RULES.md already sets for gold ("never body
text on light — use gold-dark for text").

**This affects every component that puts accent-coloured text on a surface**,
which is most of them. Applying it is not optional.

## Two open questions for the product owner

1. **`Button.jsx` padding is off the token scale.** `sm: 8px 14px / 13px` and
   `lg: 15px 26px / 15px` — 14, 15 and 26 are not on the 4px scale and 15px is
   not in the type ramp. `md` is exact. The component currently uses the
   nearest on-scale neighbours, marked PROVISIONAL. Either add the tokens (the
   `leading-arabic` precedent) or accept the rounding — but inventing three
   tokens for one component's padding is how a scale stops being a scale.
   Goldens are cheap to regenerate once decided.

2. **`accentOnSurface` is a deviation from the reference**, which specifies
   plain `--terracotta` for secondary button text. The reference fails AA. I
   treated accessibility as the higher authority; confirm that reading.

## What the day produced

| | |
|---|---|
| `packages/sahra_lints` | shared source scanners, run by every package |
| `packages/sahra_localization` | ARB ar/en, 43 backend codes mapped, **flagged UNREVIEWED** |
| `flutter_test_config.dart` | loads all four families before any test |
| `goldenMatrix` / `a11yMatrix` / `textScaleMatrix` | one call → four cells |
| golden coverage + font guard | unpictured components and blank-box goldens both fail |
| `SahraButton` | the harness proof — 7 variants × 4 cells = 28 goldens |
| `.github/workflows/ci.yml` | analyze, format, tests, goldens, plus the API suite |

**136 design-system tests, 12 localization tests, analyze clean on all three
packages.**

### Every guard, broken on purpose

| Break | Result |
|---|---|
| Hardcoded `Color(0xFFFF00FF)` | ✗ 2 violations, `color-literal` + `color-hex-literal` |
| Removed the semantic label | ✗ "Tappable widgets should have a semantic label" |
| Tap target shrunk to 20 | ✗ "Tappable objects should be at least Size(44.0, 44.0)" |
| Deleted `errSlotTaken` from `app_ar.arb` | ✗ "slot_taken → missing ar copy" |
| Renamed a backend code to `kitchen_on_fire` | ✗ "Backend codes with no client mapping" |

The second and third only failed **after** the semantics bug was fixed. Before
that they passed — which is the single most useful thing this exercise
produced.

---

# Standing rule: LOOK at the goldens at the end of every wave

Testing has now twice found nothing while looking found a real defect. So this
is a step, not a habit:

**At the end of each wave, open that wave's goldens — all four cells — before
reporting the wave done. Say what looking found that testing did not. If it
found nothing, say that too.**

Also standing, from the same reasoning: **break at least one guard deliberately
per wave** and report the result. A guard nobody has watched fail is not known
to work.

## Cosmetic flags — noted, not fixed

Kept as a running list rather than stopping the wave for each.

| Raised | Item |
|---|---|
| wave 1 | `mezze` icon reads as a command-key glyph at 28px |
| wave 1 | `shisha` icon is hard to parse at small sizes — the hose dominates |
| wave 2 | The mashrabiya lattice reads as rounded squares below ~40px tile; the eight-point star only resolves at larger tiles |

## What looking has found so far

| Wave | Found by looking, not by any assertion |
|---|---|
| setup | All three Button sizes rendered at the same height — the 48dp minimum was constraining the painted box, not the hit area, so `sm` was not small |
| 1 | `★` (U+2605) rendered as tofu — Poppins has no such glyph. The rating star is now drawn, not typed |
| 1 | The drawn star was OUTLINED, which reads as an unearned rating, and gold where the reference says terracotta |
| 2 | `SkeletonCard` stretched to whatever height was offered — a card with a large empty region under the text. No assertion covers "too tall" |

None of these could fail a test: a missing glyph still has width, an outlined
star still renders, and a button of the wrong height still passes every
guideline.

---

# Component build order

16 components (matching CLAUDE.md), across five groups:

| Group | Count | Components |
|---|---|---|
| core | **6** | Badge, Button, Chip, Icon, Input, Skeleton |
| venue | **3** | BookingWidget, RatingStars, RestaurantCard |
| social | **3** | Avatar, AvatarStack, EmptyState |
| navigation | **2** | SearchBar, TabBar |
| brand | **2** | DiningTrail, Mashrabiya |

## The group order in DESIGN-RULES.md is thematic, not buildable

I read the actual `.jsx` sources for their imports. The dependency graph does
not follow the group order:

```
Icon        ← SearchBar, TabBar, DiningTrail, EmptyState, BookingWidget, RestaurantCard
Mashrabiya  ← Skeleton, EmptyState, RestaurantCard
Button      ← EmptyState, BookingWidget
Chip        ← BookingWidget
Badge       ← RestaurantCard
RatingStars ← RestaurantCard
Avatar      ← AvatarStack
```

**`Mashrabiya` is in `brand`, the group listed last — and three components
across `core`, `social` and `venue` depend on it.** Building strictly
core → venue → social → navigation → brand would stall on the second component.

Two more ordering facts that matter:

- **`Skeleton` and `EmptyState` are required by §2**, the four-state pattern.
  No screen can be built to standard until both exist, so they come early even
  though `EmptyState` is grouped under `social`.
- `RestaurantCard` has the deepest fan-in (4 dependencies) and appears on
  Discover, Search and Saved. It is the natural last component and the best
  proof the system composes.

## Proposed order — three waves by dependency

**Wave 1 — roots (8, no dependencies)**
`Icon` · `Mashrabiya` · `Button` · `Badge` · `Chip` · `Input` · `Avatar` ·
`RatingStars`

`Icon` and `Mashrabiya` first, together: everything else is downstream of one
or the other. This wave is also where the §3 golden harness and the §4
accessibility harness get proven on the simplest possible subjects — if the
4-golden matrix is awkward, it is far cheaper to find out on `Badge`.

**Wave 2 — one level up (5)**
`Skeleton` · `EmptyState` · `SearchBar` · `TabBar` · `AvatarStack`

`Skeleton` and `EmptyState` first in this wave, because `SahraAsyncView` (§2)
cannot be finished without them, and no screen can be built to standard until
it exists.

**Wave 3 — composites (3)**
`BookingWidget` · `DiningTrail` · `RestaurantCard`

`RestaurantCard` last, deliberately.

## Before wave 1, one setup task

The harnesses in §3 and §4 have to exist before the first component, or the
first few get built without goldens and retrofitted. Concretely:
`flutter_test_config.dart` with font loading, the `goldenMatrix` helper, the
golden-coverage registry test, the a11y guideline helper, and
`packages/sahra_lints` extracted from the existing scanner.

That is roughly a day of work that produces no visible UI, and it is the
difference between this standard being real and being a document.

---

**Nothing is built. Awaiting sign-off on the bar and the order.**
