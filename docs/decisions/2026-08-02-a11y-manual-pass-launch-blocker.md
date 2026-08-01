# 2026-08-02 — Screen-reader and Arabic copy passes are MANUAL. Both are launch blockers.

> ## 🚨 LAUNCH BLOCKER — DO NOT GO LIVE WITHOUT READING THIS
>
> Two quality gates in this product **cannot be automated** and are currently
> unperformed. The test suite will stay green while both are outstanding,
> which is exactly why they are written down here rather than left to be
> noticed.

**Status:** accepted, outstanding — must be discharged before launch
**Blocks:** production launch of `customer_app` and `management_app`
**Related:** `docs/flutter/ENGINEERING-STANDARDS.md` §1, §4
**Same pattern as:** `2026-08-01-otp-delivery-deferred.md`

---

## Context

`ENGINEERING-STANDARDS.md` enforces most of the Flutter bar with tests, lints
and the compiler. It also states plainly what no test reaches. Two of those
items are not "nice to verify" — they are the difference between an accessible
bilingual product and one that merely passes its own tests.

The automated checks that exist are real but shallow in a specific way:

- `labeledTapTargetGuideline` proves a label **exists**. It accepts `"button"`.
- `androidTapTargetGuideline` / `iOSTapTargetGuideline` prove a hit box is big
  enough. They say nothing about whether the control is reachable in a sensible
  order, or announced usefully.
- `textContrastGuideline` **skips** text drawn over an image, which is most of
  the venue imagery in this product.
- ARB parity proves an Arabic key exists and differs from the English. It
  cannot tell fluent Egyptian Arabic from machine translation.

A green suite therefore proves the scaffolding is right and says nothing about
whether a blind diner can book a table or whether the Arabic reads like a
person wrote it.

## Decision

### 1. Manual screen-reader pass — OWNED BY ENGINEERING

Before launch, a full **TalkBack (Android) and VoiceOver (iOS)** pass over, at
minimum:

- the booking path: Discover → Venue detail → Slot picker → Confirm
- sign-in and OTP entry
- the owner's book on `management_app`

Checking specifically what the guidelines cannot:

- [ ] Traversal **order** is reading order, in both LTR and RTL. RTL is the one
      that breaks: a visually mirrored row can still be announced left-to-right.
- [ ] Every icon-only control announces its **purpose**, not its shape
      ("Save this restaurant", not "heart button").
- [ ] Focus moves correctly across navigation, and back-navigation returns
      focus rather than dumping it at the top.
- [ ] Slot picker is operable without sight — the single highest-risk screen,
      because a mis-picked time is a wasted evening.
- [ ] Live regions announce state changes (hold countdown, "table taken").
- [ ] Text over venue photography meets contrast **measured by hand**, since
      the automated guideline skips it.

### 2. Arabic copy review — OWNED BY THE PRODUCT OWNER

The product owner is a native Egyptian speaker and has taken this explicitly.

**Working agreement, agreed 2026-08-02:**

- Engineering writes the ARB copy as a **best attempt** and marks the file
  `UNREVIEWED`.
- The review is **one full pass over the whole file**, when there is enough
  copy to judge as a body of work — tone and consistency cannot be assessed
  phrase by phrase.
- Engineering does **not** ask for approval string by string.
- The `UNREVIEWED` banner is removed only by that pass. A test asserts the
  banner is present while the file still declares itself unreviewed, so its
  removal is a deliberate act and shows up in a diff.

What the review is looking for, beyond correctness: the warm-host voice from
DESIGN-RULES.md, Egyptian dialect where the references use it rather than MSA,
and error messages that sound like a person rather than a server.

## What has to happen before launch

| # | Item | Owner | Done |
|---|---|---|---|
| 1 | TalkBack pass, booking path, ar + en | Engineering | ☐ |
| 2 | VoiceOver pass, booking path, ar + en | Engineering | ☐ |
| 3 | TalkBack pass, owner's book | Engineering | ☐ |
| 4 | Contrast of text over photography, measured | Engineering | ☐ |
| 5 | Full Arabic ARB review | Product owner | ☐ |
| 6 | Remove the `UNREVIEWED` banner | Product owner | ☐ |

## Alternatives rejected

**"Add an accessibility linter and call it done."** The guidelines already in
`flutter_test` are the best automated checks available and they are wired up.
Adding more static analysis would raise the appearance of coverage without
touching the four things above.

**"Review the Arabic as it is written, string by string."** Rejected by the
product owner, correctly: tone is a property of the whole file. Reviewing
incrementally produces locally-fine copy that reads inconsistently as a set.

## Consequences

- The suite stays green while both gates are open. **Green does not mean
  shippable** until the table above is complete.
- This file is the record. If it is not discharged, that is a decision someone
  made, not something that was forgotten.
