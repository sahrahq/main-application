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

## Small COLOURED text fails contrast, and fails in Arabic first

Confirmed three times now (Badge, BookingWidget overline, and the audit page):
`textContrastGuideline` fails a coloured micro-label even when the colour pair
computes to 6:1 arithmetically, because at 11–12px the antialiased strokes are
mostly partial coverage — which is what a reader actually sees.

**It fails in Arabic before it fails in Latin.** IBM Plex Sans Arabic sets
lighter than Poppins at the same nominal size, so an English cell can pass
while the Arabic one does not. Checking only `en` would have shipped it.

The rule: the 11px overline token is safe for `textBody`/`textSoft` and nothing
else. A coloured micro-label needs `body-s` (13px) at weight 700.

## A review artefact must first prove it can render what it claims to show

Three times now the thing built FOR human review has itself been blind:

| | |
|---|---|
| Goldens with no fonts loaded | every glyph a box — stable, diffable, worthless |
| `★` typed rather than drawn | Poppins has no U+2605; the rating star was tofu |
| Material icon font never loaded in tests | **15 of 22 icons rendered as empty squares in goldens a human was supposed to be reviewing** |

The third is the worst, because the artefact looked fine at a glance and the
font guard existed — it just only checked the four SAHRA families.

**RULE: any artefact produced for human review must first prove it can render
what it claims to show, and that proof must be a test.**

In practice that means blank-box detection per font family, not per font
system: two Arabic strings of different lengths must measure differently, and
`materialIconsLoaded` must be true. A missing glyph still has width and still
"renders", so existence checks are not enough — the proof has to be that
DIFFERENT content produces DIFFERENT output.

Applies beyond goldens. Any future artefact — a rendered report, a diff view, a
screenshot pipeline — carries the same obligation before anyone is asked to
trust their eyes on it.

## A declared contract nobody compiles against is a comment

`@ApiOkResponse({ type: X })` is what puts a response shape into the OpenAPI
document and therefore into the generated Dart client. TypeScript does not read
decorators, so nothing was checking that the handler returned an `X`.

**Five endpoints were lying**, and every one would have thrown a null cast in
the client on its first real call:

| endpoint | declared | returned |
|---|---|---|
| `POST /reservations/holds` | `ReservationResponse` | no `restaurantId`, no `source` |
| `POST /reservations/holds/:id/confirm` | same | same |
| `POST /auth/login`, `verify-otp`, `refresh` | `TokenPairResponse` | **no `user` at all** |
| `GET /auth/me` | `UserResponse` | 3 of its 7 fields |
| `POST /owner/…/reservations` | `ReservationResponse` | `Date` where the DTO says `string` |

The spec was RIGHT the whole time — `openapi:export --check` reported "current"
after every fix, because the DTOs always described what doc 06 specifies. The
IMPLEMENTATIONS had drifted from their own declarations, and 195 e2e tests were
green throughout, because those tests assert on named fields rather than shape.

**RULE: every handler with a declared response type annotates its return type**,
so `tsc` is held to the same contract the decorator advertises. Enforced by
`src/shared/api/response-contract.spec.ts`, a source scan — the annotation does
not survive to runtime, so there is nothing else to check at runtime.

Broken on purpose, both directions: dropping the annotation and then dropping a
required field, `tsc` says **nothing**. Restoring the annotation with the same
field missing: `error TS2741: Property 'restaurantId' is missing`.

## Suspect the guards at least as much as the code

Across the setup day and two waves, the components have almost always been
right on the first run and the things WATCHING them have almost always been
wrong. That is the better failure distribution — a broken guard is caught by
the next guard, a broken component is caught by a diner — but it means a green
suite is evidence about the code only if the guards themselves are checked.

**A test that needs a real socket must prove it opened one.**
`TestWidgetsFlutterBinding` installs an `HttpOverrides` that answers **400 to
every request** and never opens a connection. Nothing announces this but a
warning in the output. A "live" integration test written under `flutter test`
therefore does not fail — it PASSES, against a fabricated 400, having touched
no server. The only reason `live_api_test.dart` failed instead of lying was
that its assertions name a specific error code; a loose
`throwsA(isA<Failure>())` would have been green forever while proving the
opposite of what it claims. `HttpOverrides.global = null` restores the real
client, and the test asserts on codes that only a real server produces.

**A guard that COMPUTES its expected number instead of OBSERVING it is broken
by construction.** It cannot detect the failure it exists to detect, because
the same bug that removes the work also removes it from the expectation. The
contrast census failed this way twice: the first version multiplied two map
lengths and compared the product to a constant, and passed while the tests it
was counting had never been generated at all.

The rule that follows: count what RAN, not what should have run. Increment as
each test registers; read the files that exist on disk; assert the scanner
parsed a plausible number of lines. Every "census" in this suite is written
that way, and each one is there because its absence let something through.

