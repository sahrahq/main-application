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
/// URLs. NOT for a single number — `4.8` has no internal neutrals and renders
/// correctly on its own, and wrapping every figure would litter the copy with
/// invisible characters and make ARB values impossible to diff.
String ltrRun(String text) => '$_lri$text$_pdi';

/// The same, tolerant of null.
String? ltrRunOrNull(String? text) => text == null ? null : ltrRun(text);
