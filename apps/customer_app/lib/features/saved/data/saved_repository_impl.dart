import 'package:sahra_api_client/sahra_api_client.dart';

import '../../../core/error/guarded.dart';
import '../../restaurants/domain/venue.dart';
import '../domain/saved_repository.dart';

class SavedRepositoryImpl implements SavedRepository {
  SavedRepositoryImpl(this._api, this._locale);

  final SahraApi _api;

  /// The active locale, read at call time rather than captured. The name pair
  /// is resolved once here, at the data boundary, so no widget ever asks
  /// "which locale am I".
  final String Function() _locale;

  @override
  Future<List<SavedVenue>> saved() async {
    final rows = await guarded(() => _api.listSaved());
    final ar = _locale() == 'ar';

    return rows
        .map(
          (r) => SavedVenue(
            savedAt: r.savedAt,
            venue: VenueSummary(
              id: r.id,
              slug: r.slug,
              name: ar ? r.nameAr : r.nameEn,
              cuisines: r.cuisines,
              rating: r.rating,
              ratingCount: r.ratingCount,
              neighborhood: r.neighborhood,
              priceBand: r.priceBand,
              cover: r.cover == null
                  ? null
                  : VenueImage(
                      id: r.cover!.id,
                      urls: r.cover!.urls,
                      width: r.cover!.width,
                      height: r.cover!.height,
                      isCover: r.cover!.isCover,
                    ),
            ),
          ),
        )
        .toList();
  }

  @override
  Future<void> save(String restaurantId) =>
      guarded(() => _api.save(body: SaveVenueDto(restaurantId: restaurantId)));

  @override
  Future<void> unsave(String restaurantId) =>
      guarded(() => _api.unsave(restaurantId: restaurantId));
}
