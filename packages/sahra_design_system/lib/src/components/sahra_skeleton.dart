import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_mashrabiya.dart';

/// `docs/design/components/core/Skeleton.d.ts` —
/// `{width, height, radius, lattice}` plus `SkeletonCard`.
///
/// The loading state. DESIGN-RULES.md requires every list screen to have one,
/// and requires it to be a skeleton rather than a spinner: a skeleton mirrors
/// the shape of what is coming, so the screen does not jump when content
/// arrives. A spinner tells the diner nothing except that something is
/// happening somewhere.
///
/// The shimmer is the signature — "the lattice glints as light sweeps across".
///
/// ACCESSIBILITY: a skeleton is announced as "loading" once, for the whole
/// block, rather than as a dozen anonymous boxes. A screen reader user needs
/// to know the screen is busy, not how many rectangles are on it.
class SahraSkeleton extends StatefulWidget {
  const SahraSkeleton({
    this.width = double.infinity,
    this.height = 16,
    this.radius,
    this.lattice = false,
    super.key,
  });

  final double width;
  final double height;
  final double? radius;

  /// Overlay the mashrabiya, for the large blocks that stand in for imagery.
  final bool lattice;

  @override
  State<SahraSkeleton> createState() => _SahraSkeletonState();
}

class _SahraSkeletonState extends State<SahraSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final radius = widget.radius ?? SahraRadius.md;

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: SahraRadius.allOf(radius),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: s.surfaceSunken),
              if (widget.lattice)
                SahraMashrabiya(
                  color: s.textBody.withValues(alpha: 0.05),
                  tile: 36,
                ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _Shimmer(
                  progress: _controller.value,
                  colour: s.premium.withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.progress, required this.colour});

  final double progress;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    // Directional: in Arabic the sweep runs right-to-left, like the reading.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final from = -1.0 + progress * 2;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(rtl ? -from : from, -1),
          end: Alignment(rtl ? -from + 1 : from + 1, 1),
          colors: <Color>[colour.withValues(alpha: 0), colour, colour.withValues(alpha: 0)],
          stops: const <double>[0.3, 0.5, 0.7],
        ),
      ),
    );
  }
}

/// A venue card's worth of skeleton — the shape Discover and Search load into.
class SahraSkeletonCard extends StatelessWidget {
  const SahraSkeletonCard({this.width = 250, this.semanticsLabel, super.key});

  final double width;

  /// "Loading restaurants" — supplied localised by the screen. Announced ONCE
  /// for the whole card rather than per placeholder.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return Semantics(
      label: semanticsLabel,
      liveRegion: semanticsLabel != null,
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: s.surfaceCard,
          borderRadius: SahraRadius.allOf(SahraRadius.lg),
          border: Border.all(color: s.line),
        ),
        child: Column(
          // Without this the card stretches to whatever height is offered —
          // it looked like a card with a large empty region below the text.
          // Caught by looking at the golden; no assertion covers "too tall".
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SahraSkeleton(height: 140, radius: 0, lattice: true),
            Padding(
              padding: SahraSpace.all(SahraSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SahraSkeleton(width: 150, height: 14),
                  SizedBox(height: SahraSpace.s2),
                  const SahraSkeleton(width: 200, height: 12),
                  SizedBox(height: SahraSpace.s2),
                  const SahraSkeleton(width: 90, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
