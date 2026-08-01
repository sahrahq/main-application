import 'package:flutter/material.dart';

import '../theme/sahra_semantics.dart';

/// `docs/design/components/brand/Mashrabiya.d.ts` — `{color, opacity, tile, fade}`.
///
/// The carved-wood screen from a Cairo balcony, abstracted to an
/// eight-point-star lattice: a diamond and a square per tile, meeting their
/// neighbours so the pattern is seamless.
///
/// SAHRA's signature texture — card dividers, empty and loading states,
/// occasion backdrops. The reference is emphatic that this is "distinctly
/// Cairene, not a generic 'Arabic pattern'", which is why the geometry is
/// exact rather than approximated.
///
/// ALWAYS DECORATIVE. It is hidden from screen readers unconditionally: a
/// texture that announced itself would be noise on every screen it appears on.
class SahraMashrabiya extends StatelessWidget {
  const SahraMashrabiya({
    this.color,
    this.opacity = 1.0,
    this.tile = 44,
    this.fade = false,
    this.child,
    super.key,
  });

  /// Defaults to the accent at the reference's 0.5 alpha.
  final Color? color;
  final double opacity;

  /// Tile edge in logical pixels. The reference's 44 is the density the
  /// pattern was drawn at; much smaller and it reads as noise.
  final double tile;

  /// Radial fade from the top, for headers that dissolve into the page.
  final bool fade;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.sahra.accent.withValues(alpha: 0.5);

    Widget painted = CustomPaint(
      painter: _MashrabiyaPainter(color: resolved, tile: tile),
      child: child,
    );

    if (fade) {
      painted = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: const <Color>[_maskOpaque, _maskClear],
          stops: const <double>[0.0, 0.78],
        ).createShader(rect),
        child: painted,
      );
    }

    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(opacity: opacity, child: painted),
      ),
    );
  }
}

// design-exempt: ALPHA STENCIL values for a dstIn mask, not design colours.
// Opaque-to-transparent black is simply how a mask is written; there is no
// token for "fully masked" and inventing one would be worse than the exemption.
const _maskOpaque = Color(0xFF000000);
// design-exempt: as above.
const _maskClear = Color(0x00000000);

class _MashrabiyaPainter extends CustomPainter {
  _MashrabiyaPainter({required this.color, required this.tile});

  final Color color;
  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // 1px on the reference's 44 grid, scaled with the tile so a large tile
      // does not thin out to nothing.
      ..strokeWidth = tile / 44
      ..isAntiAlias = true;

    // The reference's 44-unit tile: a diamond on the points, a square inset by
    // 8. Rotated-square corners meet the neighbouring tiles, which is what
    // makes it seamless rather than merely repeated.
    final u = tile / 44;
    for (double y = 0; y < size.height + tile; y += tile) {
      for (double x = 0; x < size.width + tile; x += tile) {
        final diamond = Path()
          ..moveTo(x + 22 * u, y + 2 * u)
          ..lineTo(x + 42 * u, y + 22 * u)
          ..lineTo(x + 22 * u, y + 42 * u)
          ..lineTo(x + 2 * u, y + 22 * u)
          ..close();
        canvas.drawPath(diamond, paint);
        canvas.drawRect(
          Rect.fromLTRB(x + 8 * u, y + 8 * u, x + 36 * u, y + 36 * u),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MashrabiyaPainter old) => old.color != color || old.tile != tile;
}
