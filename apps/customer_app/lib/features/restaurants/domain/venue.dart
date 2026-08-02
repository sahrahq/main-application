/// Venue entities. PURE DART — no Flutter, no Riverpod, no generated client.
///
/// The domain deliberately does not reuse `SearchResultResponse` /
/// `RestaurantProfileResponse`. Those are wire shapes owned by the backend; a
/// UI built directly on them re-renders on every field rename, and the
/// bilingual pair (`name_en` / `name_ar`) has to be resolved SOMEWHERE. Doing
/// it once at the data boundary means no widget ever asks "which locale am I".
library;

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

  /// Local `HH:MM` teasers. **A HINT, NEVER BOOKABLE** — they carry no
  /// absolute instant precisely so no screen can pass one to a booking call
  /// (sahra_api_client/README.md §2). Empty means availability was not asked
  /// for; a venue with nothing free is dropped from results entirely.
  final List<String> nextAvailable;
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
