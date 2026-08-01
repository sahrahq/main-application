# sahra_design_system

Design tokens and theme for SAHRA. **Step 1 of the design build order**
(`docs/design/DESIGN-RULES.md`): tokens only — no components, no screens.

## tokens.json is the single source

Nothing in this package hand-copies a design value.

```
docs/design/tokens.json  ──▶  tool/generate_tokens.dart  ──▶  lib/src/generated/tokens.g.dart
   (74 light + 7 night)                                        (do not edit)
```

```bash
dart run tool/generate_tokens.dart          # regenerate after editing the JSON
dart run tool/generate_tokens.dart --check  # CI: fail if stale
```

Tokens are classified by the **shape** of their value (`#RRGGBB` → `Color`,
`16px` → `double`, `rgba(...)` → `List<BoxShadow>`, a font stack → families,
`var(--x)` → an alias to the target constant), never by a hardcoded list of
names. A token added tomorrow is picked up automatically; one whose shape the
generator cannot classify is a **hard error**, not a silent skip.

### Drift is impossible, and that is tested

`test/tokens_coverage_test.dart` enforces two things that have to hold together:

1. Every token in `tokens.json` has a value in the generated theme.
2. `tokens.g.dart` matches what the generator produces *right now*.

Without (2), (1) could be satisfied by hand-editing the generated file — which
is the drift the generator exists to prevent. It also asserts the counts
CLAUDE.md states (74 + 7), so changing them forces a deliberate doc update.

Verified by mutation: adding a token to `tokens.json` without regenerating
fails with `Tokens present in tokens.json but absent from the light theme`.

## Usage

```dart
MaterialApp(
  theme: SahraTheme.light(locale: locale),
  darkTheme: SahraTheme.dark(locale: locale),
  supportedLocales: SahraTheme.supportedLocales,      // ar first
  localizationsDelegates: SahraTheme.localizationsDelegates,
);

// In a widget:
final s = context.sahra;
Container(
  color: s.surfaceCard,
  padding: SahraSpace.inset(start: SahraSpace.s4, top: SahraSpace.s3),
  child: Text('...', style: Theme.of(context).textTheme.bodyMedium),
);
```

- `context.sahra` → the semantic colours for the current theme.
- `SahraSpace` / `SahraRadius` / `SahraElevation` / `SahraTypeScale` → the
  invariant scales.
- `SahraRules` → the few constants that come from DESIGN-RULES.md rather than
  `tokens.json` (44px touch target, motion timings). Flagged as
  not-a-token deliberately — see below.

## Dark mode is not a retrofit

Dark changes exactly **seven** tokens (`themeNight`). Everything else — the
terracotta accent above all — is shared, which is why the brand does not shift
between themes. Widgets reference semantic names (`surfaceCard`, `textBody`,
`line`), never brand values, so dark mode costs nothing per widget.

A test asserts all seven actually *differ* between themes: mere presence would
let a mis-wired override pass while dark mode quietly stayed light.

On dark, elevation is a lighter surface, not a shadow — use
`context.sahra.shadow(SahraElevation.e2)`, which returns nothing on dark.

## RTL is the default, not a special case

- `supportedLocales.first` is **`ar`**, so Arabic is what Flutter falls back to.
- `flutter_localizations` is a **required** dependency, not decoration: without
  the global delegates `DefaultWidgetsLocalizations` reports LTR for every
  locale, and an Arabic app renders left-to-right. This was caught by a failing
  test, not by inspection.
- `SahraSpace.inset(start:/end:)` and `SahraRadius.only(topStart:/topEnd:)` are
  the only spacing APIs offered. There is no `left`/`right` variant.

`test/no_hardcoded_values_test.dart` fails the build on
`EdgeInsets.only(left:)`, `EdgeInsets.fromLTRB`, `Alignment.centerLeft`,
`BorderRadius.only`, colour literals, `Colors.*`, and bare numbers in
`EdgeInsets`/`BorderRadius`/`SizedBox`. A rule nothing enforces decays on the
first busy afternoon.

## Typography

|        | UI                     | Display              | Leading |
|--------|------------------------|----------------------|---------|
| Latin  | Poppins                | Newsreader (serif)   | 1.5     |
| Arabic | IBM Plex Sans Arabic   | Reem Kufi            | 1.7     |

Sizes are identical across scripts, so switching language mid-session does not
reflow the screen. Headline weight is capped at 600. Overline is the only
uppercase style, tracked out by `.14em`.

`SahraTypography.numeric(style)` keeps prices, ratings and times on the Latin
face with tabular figures, per DESIGN-RULES.md ("Numerals stay Latin"). It
fixes the *glyphs*; callers must still format with Latin digits.

## Open items

**`SahraRules` values are not tokens.** The 44px touch target and the 150-200ms
motion band come from DESIGN-RULES.md; `tokens.json` has no equivalent. They are
declared once, in one place, rather than scattered as bare numbers - but they
are outside the generator's guarantee.

## Fonts

All four families are SIL Open Font License and ship in `fonts/` with their
`OFL-*.txt`:

| Family | Role | Form | Weights |
|---|---|---|---|
| Poppins | Latin UI | static | 300-700 |
| IBM Plex Sans Arabic | Arabic UI | static | 400, 500, 600 |
| Reem Kufi | Arabic display | variable | via `FontVariation('wght')` |
| Newsreader | Latin display | variable | via `FontVariation('wght')` |

`font-mono` is a system stack (SFMono / Consolas / Menlo) and is deliberately
not bundled.

The variable faces are declared as ONE asset each. Listing the same file under
several `weight:` keys does not interpolate the axis - Flutter selects a file,
it does not set `wght` - so the weight is applied with `FontVariation` in
`SahraTypography` instead.

`test/font_assets_test.dart` fails if a family named in `tokens.json` is not
declared in `pubspec.yaml`, if a declared asset is missing or is not a real
font file, or if a bundled family has no OFL licence. Flutter does **not** error
on an unknown family - it silently substitutes the platform font, so an Arabic
screen renders in Roboto, looks fine in a screenshot to anyone not reading it
closely, and ships.
