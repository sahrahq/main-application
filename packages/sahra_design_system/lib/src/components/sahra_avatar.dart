import 'package:flutter/material.dart';

import '../theme/sahra_semantics.dart';

/// `docs/design/components/social/Avatar.d.ts` — `{name, src, size}`.
///
/// Initials on a terracotta tint when there is no photo. Initials come from
/// the first two words, which works for "Nour Hassan" and for "نور حسن" alike:
/// the reference's `split(' ')` is script-agnostic and so is this.
class SahraAvatar extends StatelessWidget {
  const SahraAvatar({
    this.name = '',
    this.image,
    this.size = 36,
    super.key,
  });

  final String name;
  final ImageProvider? image;
  final double size;

  /// Grapheme-aware: `characters.first` keeps a two-codepoint letter whole,
  /// where `name[0]` would slice it in half and render a replacement box.
  static String initialsOf(String name) => name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w.characters.first)
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final initials = initialsOf(name);

    return Semantics(
      // The person's NAME is the label. An avatar announcing "image" tells a
      // screen-reader user nothing they need.
      label: name.isEmpty ? null : name,
      image: image != null,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: s.accent.withValues(alpha: 0.16),
          image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
        ),
        alignment: Alignment.center,
        child: image != null
            ? null
            : Text(
                initials,
                style: TextStyle(
                  color: s.accentOnSurface,
                  fontWeight: FontWeight.w700,
                  // Proportional to the circle, per the reference's size × .36.
                  fontSize: (size * 0.36).roundToDouble(),
                ),
              ),
      ),
    );
  }
}
