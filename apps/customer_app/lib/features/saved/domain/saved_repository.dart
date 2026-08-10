import '../../restaurants/domain/venue.dart';

/// A venue the diner saved (C-2.7). Pure Dart.
///
/// It is a [VenueSummary] plus when it was saved — the saved screen draws the
/// same card the search list does, so it takes the same shape rather than a
/// parallel one that would drift.
class SavedVenue {
  const SavedVenue({required this.venue, required this.savedAt});

  final VenueSummary venue;

  /// Drives the newest-first order the server already applied. Kept because
  /// "saved 3 days ago" is the obvious next thing this screen will want, and
  /// dropping it at the boundary would mean another API change to get it back.
  final String savedAt;
}

abstract class SavedRepository {
  /// The caller's saved venues, newest first.
  ///
  /// OWNERSHIP IS NOT A PARAMETER. There is no `userId` and there must never
  /// be one — the server takes it from the token.
  Future<List<SavedVenue>> saved();

  /// Save a venue. **Idempotent**: saving something already saved succeeds.
  Future<void> save(String restaurantId);

  /// Unsave. **Idempotent**: unsaving something not saved succeeds.
  ///
  /// Both halves matter because the control is a TOGGLE. A diner who taps
  /// twice, or whose first response was lost, must not be shown an error for
  /// arriving at the state they asked for.
  Future<void> unsave(String restaurantId);
}
