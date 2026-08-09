import 'package:sahra_api_client/sahra_api_client.dart';

import '../../../core/error/guarded.dart';
import '../domain/menu.dart';
import '../domain/restaurant_repository.dart';
import '../domain/review.dart';
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
    String? cuisine,
    int? priceBand,
    double? ratingMin,
    List<String> amenities = const <String>[],
  }) async {
    final response = await guarded(
      () => _api.find(
        q: query,
        neighborhood: neighborhood,
        cuisine: cuisine,
        // Every query parameter is a String because that is what a query
        // parameter is. Converting here rather than taking Strings in the
        // domain keeps the type where it means something — a price band is an
        // int, and a screen that could pass "cheap" would.
        priceBand: priceBand?.toString(),
        ratingMin: ratingMin?.toString(),
        // Comma-separated, matching the API's own parsing. Empty means "no
        // amenity filter", which is not the same as "no amenities".
        amenities: amenities.isEmpty ? null : amenities.join(','),
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
      images: r.images.map(_image).toList(),
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

  @override
  Future<List<Menu>> menus(String idOrSlug) async {
    final menus = await guarded(() => _api.listMenus(idOrSlug: idOrSlug));

    return menus
        .map((m) => Menu(
              id: m.id,
              name: _isArabic ? m.nameAr : m.nameEn,
              kind: m.kind,
              pdfUrl: m.pdfUrl,
              categories: m.categories
                  .map((c) => MenuCategory(
                        id: c.id,
                        name: _isArabic ? c.nameAr : c.nameEn,
                        items: c.items
                            .map((i) => MenuItem(
                                  id: i.id,
                                  name: _isArabic ? i.nameAr : i.nameEn,
                                  description:
                                      _isArabic ? i.descriptionAr : i.descriptionEn,
                                  // NOT parsed. The API sends '320.00' and the
                                  // screen prints '320.00'; turning it into a
                                  // double on the way past is the one step that
                                  // could round it.
                                  price: i.price,
                                  currency: i.currency,
                                  dietaryTags: i.dietaryTags,
                                  image: i.image == null ? null : _image(i.image!),
                                ),)
                            .toList(),
                      ),)
                  .toList(),
            ),)
        .toList();
  }

  @override
  Future<ReviewPage> reviews(String idOrSlug, {String? cursor, int? limit}) async {
    final page = await guarded(
      () => _api.listReviews(
        idOrSlug: idOrSlug,
        cursor: cursor,
        limit: limit?.toString(),
      ),
    );

    return ReviewPage(
      summary: ReviewSummary(
        rating: page.summary.rating,
        ratingCount: page.summary.ratingCount,
        // The API keys the histogram by a STRING, because a JSON object key is
        // a string. Parsed once here rather than at every bar.
        breakdown: <int, int>{
          for (final e in page.summary.breakdown.entries)
            if (int.tryParse(e.key) != null) int.parse(e.key): e.value,
        },
      ),
      results: page.results.map(_review).toList(),
      nextCursor: page.nextCursor,
    );
  }

  Review _review(ReviewResponse r) => Review(
        id: r.id,
        rating: r.rating,
        author: r.author,
        createdAt: DateTime.parse(r.createdAt),
        body: r.body,
        foodRating: r.foodRating,
        serviceRating: r.serviceRating,
        ambienceRating: r.ambienceRating,
        ownerReply: r.ownerReply,
        ownerRepliedAt:
            r.ownerRepliedAt == null ? null : DateTime.parse(r.ownerRepliedAt!),
      );

  /// One mapping for every image the API returns, so a size key or a
  /// dimension can never mean two things in two places.
  VenueImage _image(ImageResponse r) => VenueImage(
        id: r.id,
        urls: r.urls,
        width: r.width,
        height: r.height,
        isCover: r.isCover,
      );

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
        cover: r.cover == null ? null : _image(r.cover!),
      );
}
