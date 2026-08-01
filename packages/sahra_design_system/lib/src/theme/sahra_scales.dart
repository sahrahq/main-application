import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';

/// The 4px spacing scale (DESIGN-RULES.md). Widget code says
/// `SahraSpace.s4`, never `16`.
class SahraSpace {
  const SahraSpace._();

  static const double s1 = SahraTokens.space1;
  static const double s2 = SahraTokens.space2;
  static const double s3 = SahraTokens.space3;
  static const double s4 = SahraTokens.space4;
  static const double s5 = SahraTokens.space5;
  static const double s6 = SahraTokens.space6;
  static const double s8 = SahraTokens.space8;
  static const double s10 = SahraTokens.space10;
  static const double s12 = SahraTokens.space12;
  static const double s16 = SahraTokens.space16;
  static const double s24 = SahraTokens.space24;

  /// ALWAYS directional. `EdgeInsets.only(left:)` is banned outright — in
  /// Arabic the leading edge is on the right, and a hardcoded `left` silently
  /// mirrors the layout wrongly rather than failing. See
  /// `no_hardcoded_values_test.dart`, which fails the build if one appears.
  static EdgeInsetsDirectional inset({
    double start = 0,
    double top = 0,
    double end = 0,
    double bottom = 0,
  }) =>
      EdgeInsetsDirectional.only(start: start, top: top, end: end, bottom: bottom);

  static EdgeInsetsDirectional all(double v) =>
      EdgeInsetsDirectional.fromSTEB(v, v, v, v);

  static EdgeInsetsDirectional symmetric({double horizontal = 0, double vertical = 0}) =>
      EdgeInsetsDirectional.fromSTEB(horizontal, vertical, horizontal, vertical);
}

/// sm 8 / md 12 / lg 16 / xl 24 / pill 999 (DESIGN-RULES.md).
class SahraRadius {
  const SahraRadius._();

  static const double sm = SahraTokens.radiusSm;
  static const double md = SahraTokens.radiusMd;
  static const double lg = SahraTokens.radiusLg;
  static const double xl = SahraTokens.radiusXl;
  static const double pill = SahraTokens.radiusPill;

  /// Directional so a one-sided corner treatment mirrors under RTL.
  static BorderRadiusDirectional only({
    double topStart = 0,
    double topEnd = 0,
    double bottomStart = 0,
    double bottomEnd = 0,
  }) =>
      BorderRadiusDirectional.only(
        topStart: Radius.circular(topStart),
        topEnd: Radius.circular(topEnd),
        bottomStart: Radius.circular(bottomStart),
        bottomEnd: Radius.circular(bottomEnd),
      );

  static BorderRadius allOf(double v) => BorderRadius.circular(v);
}

/// Warm ink-tinted shadows. On dark these are replaced by a lighter surface —
/// go through `context.sahra.shadow(...)` rather than using these directly.
class SahraElevation {
  const SahraElevation._();

  static const List<BoxShadow> e1 = SahraTokens.shadow1;
  static const List<BoxShadow> e2 = SahraTokens.shadow2;
  static const List<BoxShadow> e3 = SahraTokens.shadow3;
}

/// Type sizes, leading and tracking — the raw numbers behind the TextThemes.
class SahraTypeScale {
  const SahraTypeScale._();

  static const double display = SahraTokens.textDisplay;
  static const double h1 = SahraTokens.textH1;
  static const double h2 = SahraTokens.textH2;
  static const double h3 = SahraTokens.textH3;
  static const double bodyL = SahraTokens.textBodyL;
  static const double bodyM = SahraTokens.textBodyM;
  static const double bodyS = SahraTokens.textBodyS;
  static const double caption = SahraTokens.textCaption;
  static const double overline = SahraTokens.textOverline;

  static const double leadingTight = SahraTokens.leadingTight;
  static const double leadingNormal = SahraTokens.leadingNormal;
  static const double leadingLoose = SahraTokens.leadingLoose;

  /// Arabic body leading — 1.7, per docs/design/guidelines/type-arabic.html.
  /// Looser than [leadingLoose] on purpose: Arabic sets dots and diacritics
  /// above and below the baseline, where Latin has nothing.
  static const double leadingArabic = SahraTokens.leadingArabic;

  /// `.14em` in CSS. Flutter's letterSpacing is logical pixels, so it is
  /// applied per size rather than being a single constant.
  static const double trackingOverlineEm = SahraTokens.trackingOverline;

  static double overlineTracking(double fontSize) => trackingOverlineEm * fontSize;
}

/// Constants that come from DESIGN-RULES.md rather than tokens.json.
///
/// Declared ONCE, here, so they are not scattered as bare numbers through
/// widget code — but flagged as not-a-token, because tokens.json has no
/// equivalent and inventing one would put the design package and the app out
/// of step in the opposite direction.
class SahraRules {
  const SahraRules._();

  /// "44px minimum hit targets on mobile" — DESIGN-RULES.md, and CLAUDE.md
  /// non-negotiable design rule 4.
  static const double minTouchTarget = 44.0;

  /// "Motion: 150–200ms ease-out; press scale .98; no bounces."
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionNormal = Duration(milliseconds: 200);
  static const Curve motionCurve = Curves.easeOut;
  static const double pressScale = 0.98;
}