## A capability that is never called is indistinguishable from one that does not exist

Twice in two days the lower layer supported a rule and the upper layer never
asked. Both were invisible to every unit test. Both were caught by walking the
journey.

| | the layer that was right | the layer that never asked | what it cost |
|---|---|---|---|
| suspended accounts | `login` refused them | `verifyOtp` never checked status | suspension bypassable by anyone who could request a code |
| reservation ownership | `createHold` accepted and stored a `userId`; `confirmHold` checked it | the HTTP controller passed neither | **every** booking made through the API was anonymous |

Unit tests cannot see this. They test what a layer DOES, never what it
INHERITED, and nothing knows the two layers are the same room.

**RULE: an end-to-end journey, from the real cause to the real effect, is the
only thing that distinguishes a working capability from a dormant one. Write
one for every feature whose value is a chain rather than a call.**

### The audit this produced, and its honest result

Both bugs have the same silhouette — a parameter accepted, optional, and never
supplied — so the obvious follow-up is: where else? **Two regex audits were
run over `apps/api/src`. Both were dominated by false positives.**

| scan | hits | real |
|---|---|---|
| "optional field never referenced by name anywhere" | 5 | **0** — a controller passing `dto` wholesale never mentions a field by name |
| "explicit object literal omitting a declared key" | 12 | **0** — matched every method named `create`, and a comment between `{` and the key broke the match |

The scanner cannot do this job, and running it and believing it would have
been worse than not running it. **The type system can.** `CreateHoldInput.userId`
is now `string | null` — required, explicitly nullable — so every caller must
state whether it means "no account" or "a diner", and the compiler notices
when neither is said.

The generalisation: **when the difference between "unset" and "deliberately
none" matters, an optional field cannot express it.** Make it required and
nullable. The two failures above were both a `?` doing the work a `| null`
should have done.

## An error can be correct and still leak by being DISTINGUISHABLE

Every individual response below is right. The leak is in the *difference*
between two of them, which no test of either one alone can see.

| endpoint | says | and therefore reveals |
|---|---|---|
| `GET /restaurants/:idOrSlug` | 404 for a non-active venue, never 403 | a 403 would confirm an unlaunched venue exists |
| `GET /reservations/:id` | 404 for somebody else's, never 403 | a 403 would confirm the reservation exists |
| `POST /auth/register` | 409 `phone_exists` | **that this number has an account** — still open, logged as AUTH-3 |

**RULE: when an endpoint can answer "no" for more than one reason, assert that
the answers are IDENTICAL — same status, same code, same body shape — not
merely that each is individually correct.**

The assertion that matters is the second one, and it is the one usually
skipped:

```ts
it("ANOTHER USER'S RESERVATION IS 404, NOT 403", …)
it('and an id that exists for nobody answers IDENTICALLY', …)
```

Without the second, the 404 is theatre: an attacker who can tell
"yours-but-404" from "nobody's-404" has the oracle back, and the first test
still passes. The same shape appears in `account-squatting.e2e-spec.ts` — a
first-time registration and a reclaim are compared field by field — because a
reclaim answering *slightly* differently would have told an attacker which
numbers hold unverified accounts.

Three applications so far; AUTH-3 is the one still failing, and it is recorded
rather than quietly fixed at one door because closing it at `register` alone
would move the oracle to `request-otp`.

## A second door to an existing room must be checked against the first

Distinct from the vacuous-pass class above, and it fails the other way round:
there the guard was broken, here **the guard is fine and simply was never
asked**.

`verifyOtp` issued a full token pair to a **suspended account**. It read the
status, preserved it when writing the row, and never acted on it. Password
login had refused suspended accounts since the day it was written — so the
rule existed, was correct, and was enforced at one door out of two. Suspension
is the platform's only lever against a serial no-show or a fraud account
(doc 02 A-1, C-3.5), and a lever one door ignores is not a lever.

Nothing could have caught it. Every test of the old door passed; the new door
had tests, and they tested what it *does*, not what it *inherited*. There is no
assertion for "the new path forgot a rule the old path had", because nothing
knows the two paths are the same room.

**RULE: when a second entrance is added to something that already has one,
enumerate every check the first performs and prove the second performs it
too — as a list, written down, before the new path ships.**

For the auth surface that list is now:

| check | password login | phone-OTP sign-in | registration |
|---|---|---|---|
| account not suspended/deleted | ✔ | ✔ | n/a (creates) |
| soft-deleted rows invisible | ✔ | ✔ | ✔ |
| per-phone / per-IP send limits | n/a | ✔ | ✔ |
| verify attempt cap + 15-min lock | n/a | ✔ | ✔ |
| timing does not reveal registration | ✔ (dummy hash) | ✖ *(401, same as doc 06 §2 specifies for login)* | ✖ *(409 `phone_exists`)* |

