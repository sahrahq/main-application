import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../shared/widgets/venue_image_provider.dart';
import '../domain/venue.dart';

/// `VenueDetailScreen.jsx` line 39–41 — the horizontal strip of thumbnails
/// under the description.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE DATA WAS ALREADY ARRIVING
/// ─────────────────────────────────────────────────────────────────────────
///
/// Group B built the `images` table and `VenueProfile.images` has been
/// populated cover-first ever since. The hero drew `images.first` and
/// **everything after it was fetched and then not rendered** — bytes over a
/// Cairo mobile connection, paid for on every venue open, for photographs
/// nobody could see.
///
/// It is the same class as everything else this project keeps finding: correct
/// at every layer, absent on screen. No test could catch it, because every
/// test that renders the venue screen renders exactly what the screen chose to
/// render.
///
/// ── WHY THE FIRST IMAGE IS SKIPPED ───────────────────────────────────────
///
/// It is the hero, full-bleed, 200 points above this strip. Repeating it as a
/// 120×90 thumbnail would make a venue with one photo look like a venue with
/// two, and the reference draws four DIFFERENT photos.
class GalleryStrip extends ConsumerWidget {
  const GalleryStrip({required this.images, super.key});

  final List<VenueImage> images;

  /// The reference's dimensions: 120 wide, 90 tall, 10 apart, 12 radius.
  static const double _width = 120;
  static const double _height = 90;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Everything after the hero.
    final rest = images.length <= 1 ? const <VenueImage>[] : images.sublist(1);
    if (rest.isEmpty) return const SizedBox.shrink();

    // COMPUTED, not fixed. At 200% text this strip does not itself grow — no
    // text in it — but the page around it does, and a fixed height here inside
    // a scrolling column is the shape that produced two overflows in Group C.
    // The height is the photo's, and the photo has no text, so this one is
    // genuinely constant; stated rather than assumed.
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // DIRECTIONAL padding, so the strip starts at the same margin as the
        // text above it in both directions.
        padding: SahraSpace.symmetric(horizontal: SahraSpace.s5),
        itemCount: rest.length,
        separatorBuilder: (_, __) => const SizedBox(width: SahraSpace.s3),
        // `Semantics(image:)`, NOT `SahraPhoto.label`.
        //
        // `label` on that component is a VISIBLE uppercase marker in the
        // corner, from `Photo.jsx` — using it here printed "Photo 2 of 2"
        // across every thumbnail, in white on terracotta, at 3.73:1. Found by
        // opening the golden; `textContrastGuideline` failed too, but on a node
        // whose message pointed at the paragraph above it.
        itemBuilder: (context, i) => Semantics(
          image: true,
          // "Photo 2 of 5", not five identical "image" announcements. The index
          // counts from 1 and includes the hero, because that is what a diner
          // would count.
          label: l10n.venueGalleryLabel(i + 2, images.length),
          child: SizedBox(
            width: _width,
            child: SahraPhoto(
              height: _height,
              radius: SahraRadius.md,
              // The provider picks the smallest rendition at least this wide at
              // the device's pixel ratio — a 160px file for a 120pt box on a 1x
              // screen, 400px on a 3x one. Which is the entire point of having
              // resized on upload.
              image: venueImageProvider(context, ref, rest[i], slotWidth: _width),
              // The centred glyph would sit under nothing here — there is no
              // overlaid text on a thumbnail — so the placeholder keeps its cue.
            ),
          ),
        ),
      ),
    );
  }
}
