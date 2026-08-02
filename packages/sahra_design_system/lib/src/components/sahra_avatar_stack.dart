import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_avatar.dart';

/// One person in a stack.
class SahraPerson {
  const SahraPerson({this.name = '', this.image});
  final String name;
  final ImageProvider? image;
}

/// `docs/design/components/social/AvatarStack.d.ts` —
/// `{people, max, size, label}`.
///
/// Overlapping faces with a `+N` overflow — "three friends are going".
///
/// OVERLAP IS DIRECTIONAL. In Arabic the stack builds from the right, so the
/// negative offset flips; a hardcoded negative left margin would pile the
/// faces the wrong way and look like a rendering bug rather than a mirror.
///
/// ACCESSIBILITY: announced as ONE thing — "Nour, Omar and 3 others" — not as
/// five unlabelled circles. A screen reader user wants the sentence.
class SahraAvatarStack extends StatelessWidget {
  const SahraAvatarStack({
    required this.people,
    this.max = 3,
    this.size = 32,
    this.label,
    this.semanticLabel,
    super.key,
  });

  final List<SahraPerson> people;
  final int max;
  final double size;

  /// Trailing copy, already localised.
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final shown = people.take(max).toList();
    final extra = people.length - shown.length;
    final overlap = (size * 0.3).roundToDouble();

    final step = size - overlap;
    final count = shown.length + (extra > 0 ? 1 : 0);
    final stackWidth = count == 0 ? 0.0 : size + (count - 1) * step;

    return Semantics(
      label: semanticLabel ?? _fallbackLabel(shown, extra),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: stackWidth,
            height: size,
            // A Stack with PositionedDirectional rather than negative padding:
            // Padding rejects negative values, and — more to the point —
            // `start` is the RIGHT edge in Arabic, so the faces pile the
            // correct way round without a mirrored special case.
            child: Stack(
              children: <Widget>[
                for (var i = 0; i < shown.length; i++)
                  PositionedDirectional(
                    start: i * step,
                    child: _Ringed(
                      size: size,
                      colour: s.surfacePage,
                      child: SahraAvatar(
                        name: shown[i].name,
                        image: shown[i].image,
                        size: size,
                      ),
                    ),
                  ),
                if (extra > 0)
                  PositionedDirectional(
                    start: shown.length * step,
                    child: _Ringed(
                      size: size,
                      colour: s.surfacePage,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.surfaceSunken,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          // Latin digits, per DESIGN-RULES.md.
                          '+$extra',
                          style: TextStyle(
                            color: s.textSoft,
                            fontSize: SahraTypeScale.overline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (label != null) ...<Widget>[
            SizedBox(width: SahraSpace.s3),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.textSoft),
            ),
          ],
        ],
      ),
    );
  }

  /// A readable sentence, not a pile of circles. Callers should pass a
  /// localised [semanticLabel]; this is the fallback.
  static String _fallbackLabel(List<SahraPerson> shown, int extra) {
    final names = shown.map((p) => p.name).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return '';
    return extra > 0 ? '${names.join(', ')} and $extra others' : names.join(', ');
  }
}

/// The ring that separates one face from the one behind it.
class _Ringed extends StatelessWidget {
  const _Ringed({required this.size, required this.colour, required this.child});

  final double size;
  final Color colour;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colour, width: 2),
        ),
        child: child,
      );
}
