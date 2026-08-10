import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/restaurants/domain/venue.dart';

part 'venue_image_provider.g.dart';

/// URL → something Flutter can draw. THE ONLY LINE THAT TOUCHES THE NETWORK.
///
/// A seam, for the same reason the contact launcher has one: `flutter_test`
/// answers every HTTP request with a 400 and never opens a socket, so a golden
/// built on the real provider draws NOTHING — which looks exactly like the
/// designed empty state. A golden named "venue with a photo" would picture a
/// venue without one and pass forever.
///
/// That is the stale-fixture failure in a new place: a picture that quietly
/// stops meaning what its name says. Overridden in `screen_registry.dart` with
/// a real decodable image so the wiring is actually pictured.
@Riverpod(keepAlive: true)
ImageProvider Function(String url) networkImageFactory(Ref ref) => CachedNetworkImageProvider.new;

/// Turn a [VenueImage] into something `SahraPhoto` can draw.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS IS IN THE APP AND NOT IN THE DESIGN SYSTEM
/// ─────────────────────────────────────────────────────────────────────────
///
/// `SahraPhoto` takes an `ImageProvider?` and knows nothing about the network,
/// which is what lets its goldens be deterministic and its package stay free
/// of an HTTP dependency. The choice of WHICH rendition and HOW to cache it is
/// an application concern, so it lives here.
///
/// ── CACHING ──────────────────────────────────────────────────────────────
///
/// `cached_network_image` (doc 07 §Caching — already in the approved stack, so
/// no new decision). Aggressive by design and safe to be: every URL contains
/// the image id and the pixel width, and the server sets a one-year immutable
/// `Cache-Control`. A given address never changes its bytes, so a long cache
/// cannot serve a stale photo — the only way an image changes is by getting a
/// new id.
///
/// ── AND WHY THE WIDTH MATTERS AT THE CALL SITE ───────────────────────────
///
/// Every caller must say how wide the slot is. That is deliberately awkward:
/// the whole point of storing three sizes is defeated by a caller that takes
/// the biggest, and a default would let one do so silently. On the free tier
/// egress is the ceiling that binds (doc 10 §3b), so a 1200px file behind a
/// 64pt thumbnail is a real cost, paid on every scroll.
ImageProvider? venueImageProvider(
  BuildContext context,
  WidgetRef ref,
  VenueImage? image, {
  required double slotWidth,
}) {
  if (image == null) return null;

  final url = image.urlFor(
    logicalWidth: slotWidth,
    // The device's own ratio, so a 3x phone gets the sharp rendition and a 1x
    // test host does not download one it cannot show.
    pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
  );
  if (url == null) return null;

  return ref.watch(networkImageFactoryProvider)(url);
}