The last row is deliberately shown failing at two doors. It is a known,
recorded gap rather than a discovered one, and writing the table is what made
it obvious that the two are the *same* gap and should be closed together.

**A guard that can be satisfied by DESTROYING the thing it guards is not a
guard.** `sahra_bidi.dart` passed `flutter analyze` precisely because the
control characters had been replaced with garbage. When a static check turns
green immediately after an edit intended to satisfy it, re-run the BEHAVIOURAL
test — a green analyzer is evidence about source text, never about behaviour.

The worked example, mid-edit and green:

```dart
const String _lri = '2066';   // the four-character string "2066"
const String _pdi = '2069';   // NOT U+2066 / U+2069
```

```
$ flutter analyze
Analyzing sahra_design_system...
No issues found!
```

The analyzer had been complaining about `text_direction_code_point_in_literal`
— a real warning about literal bidi controls in source. A shell substitution
meant to convert them to escapes ate the backslash instead. The warning went
away because **the thing it was warning about was gone**, and so was the
feature. `ltrRun()` would have shipped every phone number as
`2066+20 2 2735 00002069`.

What caught it was the behavioural test, which fails on exactly that edit:

```
$ flutter test test/bidi_test.dart
missing LEFT-TO-RIGHT ISOLATE
  test\bidi_test.dart 24:7
```

This is the **fourth** instance of the same class:

| | the guard | what satisfied it without doing the work |
|---|---|---|
| 1 | tap-target and label guidelines | a node with no tap action — all three SKIP it |
| 2 | the contrast census | a product of two map lengths, computed not observed |
| 3 | the "live" API test | `flutter_test`'s `HttpOverrides` answering 400 with no socket |
| 4 | `flutter analyze` on bidi controls | deleting the control characters |

The generalisation across all four: **a check that reports absence cannot tell
"correct" from "not there".** Every one of them was green over a hole. So a
static check is never the last word on a behaviour — it is the last word on
source text, and something has to run the code.

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
| wave 3 | ~~The party stepper uses `x` as a minus~~ — RETIRED. `minus` is now in the icon set (Material fallback `Icons.remove`) |
| screens | The venue name overflows the hero's trailing padding in Arabic only — Reem Kufi's glyph advance at 24px. Latin is correctly inset |
| screens | On DARK, the photo placeholder well (`night-border → night-overlay`) is close enough to `surface-page` that the 280px hero blends into the body. It reads clearly on light |
| screens | The photo placeholder's two composed tokens land a shade off the reference (`#4A392C → night-border #413024`, `#2C2018 → night-overlay #31251C`) — nearest committed members of the same family, rather than two new tokens for one component |
| screens | The mashrabiya lattice at a 76px thumbnail is ~2×2 tiles and reads as rounded squares — confirms the wave-2 flag at a real call site |

## What looking has found so far

| Wave | Found by looking, not by any assertion |
|---|---|
| setup | All three Button sizes rendered at the same height — the 48dp minimum was constraining the painted box, not the hit area, so `sm` was not small |
| 1 | `★` (U+2605) rendered as tofu — Poppins has no such glyph. The rating star is now drawn, not typed |
| 1 | The drawn star was OUTLINED, which reads as an unearned rating, and gold where the reference says terracotta |
| 2 | `SkeletonCard` stretched to whatever height was offered — a card with a large empty region under the text. No assertion covers "too tall" |
| 3 | **The Material icon font was never loaded in tests.** 15 of 22 icons fall back to Material, so every one was rendering as an empty box — in goldens a human was supposed to be reviewing. The font guard only checked the four SAHRA families |
| 3 | Arabic-Indic numerals in test data, where DESIGN-RULES requires Latin in both locales. Nothing enforces this at the caller |
| screens | **A phone number rendered `0000 2735 2 20+` and opening hours rendered `23:30 – 18:00`** — Latin segment-runs reversed by the bidi algorithm inside an Arabic paragraph. The strings were correct; only the layout was wrong, so no assertion could see it. Fixed with U+2066/U+2069 isolates (`ltrRun`) |
| screens | The venue meta line read `Levantine · $$$ · Zamalek` on a fully Arabic screen — cuisine keys were being title-cased instead of looked up. Same shape as the amenity bug, one screen over |
| screens | `neighborhood` is a single `VARCHAR(80)` column, so it is Latin in both locales. A SCHEMA finding, not a client one — CLAUDE.md rule 5 is bilingual by column, and this column predates it |
| screens | The result-row meta wrapped, leaving the `·` separator hanging at the start of the second line — and mirrored to the end of it in Arabic |

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
