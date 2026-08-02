import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/sahra_semantics.dart';

/// `docs/design/components/core/Icon.d.ts` — `{name, size}`.
///
/// "One uniform 1.6px line hand drawn from Cairo dining culture, not a generic
/// library. Unknown names fall back to Lucide."
///
/// In Flutter the fallback is Material rather than Lucide, which adds no
/// dependency and is the same bargain: a house glyph where one is drawn, a
/// stock glyph where one is not.
///
/// WHAT IS DRAWN vs WHAT FALLS BACK is deliberate and visible in
/// [drawnIcons]. The brand-carrying glyphs — lantern, tea, mezze, shisha,
/// spark, star — are drawn, because they are the ones that make the set feel
/// Cairene rather than generic. The rest are stock until someone draws them,
/// and `SahraIcon.isDrawn` tells you which is which so the gap is countable
/// rather than assumed.
class SahraIcon extends StatelessWidget {
  const SahraIcon(
    this.name, {
    this.size = 20,
    this.color,
    this.semanticLabel,
    this.filled = false,
    super.key,
  });

  final String name;
  final double size;

  /// Defaults to the ambient [IconTheme], so an icon inside a button takes the
  /// button's foreground without being told.
  final Color? color;

  /// Null means decorative — the icon is hidden from screen readers, which is
  /// correct when it sits beside a label that already says the same thing.
  final String? semanticLabel;

  /// Solid rather than stroked. The set is a LINE set by design, but a few
  /// glyphs are wrong hollow: an outlined rating star reads as "not rated",
  /// which is the opposite of what a 4.8 means. Caught by looking at a
  /// RatingStars golden.
  final bool filled;

  /// The 1.6px line weight, from the reference. Scales with [size] so a large
  /// icon does not read as a hairline.
  static const double _referenceStroke = 1.6;
  static const double _referenceSize = 24;

  static bool isDrawn(String name) => _painters.containsKey(name);

  static Iterable<String> get drawnIcons => _painters.keys;

  /// Names the reference defines that are NOT yet drawn — they render from
  /// Material. Listed so "the icon set is finished" is a checkable claim.
  static const List<String> fallbackIcons = <String>[
    'heart',
    'user',
    'users',
    'clock',
    'calendar',
    'check',
    'image',
    'compass',
    'share',
    'phone',
    'plus',
    'bell',
    'tag',
    'ticket',
    'globe',
    // Added while building the booking path.
    //
    // `minus` retires a wave-3 cosmetic flag: the party stepper was using `x`
    // as a minus, and `x` is a CLOSE glyph — "remove this", not "one fewer".
    // The reference writes the HTML entity `&minus;`, which has no icon at
    // all, so there was nothing to draw from.
    'minus',
    'map-pin',
    'chevron-down',
    // Directional. See the note on _material below — these MIRROR.
    'arrow-back',
    'chevron-forward',
  ];

  static const Map<String, IconData> _material = <String, IconData>{
    'heart': Icons.favorite_border,
    'user': Icons.person_outline,
    'users': Icons.people_outline,
    'clock': Icons.schedule,
    'calendar': Icons.calendar_today_outlined,
    'check': Icons.check,
    'image': Icons.image_outlined,
    'compass': Icons.explore_outlined,
    'share': Icons.ios_share,
    'phone': Icons.phone_outlined,
    'plus': Icons.add,
    'bell': Icons.notifications_none,
    'tag': Icons.local_offer_outlined,
    'ticket': Icons.confirmation_number_outlined,
    'globe': Icons.language,
    'minus': Icons.remove,
    'map-pin': Icons.place_outlined,
    'chevron-down': Icons.keyboard_arrow_down,
    // `Icons.arrow_back` carries `matchTextDirection: true`, so Flutter FLIPS
    // it under `Directionality.rtl` and an Arabic screen gets a back arrow
    // pointing right — which is what `VenueDetailScreen.jsx` does by hand
    // (`name={ar ? 'arrow-right' : 'arrow-left'}`).
    //
    // Asserted in icon_direction_test.dart rather than trusted: the flag is a
    // property of a Material constant that a future SDK could change, and a
    // back arrow pointing the wrong way is the exact "mirrors but reads wrong"
    // failure ENGINEERING-STANDARDS lists as un-catchable by any other test.
    'arrow-back': Icons.arrow_back,
    // "Onward", not "right". `Icons.arrow_forward_ios` also carries
    // `matchTextDirection: true`, so the disclosure chevron on a list row
    // points right in English and LEFT in Arabic — where "further in" is.
    // A hardcoded `chevron_right` would point out of the row in RTL, which is
    // the same class of defect as a back arrow that does not turn round.
    'chevron-forward': Icons.arrow_forward_ios,
  };

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? context.sahra.textBody;
    final painter = _painters[name];

    final glyph = painter == null
        ? Icon(
            _material[name] ?? Icons.help_outline,
            size: size,
            color: resolved,
          )
        : CustomPaint(
            size: Size.square(size),
            painter: _SahraIconPainter(
              draw: painter,
              color: resolved,
              strokeWidth: _referenceStroke * (size / _referenceSize),
              filled: filled,
            ),
          );

    return Semantics(
      label: semanticLabel,
      // Decorative unless named. An icon that repeats its neighbouring label
      // just makes a screen reader say everything twice.
      excludeSemantics: semanticLabel == null,
      child: SizedBox(width: size, height: size, child: glyph),
    );
  }
}

typedef _Draw = void Function(Canvas canvas, Size size, Paint paint);

