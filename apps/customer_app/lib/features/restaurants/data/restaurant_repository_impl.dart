import 'package:sahra_api_client/sahra_api_client.dart';

import '../../../core/error/guarded.dart';
import '../domain/restaurant_repository.dart';
import '../domain/venue.dart';

/// Wire → domain, and the ONE place `name_en` / `name_ar` is resolved.
///
/// Every mapping here is a compile-time coupling to the generated client, on
/// purpose: a backend rename breaks THIS file rather than a screen. That is
/// guarantee 3 of `sahra_api_client` doing its job, and keeping the mapping in
/// one file per feature is what makes the resulting compile error small.
class RestaurantRepositoryImpl implements RestaurantRepository {
  RestaurantRepositoryImpl(this._api, this._localeCode);

  final SahraApi _api;

  /// Read on every call rather than captured once — the locale can change
  /// while the app is running, and a repository that cached it would keep
  /// serving Arabic names to a diner who just switched to English.
  final String Function() _localeCode;

  bool get _isArabic => _localeCode() == 'ar';

  @override
  Future<SearchPage> search({
    String? query,
    String? neighborhood,
    String? availableOn,
    int? partySize,
    String? cursor,
  }) async {
    final response = await guarded(
      () => _api.find(
        q: query,
        neighborhood: neighborhood,
        // The API rejects one without the other
        // (`invalid_availability_filter`), so they travel together or not at
        // all.
        availableAt: partySize == null ? null : availableOn,
        partySize: availableOn == null ? null : partySize?.toString(),
        cursor: cursor,
      ),
    );

    return SearchPage(
      results: response.results.map(_summary).toList(),
      estimatedTotal: response.estimatedTotal,
      availabilityFiltered: response.availabilityFiltered,
      nextCursor: response.nextCursor,
    );
  }

  @override
  Future<VenueProfile> profile(String idOrSlug) async {
    final r = await guarded(() => _api.profile(idOrSlug: idOrSlug));

    return VenueProfile(
      id: r.id,
      slug: r.slug,
      name: _isArabic ? r.nameAr : r.nameEn,
      description: _isArabic ? r.descriptionAr : r.descriptionEn,
      cuisines: r.cuisines,
      rating: r.rating,
      ratingCount: r.ratingCount,
      neighborhood: r.neighborhood,
      city: r.city,
      address: _isArabic ? r.addressAr : r.addressEn,
      phone: r.phone,
      priceBand: r.priceBand,
      lat: r.lat,
      lng: r.lng,
      amenities: r.amenities,
      timezone: r.timezone,
      hours: r.hours
          .map((h) => OpeningHours(
                name: _isArabic ? h.nameAr : h.nameEn,
                opensAt: h.opensAt,
                closesAt: h.closesAt,
                spansMidnight: h.spansMidnight,
                dayOfWeek: h.dayOfWeek,
                specificDate: h.specificDate,
              ),)
          .toList(),
    );
  }

  VenueSummary _summary(SearchResultResponse r) => VenueSummary(
        id: r.id,
        slug: r.slug,
        name: _isArabic ? r.nameAr : r.nameEn,
        cuisines: r.cuisines,
        rating: r.rating,
        ratingCount: r.ratingCount,
        neighborhood: r.neighborhood,
        priceBand: r.priceBand,
        // Kept as the strings the server sent. Parsing these into times would
        // be the first step towards treating a teaser as bookable.
        nextAvailable: r.nextAvailable ?? const <String>[],
      );
}
