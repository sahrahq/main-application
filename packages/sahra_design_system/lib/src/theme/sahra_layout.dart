import 'package:flutter/widgets.dart';

/// Where content stops stretching.
///
/// THE PROBLEM. Every screen in this app was drawn on a phone. The design
/// package's own preview shell renders each one at **375 × 812**
/// (`ui_kits/app/index.html`), and nothing in the reference contemplates a
/// wider window — because nothing was meant to be seen in one. But Flutter
/// builds for web and for tablets, and a `Column` given 1440 points will
/// happily use all of them: a venue description becomes a single 200-character
/// line, a search result row becomes a thumbnail marooned beside a horizon of
/// whitespace, and a booking footer's button stretches the full width of a
/// desktop monitor.
///
/// THE RULE. Content has a maximum readable width and CENTRES beyond it,
/// rather than stretching edge to edge.
///
/// **560 points**, and the reasoning is written down because the number will
/// look arbitrary otherwise:
///
///   - it is ~1.5× the 375 the screens were actually drawn at, so a layout
///     never stretches more than half again beyond what a designer saw;
///   - it keeps a comfortable measure for the one genuinely long text in the
///     product — the venue description — at roughly 60–75 characters a line,
///     which is the range typography has agreed on for a century;
///   - it is BELOW 768, so tablet portrait gets the centred phone layout
///     rather than a stretched one. That is deliberate: `management_app` is
///     the tablet-first surface (CLAUDE.md), its screens will be DRAWN for
///     tablets, and the customer app must not inherit a half-considered wide
///     layout in the meantime.
///
/// This is not a breakpoint system. There is one number, applied one way, in
/// one place — the same discipline as the tokens. A screen that needs a real
/// tablet layout should get a designed one, not a wider phone.
class SahraLayout {
  const SahraLayout._();

  /// The widest content ever gets. See the class note for why 560.
  static const double maxContentWidth = 560;

  /// The canvas every screen in `docs/design/ui_kits/app/` was drawn on.
  ///
  /// Recorded here because it is the origin of [maxContentWidth] and because
  /// the preview harness in the app reproduces it rather than inventing a
  /// frame.
  static const Size designCanvas = Size(375, 812);
}

/// Constrain content to [SahraLayout.maxContentWidth] and centre it.
///
/// Wrap a screen's BODY in this, once, at the top. Do not scatter
/// `MediaQuery.of(context).size.width` checks through widgets: that is how
/// three screens end up with three different ideas of "wide", and how a
/// change to the number becomes a search-and-replace instead of an edit.
///
/// Deliberately NOT applied inside components. A component is given whatever
/// width its parent offers and should fill it — a card that refused to be
/// wider than 560 inside a 560 column would be wrong, and one that centred
/// itself inside a list row would be baffling.
class SahraPageWidth extends StatelessWidget {
  const SahraPageWidth({
    required this.child,
    this.maxWidth = SahraLayout.maxContentWidth,
    super.key,
  });

  final Widget child;

  /// Override only with a reason. A screen that genuinely needs more — a
  /// future floor-plan editor, say — is a designed exception, not a preference.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      // `topCenter`, not `center`: horizontally centred, but content still
      // starts at the top. `Alignment.center` would float a short screen's
      // content into the middle of a tall window, which reads as broken
      // rather than as centred.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
