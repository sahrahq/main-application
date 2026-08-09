/// Latin runs inside Arabic text.
///
/// FOUND BY LOOKING AT AN ARABIC GOLDEN, and catchable no other way — every
/// assertion passed, because the string was correct and only its RENDERING was
/// reversed:
///
/// | written              | rendered in an Arabic paragraph |
/// |----------------------|---------------------------------|
/// | `+20 2 2735 0000`    | `0000 2735 2 20+`               |
/// | `18:00 - 23:30`      | `23:30 - 18:00`                 |
///
/// A phone number nobody can dial and opening hours that say the venue shuts
/// before it opens. This is the "RTL that mirrors but reads wrong" failure
/// ENGINEERING-STANDARDS lists as visible only to someone looking at the `ar`
/// variant.
///
/// The cause is the Unicode bidirectional algorithm doing exactly its job: in
/// a right-to-left paragraph, a run of neutral characters (space, `+`, en-dash,
/// `:`) between numbers takes the paragraph's direction, so the segments get
/// laid out right-to-left even though the digits inside each segment do not.
///
/// The remedy is an ISOLATE, not an embedding: U+2066 LEFT-TO-RIGHT ISOLATE
/// then U+2069 POP DIRECTIONAL ISOLATE. An isolate also stops the run from
/// influencing the direction of the text AROUND it, which an embedding does
/// not — that difference is why a phone number in the middle of a sentence
/// could otherwise drag the following Arabic word to the wrong side.
library;

import 'dart:ui' show TextDirection;

/// U+2066 LEFT-TO-RIGHT ISOLATE.
///
/// Written as an ESCAPE, not as the literal character. A literal U+2066 in
/// source reorders the source line itself in any editor that honours bidi, so
/// the code would read differently from how it compiles — the same class of
/// problem this file exists to fix. The analyzer says so too
/// (`text_direction_code_point_in_literal`).
const String _lri = '\u2066';

/// U+2069 POP DIRECTIONAL ISOLATE.
const String _pdi = '\u2069';

/// Wrap [text] so it always lays out left-to-right, whatever paragraph it
/// lands in.
///
/// For anything that is a sequence of Latin-script or numeric SEGMENTS: phone
/// numbers, time ranges, addresses with house numbers, reservation codes,
/// URLs.
///
/// AND for a lone figure that carries a SIGN — `4.0+`, `<15`, `~20`, `-5`.
/// That case was missed when this was first written, and it shipped: the rule
/// here said "not for a single number", which is true of `4.8` and false of
/// `4.0+`. A `+` at the edge of a number is not absorbed by the number the way
/// an internal `:` or `.` is (bidi rule W4 covers only the *between* case), so
/// it is demoted to a neutral and takes the paragraph's direction — landing on
/// the far side of the figure it modifies. `4.0+` rendered `+4.0`, and the
/// rating chip stopped saying "or better".
///
/// Still NOT for a bare figure with nothing attached. `4.8` has no neutrals at
/// all; wrapping every number would litter the copy with invisible characters
/// and make ARB values impossible to diff.
///
/// The boundary between those two is no longer a judgement call:
/// `apps/customer_app/test/i18n/bidi_neutral_test.dart` reads the Arabic ARB,
/// finds the strings that carry the risk, and fails if any call site of one is
/// not wrapped here.
String ltrRun(String text) => '$_lri$text$_pdi';

/// The same, tolerant of null.
String? ltrRunOrNull(String? text) => text == null ? null : ltrRun(text);

/// The paragraph direction a piece of **user content** should be laid out in.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS IS NOT `ltrRun`
/// ─────────────────────────────────────────────────────────────────────────
///
/// `ltrRun` is for a run we KNOW is Latin — a phone number, a time range, a
/// price. Applied to content we did not write, it would be wrong half the
/// time: wrapping «نور حسن» in a left-to-right isolate lays an Arabic name out
/// backwards.
///
/// Review bodies and author names are written by diners, in whichever language
/// they chose, and shown to diners reading the app in the other one. Found by
/// looking at the Arabic reviews golden, where an English review ended
/// **`.whatever the menu says`** and the author read **`.Nour H`** — the full
/// stop taking the paragraph's direction and landing on the wrong end of a
/// sentence somebody else wrote.
///
/// An isolate cannot fix that, because the problem is not a run inside a
/// paragraph — the whole paragraph is in the other direction. The fix is to
/// give the `Text` its own direction, which is what `textDirection:` is for.
///
/// ── HOW THE DIRECTION IS DECIDED ─────────────────────────────────────────
///
/// The first STRONG character wins, which is the Unicode bidi algorithm's own
/// rule P2 for a paragraph of unknown direction. Digits and punctuation are
/// not strong and are skipped, so `"4/5 — عظيم"` is Arabic and `"«Great»"` is
/// Latin.
///
/// Returns null when there is no strong character at all (a rating with no
/// words, an emoji). Null means "inherit", which is the right answer: a string
/// with no direction of its own belongs to the page it is on.
TextDirection? contentDirection(String text) {
  for (final int rune in text.runes) {
    // Arabic, Arabic Supplement/Extended, Hebrew, Syriac, Thaana, and the
    // Arabic Presentation Forms some keyboards still emit.
    final bool rtl = (rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
    if (rtl) return TextDirection.rtl;

    // Latin, Greek, Cyrillic and the rest of the strong-LTR basic planes.
    final bool ltr = (rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x058F) ||
        (rune >= 0x0900 && rune <= 0x1FFF);
    if (ltr) return TextDirection.ltr;
  }
  return null;
}
