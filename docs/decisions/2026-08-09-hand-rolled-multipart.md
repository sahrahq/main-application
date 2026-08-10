# Hand-rolled multipart, and the boundary that makes it proportionate

Decided 2026-08-09, during Group B (venue photos).

## The decision

`apps/api/src/modules/images/read-upload.ts` parses `multipart/form-data` by
hand — about sixty lines — instead of adding `multer` and
`@nestjs/platform-express`'s `FileInterceptor`.

Neither is in the doc 08 §5 stack table, and CLAUDE.md says stop and ask before
adding a dependency that is not. `sharp` and `url_launcher` were worth asking
for. A general multipart parser, for a single admin endpoint that accepts a
single field, was judged not to be.

**Accepted by the product owner, with the boundary below written into the file
as a condition of acceptance.**

## THE HARD BOUNDARY

> It handles **admin-authenticated input only** and must never be reused for an
> unauthenticated or diner-facing upload path.

The proportionality argument is **entirely a function of who can reach it**. A
hand-written parser for a binary wire format is a classic place for a security
hole — an unbounded read, an index past the end of a buffer, a boundary string
the caller chooses. The mitigation is not that this code is clever. It is that
the population who can reach it is us, and every one of them is named in a role
table.

The same source code, reachable anonymously, is a different object.

### What that forbids, concretely

- Diner review photos (C-4.4) must not call it.
- Owner photo upload (R-2.2, in `management_app`) must not call it.
- No unauthenticated route may call it, for any reason.

### And what to do instead

**When the management app needs owner-facing upload, that is the moment to
revisit the dependency** — not the moment to widen this file's role list or add
a second caller. `multer` is maintained, fuzzed, and read by thousands of
people; this is read by us.

## How the boundary is enforced rather than described

`admin-upload-parser.contract.spec.ts` pins:

1. **Exactly one non-test importer** — `admin-images.controller.ts`. A second
   `readUpload` import fails the build and forces the conversation.
2. **That controller keeps `RolesGuard`, not just `JwtAuthGuard`.** Losing the
   role guard while keeping the auth guard would let any signed-in *diner*
   reach the parser, which is precisely the population excluded — and it is a
   one-word diff.
3. **Every `@Roles(...)` in the file, exhaustively.** The parser is one handler
   away from all of them, so a widened list anywhere in that controller is
   visible here.

## Failing cleanly, proved rather than asserted

`read-upload.spec.ts` — 17 cases, all of which must produce a typed
`BadRequestException` or `PayloadTooLargeException`, never a `RangeError`,
never an unhandled rejection, never a hang, and never a silently truncated file
that decodes into a corrupt photograph:

- not multipart at all; multipart with no boundary; no `content-type` header
- an empty body; a boundary that never appears; CRLFs and nothing else
- a part truncated **mid-headers**, so there is no blank line to slice at
- a part with headers and a zero-byte body
- a form field with no filename, which must not be mistaken for a file
- a file part with no `Content-Type`, refused rather than guessed from the
  extension — guessing is how an SVG arrives named `.jpg`
- **a boundary made of regex metacharacters.** The boundary comes from a header
  the caller controls, and it is used with `Buffer.indexOf`, never in a
  `RegExp`. This case exists so that if somebody later "improves" the split to
  use a regex, the body turns into catastrophic backtracking and the test says
  so.
- a body over the limit, **refused mid-stream** — buffering two gigabytes and
  then returning a correct 413 is a denial of service with good manners
- the stream is `destroy()`ed rather than drained
- a body exactly *at* the limit, which must still be accepted
- a socket that errors mid-read

There is also a control case asserting a well-formed body parses with its bytes
**byte-identical** — deliberately using bytes that are not valid UTF-8, because
a parser that round-trips through a string corrupts real image data silently,
and every other assertion in the file would still pass.

---

# Known limit: the photo scrim is a gradient

Recorded 2026-08-09 alongside the above. **Not scheduled.**

`textContrastGuideline` cannot evaluate text drawn over an image — it has no
idea what pixels are underneath — so the venue hero, the search thumbnail and
the confirmation ticket all draw text on a photograph with no automated check
at all.

`palette_contrast_test.dart` now measures the worst case it *can* measure: the
brightest possible photograph, pure white, under `photoScrim` at full strength.
It clears AA, and a control asserts a weakened scrim fails, so the check cannot
go quietly vacuous.

**What it still cannot see, in the engineer's words:**

> The scrim is a GRADIENT, so text placed higher in a photo gets less of it.
> The guard measures the bottom, where the reference puts the venue name. Text
> placed further up would be weaker and nothing here would notice — that
> remains a human looking at a golden, now with a bright fixture photo rather
> than a dark one.

The product owner is checking the hero on a device with a real photograph.
