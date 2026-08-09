/// C-2.3 — how search results are ordered, and how far "near me" reaches.
///
/// IN `domain/`, NOT `presentation/`. These started life next to `SearchQuery`
/// in the notifier, which meant `RestaurantRepository` — a domain file — had to
/// import from `presentation/` to name the type in its own signature. That is
/// the dependency arrow pointing outward, which doc 07 §1 forbids and
/// `layers_test.dart` would have caught on the next run.
///
/// An ordering and a radius are facts about what a search IS, not about how a
/// screen draws one, so this is where they belonged in the first place.
library;

enum SearchSort { relevance, rating, distance }

/// How far "near me" reaches.
///
/// 5km, and it is a judgement rather than a measurement. Cairo traffic makes a
/// straight-line radius a poor proxy for effort — 5km across the river at 8pm
/// is not 5km inside Zamalek — but a radius is what the API takes and what
/// Meilisearch's `_geoRadius` filters on. Wide enough to keep Zamalek, Downtown
/// and Garden City in one another's results; narrow enough that "near me" is
/// not the whole city.
const double kNearMeRadiusKm = 5;