/// Paths are authored on a 24×24 grid and scaled, matching the reference's
/// viewBox so the line weight stays proportional.
const Map<String, _Draw> _painters = <String, _Draw>{
  'lantern': _lantern,
  'tea': _tea,
  'mezze': _mezze,
  'shisha': _shisha,
  'star': _star,
  'spark': _spark,
  'search': _search,
  'x': _close,
};

class _SahraIconPainter extends CustomPainter {
  _SahraIconPainter({
    required this.draw,
    required this.color,
    required this.strokeWidth,
    this.filled = false,
  });

  final _Draw draw;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    draw(canvas, size, paint);
  }

  @override
  bool shouldRepaint(_SahraIconPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.draw != draw ||
      old.filled != filled;
}

double _u(Size s) => s.width / 24;

/// A Ramadan fanous — the lantern that hangs in every Cairo street in Ramadan.
void _lantern(Canvas c, Size s, Paint p) {
  final u = _u(s);
  c.drawLine(Offset(9 * u, 3 * u), Offset(15 * u, 3 * u), p);
  c.drawLine(Offset(12 * u, 3 * u), Offset(12 * u, 5 * u), p);
  final body = Path()
    ..moveTo(8 * u, 6 * u)
    ..lineTo(16 * u, 6 * u)
    ..lineTo(17 * u, 16 * u)
    ..lineTo(7 * u, 16 * u)
    ..close();
  c.drawPath(body, p);
  c.drawLine(Offset(12 * u, 6 * u), Offset(12 * u, 16 * u), p);
  c.drawRect(Rect.fromLTRB(9 * u, 17 * u, 15 * u, 20 * u), p);
}

/// A tea glass — shai, served in a narrow glass, never a mug.
void _tea(Canvas c, Size s, Paint p) {
  final u = _u(s);
  final glass = Path()
    ..moveTo(8 * u, 8 * u)
    ..lineTo(16 * u, 8 * u)
    ..lineTo(14.5 * u, 19 * u)
    ..lineTo(9.5 * u, 19 * u)
    ..close();
  c.drawPath(glass, p);
  c.drawLine(Offset(9 * u, 13 * u), Offset(15 * u, 13 * u), p);
  // Steam.
  c.drawArc(Rect.fromLTWH(10 * u, 3 * u, 2 * u, 4 * u), math.pi, math.pi, false, p);
  c.drawArc(Rect.fromLTWH(13 * u, 3 * u, 2 * u, 4 * u), math.pi, math.pi, false, p);
}

/// Mezze — small plates around a shared centre.
void _mezze(Canvas c, Size s, Paint p) {
  final u = _u(s);
  c.drawCircle(Offset(12 * u, 12 * u), 3.2 * u, p);
  for (var i = 0; i < 4; i++) {
    final a = (math.pi / 2) * i - math.pi / 4;
    c.drawCircle(
      Offset(12 * u + math.cos(a) * 7 * u, 12 * u + math.sin(a) * 7 * u),
      2.1 * u,
      p,
    );
  }
}

/// Shisha — the pipe on every ahwa terrace.
void _shisha(Canvas c, Size s, Paint p) {
  final u = _u(s);
  c.drawRect(Rect.fromLTRB(10.5 * u, 3 * u, 13.5 * u, 5.5 * u), p);
  c.drawLine(Offset(12 * u, 5.5 * u), Offset(12 * u, 14 * u), p);
  final base = Path()
    ..moveTo(9 * u, 14 * u)
    ..quadraticBezierTo(12 * u, 22 * u, 15 * u, 14 * u)
    ..close();
  c.drawPath(base, p);
  final hose = Path()
    ..moveTo(12 * u, 8 * u)
    ..cubicTo(18 * u, 8 * u, 20 * u, 13 * u, 19 * u, 17 * u);
  c.drawPath(hose, p);
}

/// The rating star. DRAWN, not the ★ glyph: Poppins has no U+2605 and the
/// character renders as tofu — found by looking at a golden, not by any test.
void _star(Canvas c, Size s, Paint p) {
  final u = _u(s);
  final centre = Offset(12 * u, 12.5 * u);
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? 9 * u : 3.7 * u;
    final a = -math.pi / 2 + i * math.pi / 5;
    final pt = Offset(centre.dx + math.cos(a) * r, centre.dy + math.sin(a) * r);
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  path.close();
  c.drawPath(path, p);
}

/// Spark — the "something special tonight" mark.
void _spark(Canvas c, Size s, Paint p) {
  final u = _u(s);
  void burst(double cx, double cy, double r) {
    final path = Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx + r * 0.22, cy - r * 0.22, cx + r, cy)
      ..quadraticBezierTo(cx + r * 0.22, cy + r * 0.22, cx, cy + r)
      ..quadraticBezierTo(cx - r * 0.22, cy + r * 0.22, cx - r, cy)
      ..quadraticBezierTo(cx - r * 0.22, cy - r * 0.22, cx, cy - r)
      ..close();
    c.drawPath(path, p);
  }

  burst(10 * u, 10 * u, 6 * u);
  burst(18 * u, 17 * u, 3.2 * u);
}

void _search(Canvas c, Size s, Paint p) {
  final u = _u(s);
  c.drawCircle(Offset(10.5 * u, 10.5 * u), 6 * u, p);
  c.drawLine(Offset(15 * u, 15 * u), Offset(20 * u, 20 * u), p);
}

void _close(Canvas c, Size s, Paint p) {
  final u = _u(s);
  c.drawLine(Offset(6 * u, 6 * u), Offset(18 * u, 18 * u), p);
  c.drawLine(Offset(18 * u, 6 * u), Offset(6 * u, 18 * u), p);
}
