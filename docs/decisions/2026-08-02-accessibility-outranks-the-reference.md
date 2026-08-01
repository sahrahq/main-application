# 2026-08-02 — Accessibility outranks the design reference. The measured palette.

**Status:** Accepted — standing rule, no further approval needed per case
**Applies to:** every component and screen
**Recorded in:** `docs/design/DESIGN-RULES.md` (standing rule, top of file)

---

## The rule

> Where a reference file and WCAG 2.1 AA disagree, **AA wins. Every time,
> without asking.**

This overrides DESIGN-RULES.md's "when this doc and the HTML disagree, the HTML
wins". The reference files were drawn, not measured.

Enforced by `test/a11y/palette_contrast_test.dart`, which fails on any
text/surface pair below **4.5:1** in either theme — across the whole palette,
not component by component. Adding a token means adding a row to that matrix.

## What the rule found

Applying it once, before any screen existed, surfaced **13 failing pairs.**
Measured, not estimated:

### Before

| theme | text | surface | ratio | |
|---|---|---|---|---|
| light | text-faint | page / card / sunken | 3.48 / 3.45 / 3.16 | ✗ |
| light | warning | page / card / sunken | 2.78 / 2.76 / 2.52 | ✗ |
| light | success | sunken | 4.25 | ✗ |
| dark | success | page / card / sunken | 3.67 / 3.37 / 2.98 | ✗ |
| dark | error | page / card / sunken | 3.24 / 2.97 / 2.62 | ✗ |
| both | terracotta as text | page | 4.45 / 3.86 | ✗ |

Two of these are worth naming individually:

- **`text-faint` failed on every light surface.** It is the caption colour —
  the meta line `★ 4.8 (312) · Levantine · $$$` that appears on every venue
  card in the product. It would have shipped on every screen.
- **`warning` failed at 2.52–2.78.** `warning` is `gold-dark`, which is the
  value DESIGN-RULES.md explicitly recommends as the *readable* gold ("never
  body text on light — use gold-dark for text"). The document's own remedy did
  not meet AA.

### After

Fixes are hue-preserving: the same colour, moved in lightness until it clears
4.5 against the worst surface in its theme. No new hues, no brand change.

| token | before | after | worst ratio |
|---|---|---|---|
| `ink-faint-legible` (new) | `#8A8479` | `#706B62` | 4.51 |
| `warning` (light) | `#C48A4B` | `#8F612F` | 4.56 |
| `success` (light) | `#4C7A4F` | `#49754C` | 4.55 |
| `themeNight.success` (new) | — | `#619B64` | 4.52 |
| `themeNight.error` (new) | — | `#D9705B` | 4.55 |
| `themeNight.warning` (new) | — | `var(--gold-dark)` | 5.02 |
| `accentOnSurface` (semantic) | `terracotta` | `terracotta-dark` / `terracotta-light` | 5.58 / 4.62 |

`ink-faint` itself is **kept unchanged** for non-text use — icons and rules,
where 1.4.11 asks for 3:1, not 4.5. Only the `text-faint` alias moved.

**Token counts changed: 74 → 75 light, 7 → 10 night.** `success`, `warning` and
`error` now need per-theme values, which is why `themeNight` grew. Updated
deliberately in CLAUDE.md and in the coverage test.

## Rejected

**Loosening the threshold to 3:1 for "large text".** AA does permit that at
≥24px, and it would have made most of these pass. Rejected because a token's
job is to be usable at body size; that a component happens to draw it large is
not a property of the token, and the next component will draw it small.

**Per-component overrides.** The failure is in the palette, so the fix belongs
in the palette. Thirteen component-level exceptions would be thirteen places
to get it wrong again.

---

# Companion decision: Button padding rounds to the scale

`Button.jsx` specifies `sm: 8px 14px / 13px` and `lg: 15px 26px / 15px`. 14, 15
and 26 are off the 4px scale; 15px is not in the type ramp. `md` is exact.

**Decided: round to the nearest on-scale neighbour.**

The `leading-arabic` precedent — where a guideline value not in the tokens was
added *as* a token — **does not apply**, and the distinction matters enough to
write down so it is not re-litigated:

- **1.7 was a deliberate typographic decision.** It changes how Arabic reads,
  and Arabic needs the extra leading because dots and diacritics sit outside
  the x-height. There was intent behind the number.
- **14px, 15px and 26px are incidental CSS values.** Nothing was decided by
  them. Adding off-scale tokens to preserve them would break the 4px system
  permanently, and a scale with exceptions is not a scale.

**Condition attached and discharged:** the goldens were looked at afterwards.
The three sizes read as distinct and correctly proportioned. The rounding is
not visibly wrong at any size.

Looking did surface a different defect: all three sizes were rendering at the
same height, because the 48dp touch-target minimum was constraining the
**painted box** rather than the hit area — so `sm` was not small and the size
scale did nothing. The hit area now grows while the button stays the size the
reference asks for. That was caught by the eye, not by any assertion, which is
the argument for goldens in one sentence.
