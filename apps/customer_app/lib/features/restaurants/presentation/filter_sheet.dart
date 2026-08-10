import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import 'amenity_copy.dart';
import 'cuisine_copy.dart';
import '../../../shared/location/location_notifier.dart';
import '../../../shared/location/location_source.dart';
import '../domain/search_sort.dart';
import 'search_notifier.dart';
import 'venue_meta.dart';

/// C-2.2 — the filters, in a sheet.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE API HAS SERVED THESE SINCE SEARCH SHIPPED
/// ─────────────────────────────────────────────────────────────────────────
///
/// Cuisine, price band, rating and amenities were all in `GET
/// /restaurants/search` from the start; the client asked for none of them, so
/// the search screen offered one chip. This sheet is entirely client work
/// against a finished endpoint — which is why it belongs with discovery rather
/// than in a backend group.
///
/// ── WHAT IS NOT HERE ─────────────────────────────────────────────────────
///
/// **Nothing, any more.** Distance and sort were the two absences, and both
/// landed in the location half-batch.
///
/// ── THE ONLY PERMISSION PROMPT IN THE APP ────────────────────────────────
///
/// "Near me" is the single control that can raise the OS location dialog, and
/// it raises it on the tap that switches it on. Not at launch, not when this
/// sheet opens, not when the screen behind it builds.
///
/// That is the agreement — "I don't want a permission prompt in the app before
/// there's a reason for one" — enforced by shape rather than by discipline:
/// `DinerLocation.build()` returns null and asks nothing, so the dialog cannot
/// appear unless something calls `request()`, and this is the only caller.
///
/// **The toggle flips only if a position arrives.** A diner who taps it and
/// then declines gets the switch back where it was and a line saying why —
/// rather than a filter that is on, changes nothing, and has to be discovered
/// to be useless. Which is the failure Discover was rebuilt to fix.
///
/// ── AND WHY EVERYTHING IS LOCAL UNTIL "APPLY" ────────────────────────────
///
/// The sheet holds a DRAFT and writes it once. Applying each tap live would
/// re-run the search on every touch — five requests to set four filters, over
/// a Cairo mobile connection, with the results shifting under a sheet the
/// diner cannot see past. `Clear` resets the draft; the search behind is
/// untouched until Apply.
Future<void> showFilterSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _FilterSheet(),
  );
}

const List<String> _cuisines = <String>[
  'levantine',
  'egyptian',
  'mediterranean',
  'lebanese',
  'japanese',
  'sushi',
  'street_food',
  'cafe',
];

const List<String> _amenities = <String>[
  'outdoor',
  'shisha',
  'nile_view',
  'valet',
  'family_section',
  'alcohol_free',
];

