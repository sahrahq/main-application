/// C-4.4 — a review, written by somebody who actually turned up.
class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.author,
    required this.createdAt,
    this.body,
    this.foodRating,
    this.serviceRating,
    this.ambienceRating,
    this.ownerReply,
    this.ownerRepliedAt,
  });

  final String id;
  final int rating;

  /// Already reduced to a first name and an initial by the API. The client
  /// never sees the full name, so it cannot leak one.
  final String author;

  final DateTime createdAt;

  /// Null is ordinary — stars alone is a complete review.
  final String? body;

  final int? foodRating;
  final int? serviceRating;
  final int? ambienceRating;

  final String? ownerReply;
  final DateTime? ownerRepliedAt;

  bool get hasSubRatings => foodRating != null || serviceRating != null || ambienceRating != null;
}

/// The headline figure and the histogram under it.
class ReviewSummary {
  const ReviewSummary({
    required this.rating,
    required this.ratingCount,
    required this.breakdown,
  });

  const ReviewSummary.empty()
      : rating = 0,
        ratingCount = 0,
        breakdown = const <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  final double rating;
  final int ratingCount;

  /// Stars → how many gave it. Always five entries, so the bars do not reflow
  /// as reviews arrive.
  final Map<int, int> breakdown;

  /// 0..1 for the bar next to [stars]. Zero reviews is a flat row, not a
  /// division by zero.
  double share(int stars) => ratingCount == 0 ? 0 : (breakdown[stars] ?? 0) / ratingCount;
}

class ReviewPage {
  const ReviewPage({
    required this.summary,
    required this.results,
    this.nextCursor,
  });

  const ReviewPage.empty()
      : summary = const ReviewSummary.empty(),
        results = const <Review>[],
        nextCursor = null;

  final ReviewSummary summary;
  final List<Review> results;

  /// Keyset, not an offset — a review posted between two page loads must not
  /// push one the diner already read onto page two.
  final String? nextCursor;
}
