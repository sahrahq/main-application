import 'package:flutter/material.dart';
import '../../reservations/presentation/reservation_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/providers/session_providers.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../../../shared/widgets/venue_image_provider.dart';
import '../../saved/presentation/saved_notifier.dart';
import '../domain/restaurant_repository.dart';
import 'cuisine_copy.dart';
import 'discover_notifier.dart';
import 'venue_meta.dart';

/// `docs/design/ui_kits/app/DiscoverScreen.jsx` — THE HOME SCREEN.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THIS SCREEN DID NOT EXIST, AND NOTHING SAID SO
/// ─────────────────────────────────────────────────────────────────────────
///
/// The tab labelled "Discover" opened `SearchScreen`. So the first thing a
/// diner ever saw was an empty box asking them what they wanted — the opposite
/// of how this category works, and the fastest way to lose somebody in their
/// first ten seconds. The reference has existed the whole time; nothing
/// referenced it, and no test could notice, because every test began by
/// constructing a screen that was reachable.
///
/// ── WHAT THE REFERENCE DRAWS AND THIS DOES NOT ───────────────────────────
///
/// Four of its seven sections have no data behind them, and each is ABSENT
/// rather than faked. A home screen of plausible-looking placeholders is worse
/// than a short one: it teaches the diner that nothing here is real.
///
///   - **The Ramadan / occasion banner.** `OccasionScreen.jsx` is unbuilt and
///     there is no events or offers table. C-2.5 is P1.
///   - **"How was Zooba?"** — a rating prompt. Reviews are C-4.4, P1, and
///     scheduled as Group D. There is no reviews table to write to.
///   - **"Tonight in Cairo"** — events. No table, no endpoint. P2.
///   - **Collections** — "Rooftops with a view · 12 places". Curated lists,
///     C-2.5, P1. No schema for a named list.
///
/// ── AND THE LOCATION PICKER ──────────────────────────────────────────────
///
/// The reference shows "Zamalek, Cairo" with a chevron, which promises a
/// picker. There is no location permission, no geocoding and no city list; the
/// search API takes lat/lng but nothing collects them. So the line names the
/// city we actually serve, WITHOUT the chevron — a control that opens nothing
/// is the defect this file was written to fix, one section down.
///
/// What is left is real: who you are, and tables you can book tonight.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: SahraPageWidth(
        child: SafeArea(bottom: false, child: _Body()),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      // The reference's pull-to-refresh, in the platform's own idiom. Its
      // swinging-lantern indicator is a bespoke animation; `RefreshIndicator`
      // is what an Android diner already knows, and inventing a second gesture
      // language for one screen is a cost with no user.
      onRefresh: () async {
        ref.invalidate(availableTonightProvider);
        await ref.read(availableTonightProvider.future);
      },
      child: ListView(
        // ALWAYS SCROLLABLE. Pull-to-refresh needs a scrollable that can
        // overscroll even when the content is short — otherwise the gesture
        // silently does nothing on exactly the screens that most need it, the
        // empty ones.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SahraSpace.inset(bottom: SahraSpace.s6),
        children: <Widget>[
          const _Greeting(),
          _SectionTitle(
            title: l10n.discoverTonight,
            action: l10n.discoverSeeAll,
            onAction: () => const SearchRoute().go(context),
          ),
          const _TonightRow(),
        ],
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final session = ref.watch(currentSessionProvider);

    // The FIRST name only. "Good evening, Nour Hassan Mohamed" is a form
    // letter; "Good evening, Nour" is a greeting.
    final firstName = session?.fullName.trim().split(' ').first;

    return Padding(
      padding: SahraSpace.inset(
        start: SahraSpace.s5,
        end: SahraSpace.s5,
        top: SahraSpace.s5,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  firstName == null
                      ? l10n.discoverGreetingAnonymous
                      : l10n.discoverGreeting(firstName),
                  style: text.bodySmall?.copyWith(color: s.textFaint),
                ),
                const SizedBox(height: SahraSpace.s1),
                Text(
                  // NO CHEVRON. See the class note — there is no city picker,
                  // and a control that opens nothing is the defect this screen
                  // exists to fix.
                  l10n.discoverCity,
                  style: text.headlineSmall?.copyWith(color: s.textBody),
                ),
              ],
            ),
          ),
          if (session != null) SahraAvatar(name: session.fullName, size: 40),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: SahraSpace.inset(
        start: SahraSpace.s5,
        end: SahraSpace.s5,
        top: SahraSpace.s6,
        bottom: SahraSpace.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: Text(title, style: text.headlineSmall?.copyWith(color: s.textBody)),
          ),
          if (action != null && onAction != null)
            // A real 44dp target, not a bare tappable Text. The reference draws
            // a 13px label; the hit box grows around it.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SahraRules.minTouchTarget,
                  minWidth: SahraRules.minTouchTarget,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    action!,
                    // ACCENT, NOT GOLD. The reference sets `--gold-dark` on
                    // this label; gold as TEXT measures 2.5–2.8:1 on both
                    // surfaces and fails AA, which `palette_contrast_test`
                    // already pins. AA wins over the reference, every time.
                    // `accentOnSurface` is the tested accent-as-text colour
                    // the rest of the app uses for exactly this.
                    style: text.labelLarge?.copyWith(
                      color: s.accentOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The reference's 244×140 horizontal carousel.
class _TonightRow extends ConsumerWidget {
  const _TonightRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // The card is 244 wide with a 140 image, plus its text block. Fixed rather
    // than intrinsic because a horizontal list has no height of its own, and a
    // row that resized as cards loaded would make the whole screen jump.
    //
    // THE FIXED HEIGHT WRAPS THE ROWS, NOT THE WHOLE VIEW. Putting it outside
    // `SahraAsyncView` clamped the EMPTY state to 268 too, and the empty state
    // is taller — it overflowed by 15px, which is silent in a release build.
    // Caught by the tab-navigation test, which happens to render this screen.
    // COMPUTED FROM THE SCALER, not fixed. 268 was right at 1.0 and overflowed
    // by 39px at 200% — the same defect as the saved grid, one screen later,
    // because a horizontal list has no height of its own and something has to
    // supply one. The image is a fixed 140 (the reference's number) and the
    // text block below it scales, so one constant cannot describe both.
    final rowHeight = 140 + 128 * MediaQuery.textScalerOf(context).scale(1);

    return SahraAsyncView<SearchPage>(
      value: ref.watch(availableTonightProvider),
      onRetry: () => ref.invalidate(availableTonightProvider),
      isEmpty: (page) => page.results.isEmpty,
      loading: (_) => SizedBox(
        height: rowHeight,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: SahraSpace.symmetric(horizontal: SahraSpace.s5),
          children: const <Widget>[
            SahraSkeleton(width: 244, height: 244, radius: SahraRadius.lg),
            SizedBox(width: SahraSpace.s3),
            SahraSkeleton(width: 244, height: 244, radius: SahraRadius.lg),
          ],
        ),
      ),
      // NOTHING FREE TONIGHT IS A REAL ANSWER, not an error. Cairo on a
      // Thursday in Ramadan is a city with no tables, and a home screen that
      // showed a spinner or a retry button for it would be lying about the
      // situation.
      empty: (context) => Padding(
        padding: SahraSpace.symmetric(horizontal: SahraSpace.s5),
        child: SahraEmptyState(
          icon: 'lantern',
          title: l10n.discoverNothingTonightTitle,
          message: l10n.discoverNothingTonightMessage,
          actionLabel: l10n.discoverNothingTonightAction,
          onAction: () => const SearchRoute().go(context),
        ),
      ),
      content: (context, page) => SizedBox(
        height: rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: SahraSpace.symmetric(horizontal: SahraSpace.s5),
          itemCount: page.results.length,
          separatorBuilder: (_, __) => const SizedBox(width: SahraSpace.s3),
          itemBuilder: (context, i) {
            final venue = page.results[i];
            final saved = ref.watch(savedVenueIdsProvider).contains(venue.id);

            return SahraRestaurantCard(
              width: 244,
              imageHeight: 140,
              name: venue.name,
              rating: venue.rating,
              reviews: venue.ratingCount,
              cuisine: venue.cuisines.isEmpty
                  ? ''
                  : cuisineLabel(venue.cuisines.first, l10n) ?? venue.cuisines.first,
              price: venue.priceBand == null ? '' : priceSymbols(venue.priceBand!),
              neighbourhood: venue.neighborhood,
              image: venueImageProvider(context, ref, venue.cover, slotWidth: 244),
              // The reference puts the first slot on the card. It is a HINT and
              // carries no bookable instant — the same rule the search rows
              // follow, so no screen can pass one to a booking call.
              availability: venue.nextAvailable.isEmpty
                  ? null
                  : l10n.searchNextAvailable(timeOfDay(venue.nextAvailable.first, context)),
              saved: saved,
              saveLabel: saved ? l10n.savedRemoveLabel(venue.name) : l10n.savedAddLabel(venue.name),
              onSave: () => toggleSavedAndReport(context, ref, restaurantId: venue.id),
              onTap: () => VenueRoute(venue.slug).go(context),
            );
          },
        ),
      ),
    );
  }
}
