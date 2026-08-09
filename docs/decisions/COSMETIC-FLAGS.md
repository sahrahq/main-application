# Cosmetic flags — carried, not fixed

One list, so they do not quietly become permanent.

The standing rule is to carry cosmetic issues rather than fix them mid-batch,
because stopping to chase pixel differences is how a feature batch turns into a
week. The risk of that rule is the one this file exists to remove: a carried
flag that nobody wrote down is a defect that has been silently accepted.

**Nothing here is scheduled.** Each entry says what it is, where it came from,
and what it would cost. Review this list when a UI polish pass is scheduled, or
whenever one of them starts being reported by a real diner — which is the
signal that it was never cosmetic.

| # | What | Where | Found | Cost |
|---|---|---|---|---|
| 1 | Photo placeholder is two shades off the reference — `#4A392C → #2C2018` became `night-border → night-overlay` | `sahra_semantics.dart` | wave 3 | Two new tokens, or accept |
| 2 | Saved card meta truncates to "شامي · …" in a two-column cell | `Saved/list` golden | Group C | Shorter meta, or a third line |
| 3 | Saved cards have loose bottom padding at 1× text | `Saved/list` golden | Group C | Tune the computed cell height |
| 4 | Discover has no pull-to-refresh lantern; uses the platform `RefreshIndicator` | `discover_screen.dart` | Group F | A custom indicator widget |
| 5 | Splash animates the fade and the hairline only — no mark settle, no wordmark letter-spacing, no lattice fade | `splash_screen.dart` | Group F | Animating letter-spacing rebuilds the `TextStyle` every frame |
| 6 | Splash draws the wordmark as TEXT — there is no logo asset in the repo | `splash_screen.dart` | Group F | Add `assets/logo.png`, which the reference expects |
| 7 | Onboarding's "Already with us? Sign in" wraps to two lines | `onboarding_screen.dart` | Group F | Shorter copy, or a Row that shrinks |
| 8 | The Arabic venue name on the hero touches the right edge — «ليالي لاونج» loses part of its last glyph | `Venue/*.ar.*` goldens | **Pre-existing**, seen in Group D | The display face's Arabic glyphs overrun their box; needs a `strutStyle` or a wider inset |
| 9 | A menu sheet and a reviews sheet have no visible close control — drag, scrim or back button only | `menu_section.dart`, `reviews_section.dart` | Group D | Platform-standard, but it is why both are `interactive: false` in the registry |

## Not on this list, on purpose

**Anything that fails AA.** Contrast is not cosmetic and never gets carried —
the standing rule is that AA wins over the reference without asking. The
Discover "See all" label is the most recent example: the reference sets
`--gold-dark`, gold-as-text measures 2.5–2.8:1, and it ships as
`accentOnSurface` instead.

**A rating that does not distinguish itself.** Review cards briefly drew
`SahraRatingStars(showValue: false)`, which is one star and no figure — so a
three-star review and a five-star one were the same picture. Not carried: a
control that looks like it is telling you something and is not is a defect, not
a polish item. Fixed in Group D by showing the figure.

**Anything that overflows.** A `RenderFlex` overflow is silent in a release
build, so it is a defect that the person it breaks for cannot even report. Two
were found and fixed within Group C and F rather than carried — the saved grid
at 200% text, and the Discover carousel at the same.

**Missing sections on a screen that has a reference.** Those are gaps, not
cosmetics, and they live in the class docstring of the screen that lacks them
plus `docs/decisions/2026-08-02-open-p0-gaps.md`. Discover alone is missing
four: the occasion banner, the rating prompt, events, and collections.
