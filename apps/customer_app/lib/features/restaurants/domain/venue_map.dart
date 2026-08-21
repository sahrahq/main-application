/// WHERE "GET DIRECTIONS" SENDS A DINER — decided as a pure function.
///
/// The same shape as `routeForPush`: the destination is a value, so it can be
/// asserted without a widget, a platform channel or a running map app. The
/// only thing left at the call site is handing the result to the launcher.
///
/// ── NO MAP SDK, AND THAT IS THE DECISION, NOT A SHORTCUT ─────────────────
///
/// `MapCard.jsx` draws a live Leaflet map. Reproducing that in Flutter means
/// `google_maps_flutter` or `flutter_map`: an API key, a billing account, a
/// tile budget, and a second rendering engine inside the app — for a screen
/// whose job is "show me where this is so I can go there". C-2.4 is P1.
///
/// The handoff does the same job with no dependency: the diner's own map app
/// already has their location, their traffic, their saved places and their
/// preferred navigation. `url_launcher` is already approved (doc 08 §5).
library;

/// Which scheme the host platform actually answers.
enum MapPlatform {
  /// `geo:` — the Android standard. Every map app registers for it.
  android,

  /// `geo:` is NOT handled on iOS. Apple Maps answers `maps.apple.com`, which
  /// also opens the app rather than Safari when it is installed.
  ios,
}

/// A URI that opens the venue in the device's map app, or null when the venue
/// has no location worth sending.
///
/// Coordinates are preferred over the written address: an address string gets
/// re-geocoded by the map app and Cairo addresses geocode badly. When they are
/// absent the address is used as a search query, which is still better than
/// nothing — and when BOTH are absent this returns null and the caller must
/// not offer the action at all. **A control that opens an empty map is the
/// dead-end shape; no control is honest.**
Uri? venueMapUri({
  required MapPlatform platform,
  required String name,
  double? lat,
  double? lng,
  String? address,
  String? city,
}) {
  final bool hasCoords = lat != null && lng != null && !(lat == 0 && lng == 0);

  if (hasCoords) {
    final String pair = '$lat,$lng';
    return switch (platform) {
      // `q=` with a label puts a named pin at the point. Without it, `geo:`
      // alone only centres the map and drops no pin, so the diner sees a
      // patch of city and no destination.
      MapPlatform.android => Uri.parse('geo:$pair?q=${Uri.encodeComponent(pair)}'
          '(${Uri.encodeComponent(name)})'),
      MapPlatform.ios =>
        Uri.parse('https://maps.apple.com/?ll=$pair&q=${Uri.encodeComponent(name)}'),
    };
  }

  // No coordinates. Search by whatever text we have — the venue name alone is
  // ambiguous in a city with three places called Layali, so the address and
  // city are joined in when present.
  final String query = <String?>[name, address, city]
      .where((String? s) => s != null && s.trim().isNotEmpty)
      .join(', ');
  if (query.isEmpty) return null;

  return switch (platform) {
    MapPlatform.android => Uri.parse('geo:0,0?q=${Uri.encodeComponent(query)}'),
    MapPlatform.ios => Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(query)}'),
  };
}