const List<double> _ratings = <double>[4.0, 4.5];

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late String? _cuisine;
  late int? _priceBand;
  late double? _ratingMin;
  late Set<String> _amenitySet;
  late bool _nearMe;
  late SearchSort _sort;

  /// Set when the diner asked for "near me" and the platform said no. Cleared
  /// on the next attempt, so the message belongs to the last thing they did.
  LocationOutcome? _refused;

  /// The prompt can take a second or two. Without this the toggle sits
  /// unchanged and the sheet looks frozen.
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    // Seeded from what is actually applied, so the sheet opens showing the
    // filters in force rather than an empty form the diner has to rebuild.
    final criteria = ref.read(searchCriteriaProvider);
    _cuisine = criteria.cuisine;
    _priceBand = criteria.priceBand;
    _ratingMin = criteria.ratingMin;
    _amenitySet = <String>{...criteria.amenities};
    _nearMe = criteria.nearMe;
    _sort = criteria.sort;
  }

  /// The one place in the app that can raise the location dialog.
  Future<void> _toggleNearMe() async {
    if (_nearMe) {
      // Turning it OFF forgets the position too, so the next tap asks again
      // rather than reusing a fix from an hour and one taxi ride ago. A
      // distance SORT cannot outlive the filter that gave it a position.
      ref.read(dinerLocationProvider.notifier).clear();
      setState(() {
        _nearMe = false;
        _refused = null;
        if (_sort == SearchSort.distance) _sort = SearchSort.relevance;
      });
      return;
    }

    setState(() {
      _locating = true;
      _refused = null;
    });

    final LocationResult result = await ref.read(dinerLocationProvider.notifier).request();
    if (!mounted) return;

    setState(() {
      _locating = false;
      // THE SWITCH FOLLOWS THE POSITION, not the tap. On refusal it stays off
      // and the reason appears underneath.
      _nearMe = result.hasPosition;
      _refused = result.hasPosition ? null : result.outcome;
    });
  }

  /// Four different sentences, because four different things are true and
  /// three of them cannot be fixed by tapping again. `deniedForever`
  /// especially: the OS will not show the dialog, so "try again" would be an
  /// instruction that cannot work.
  String _refusalMessage(LocationOutcome outcome, AppLocalizations l10n) => switch (outcome) {
        LocationOutcome.denied => l10n.locationDenied,
        LocationOutcome.deniedForever => l10n.locationDeniedForever,
        LocationOutcome.serviceDisabled => l10n.locationServiceDisabled,
        LocationOutcome.unavailable => l10n.locationUnavailable,
        LocationOutcome.ok => '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: SahraPageWidth(
        child: Padding(
          padding: SahraSpace.all(SahraSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: s.line,
                    borderRadius: BorderRadius.circular(SahraRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: SahraSpace.s5),
              Text(
                l10n.filterTitle,
                style: text.headlineSmall?.copyWith(color: s.textBody),
              ),

              // ── Cuisine — single select, because the API takes one ────────
              const SizedBox(height: SahraSpace.s5),
              SahraSectionLabel(l10n.filterCuisine),
              const SizedBox(height: SahraSpace.s2),
              Wrap(
                spacing: SahraSpace.s2,
                runSpacing: SahraSpace.s2,
                children: <Widget>[
                  for (final key in _cuisines)
                    SahraChip(
                      label: cuisineLabel(key, l10n) ?? key,
                      active: _cuisine == key,
                      // TAPPING THE ACTIVE ONE CLEARS IT. Without that, a
                      // single-select has no "any" and the only way back is
                      // Clear, which also drops the other three filters.
                      onPressed: () => setState(
                        () => _cuisine = _cuisine == key ? null : key,
                      ),
                    ),
                ],
              ),

              // ── Price ─────────────────────────────────────────────────────
              const SizedBox(height: SahraSpace.s5),
              SahraSectionLabel(l10n.filterPrice),
              const SizedBox(height: SahraSpace.s2),
              Wrap(
                spacing: SahraSpace.s2,
                runSpacing: SahraSpace.s2,
                children: <Widget>[
                  for (var band = 1; band <= 4; band++)
                    SahraChip(
                      // Latin figures in both locales, and `$` is a symbol
                      // rather than copy — the same call the search meta makes.
                      label: priceSymbols(band),
                      active: _priceBand == band,
                      onPressed: () => setState(
                        () => _priceBand = _priceBand == band ? null : band,
                      ),
                    ),
                ],
              ),

              // ── Rating ────────────────────────────────────────────────────
              const SizedBox(height: SahraSpace.s5),
              SahraSectionLabel(l10n.filterRating),
              const SizedBox(height: SahraSpace.s2),
              Wrap(
                spacing: SahraSpace.s2,
                runSpacing: SahraSpace.s2,
                children: <Widget>[
                  for (final rating in _ratings)
                    SahraChip(
                      // ISOLATED. `+` is a bidi-neutral character, so in Arabic
                      // "4.0+" renders as "+4.0" — the plus jumps to the
                      // visual left and the label stops saying "4.0 or
                      // better". Caught by looking at the golden; the same
                      // defect the phone number and the venue hours had.
                      label: ltrRun(l10n.filterRatingPlus(rating.toStringAsFixed(1))),
                      active: _ratingMin == rating,
                      onPressed: () => setState(
                        () => _ratingMin = _ratingMin == rating ? null : rating,
                      ),
                    ),
                ],
              ),

              // ── Amenities — multi, because the API takes a list ───────────
              const SizedBox(height: SahraSpace.s5),
              SahraSectionLabel(l10n.filterAmenities),
              const SizedBox(height: SahraSpace.s2),
              Wrap(
                spacing: SahraSpace.s2,
                runSpacing: SahraSpace.s2,
                children: <Widget>[
                  for (final key in _amenities)
                    SahraChip(
                      label: amenityLabel(key, l10n) ?? key,
                      active: _amenitySet.contains(key),
                      onPressed: () => setState(() {
                        if (!_amenitySet.remove(key)) _amenitySet.add(key);
                      }),
                    ),
                ],
              ),

              // Distance — C-2.2, and the permission prompt.
              const SizedBox(height: SahraSpace.s5),
              SahraSectionLabel(l10n.filterDistance),
              const SizedBox(height: SahraSpace.s2),
              SahraChip(
                label: _locating
                    ? l10n.locationAsking
                    : _nearMe
                        // Says WHAT "near me" means once it is on. A filter
                        // whose reach is invisible is one a diner cannot tell
                        // is working.
                        ? l10n.filterNearMeRadius(
                            kNearMeRadiusKm.toStringAsFixed(0),
                          )
                        : l10n.filterNearMe,
                active: _nearMe,
                onPressed: _locating ? null : () => unawaited(_toggleNearMe()),
              ),
              if (_refused != null) ...<Widget>[
                const SizedBox(height: SahraSpace.s2),
                Text(
                  _refusalMessage(_refused!, l10n),
                  style: text.bodySmall?.copyWith(color: s.textSoft),
                ),
              ],

              // Sort — C-2.3.
              const SizedBox(height: SahraSpace.s5),
              SahraSectionLabel(l10n.filterSort),
              const SizedBox(height: SahraSpace.s2),
              Wrap(
                spacing: SahraSpace.s2,
                runSpacing: SahraSpace.s2,
                children: <Widget>[
                  for (final option in SearchSort.values)
                    // NEAREST FIRST IS ABSENT UNTIL THERE IS A POSITION, not
                    // present and disabled. A disabled control invites the
                    // question "why"; an absent one is answered by the
                    // distance filter directly above it.
                    if (option != SearchSort.distance || _nearMe)
                      SahraChip(
                        label: switch (option) {
                          SearchSort.relevance => l10n.sortRelevance,
                          SearchSort.rating => l10n.sortRating,
                          SearchSort.distance => l10n.sortDistance,
                        },
                        active: _sort == option,
                        onPressed: () => setState(() => _sort = option),
                      ),
                ],
              ),

              const SizedBox(height: SahraSpace.s6),
              SahraButton(
                label: l10n.filterApply,
                onPressed: () {
                  ref.read(searchCriteriaProvider.notifier).applyFilters(
                        cuisine: _cuisine,
                        priceBand: _priceBand,
                        ratingMin: _ratingMin,
                        amenities: _amenitySet,
                        nearMe: _nearMe,
                        sort: _sort,
                      );
                  unawaited(Navigator.of(context).maybePop());
                },
              ),
              const SizedBox(height: SahraSpace.s3),
              SahraButton(
                label: l10n.filterClear,
                variant: SahraButtonVariant.ghost,
                // CLEARS THE DRAFT, not the applied search. The diner can
                // still back out without changing anything, which is what a
                // sheet with a Cancel gesture promises.
                onPressed: () => setState(() {
                  _cuisine = null;
                  _priceBand = null;
                  _ratingMin = null;
                  _amenitySet = <String>{};
                  _nearMe = false;
                  _sort = SearchSort.relevance;
                  _refused = null;
                }),
              ),
              const SizedBox(height: SahraSpace.s3),
            ],
          ),
        ),
      ),
    );
  }
}
