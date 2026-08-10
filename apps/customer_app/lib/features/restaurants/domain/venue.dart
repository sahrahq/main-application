/// Venue entities. PURE DART — no Flutter, no Riverpod, no generated client.
///
/// The domain deliberately does not reuse `SearchResultResponse` /
/// `RestaurantProfileResponse`. Those are wire shapes owned by the backend; a
/// UI built directly on them re-renders on every field rename, and the
/// bilingual pair (`name_en` / `name_ar`) has to be resolved SOMEWHERE. Doing
/// it once at the data boundary means no widget ever asks "which locale am I".
library;

/// One venue photo, in every size the server stored it in.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE CLIENT PICKS A SIZE; IT NEVER BUILDS A URL
/// ─────────────────────────────────────────────────────────────────────────
///
/// [urls] is keyed by pixel width — 160, 400, 1200 — and every entry is a
/// complete address the server composed. The bucket, the CDN in front of it
/// and the path convention are deployment concerns; a client that assembled
/// addresses itself would need a release the day any of them moved.
///
/// [width] and [height] are the ORIGINAL'S, and they are the reason a list
/// does not reflow as photos arrive: the box is reserved from this ratio
/// before a byte is fetched.
class VenueImage {
  const VenueImage({
    required this.id,
    required this.urls,
    required this.width,
    required this.height,
    required this.isCover,
  });

  final String id;
  final Map<String, String> urls;
  final int width;
  final int height;
  final bool isCover;

  double get aspectRatio => height == 0 ? 1 : width / height;

  /// The smallest stored rendition at least [logicalWidth] * [pixelRatio] wide.
  ///
  /// SMALLEST THAT FITS, not largest available. Sending the 1200px file to a
  /// 64pt thumbnail costs the full egress of a hero for a picture the size of
  /// a stamp — and on the free tier egress is the ceiling that actually binds
  /// (doc 10 §3b). Falling UP to the largest only when nothing is big enough
  /// keeps a hero sharp on a tablet.
  String? urlFor({required double logicalWidth, double pixelRatio = 1}) {
    if (urls.isEmpty) return null;

    final wanted = logicalWidth * pixelRatio;
    final sizes = urls.keys.map(int.tryParse).whereType<int>().toList()..sort();
    if (sizes.isEmpty) return null;

    for (final size in sizes) {
      if (size >= wanted) return urls['$size'];
    }
    return urls['${sizes.last}'];
  }
}

/// A venue as it appears in a list of results.
class VenueSummary {
  const VenueSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.cuisines,
    required this.rating,
    required this.ratingCount,
    this.neighborhood,
    this.priceBand,
    this.nextAvailable = const <String>[],
    this.cover,
    this.distanceKm,
  });

  final String id;
  final String slug;

  /// Already resolved for the active locale.
  final String name;

  final List<String> cuisines;
  final double rating;
  final int ratingCount;
  final String? neighborhood;

  /// 1–4, rendered as `$`–`$$$$`.
  final int? priceBand;

  /// How far this venue is, in kilometres, AS THE SERVER COMPUTED IT.
  ///
  /// Null unless the diner shared a position — the API only returns it when
  /// the query carried lat/lng. Never computed here: the client would need the
  /// venue's coordinates and a haversine of its own, and two implementations of
  /// one distance is two answers on one screen.
  final double? distanceKm;

  /// Local `HH:MM` teasers. **A HINT, NEVER BOOKABLE** — they carry no
  /// absolute instant precisely so no screen can pass one to a booking call
  /// (sahra_api_client/README.md §2). Empty means availability was not asked
  /// for; a venue with nothing free is dropped from results entirely.
  final List<String> nextAvailable;

  /// The venue hero, or null for a venue with no photos.
  ///
  /// NULL IS AN ORDINARY STATE, not an error. Most venues have no photos until
  /// somebody uploads them by hand (doc 10 §3b), and `SahraPhoto` draws a
  /// designed placeholder for exactly this — a mashrabiya lattice the designer
  /// specified, not a broken-image icon.
  final VenueImage? cover;
}

/// The full profile behind a result.
class VenueProfile {
  const VenueProfile({
    required this.id,
    required this.slug,
    required this.name,
    required this.cuisines,
    required this.rating,
    required this.ratingCount,
    required this.city,
    required this.amenities,
    required this.hours,
    required this.timezone,
    this.images = const <VenueImage>[],
    this.description,
    this.neighborhood,
    this.address,
    this.phone,
    this.priceBand,
    this.lat,
    this.lng,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final List<String> cuisines;
  final double rating;
  final int ratingCount;
  final String? neighborhood;
  final String city;
  final String? address;
  final String? phone;
  final int? priceBand;
  final double? lat;
  final double? lng;
  final List<String> amenities;
  final List<OpeningHours> hours;

  /// IANA zone. Every wall-clock time in [hours] is expressed in it — a client
  /// that assumes the device's zone shows the wrong opening time to anyone
  /// travelling, and is 2–3 hours out for Cairo seen from Europe.
  final String timezone;

  /// The gallery, cover first then by position. EMPTY IS A DESIGNED STATE —
  /// `SahraPhoto` draws the reference's mashrabiya placeholder, which is what
  /// the designer specified for a venue with no photo.
  final List<VenueImage> images;

  /// The hero, or null. `firstOrNull` rather than a search for `isCover`: the
  /// server already orders cover-first, and re-deriving it here would be a
  /// second opinion about something Postgres enforces with a unique index.
  VenueImage? get cover => images.isEmpty ? null : images.first;

  /// The shifts running on [weekday] (0 = Sunday), in order. Empty means the
  /// venue is closed that day, which is information rather than an error.
  List<OpeningHours> hoursOn(int weekday) =>
      hours.where((h) => h.dayOfWeek == weekday).toList();
}

class OpeningHours {
  const OpeningHours({
    required this.name,
    required this.opensAt,
    required this.closesAt,
    required this.spansMidnight,
    this.dayOfWeek,
    this.specificDate,
  });

  /// Resolved for the locale — "Dinner" / "العشاء".
  final String name;

  /// `HH:MM` on the RESTAURANT's wall clock, not the device's.
  final String opensAt;
  final String closesAt;

  /// Sohour-style shifts run past midnight, so `closesAt < opensAt` is normal
  /// and a naive start-before-end comparison hides the whole shift.
  final bool spansMidnight;

  final int? dayOfWeek;
  final String? specificDate;
}
