import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../../../shared/widgets/venue_image_provider.dart';
import '../domain/venue.dart';
import 'amenity_copy.dart';
import 'gallery_strip.dart';
import 'menu_section.dart';
import 'reviews_section.dart';
import 'venue_meta.dart';
import 'venue_notifier.dart';
import '../../../shared/providers/session_providers.dart';
import '../../saved/presentation/saved_notifier.dart';

/// `docs/design/ui_kits/app/VenueDetailScreen.jsx`.
///
/// WHAT IS NOT HERE, and why — every one of these is a MISSING DATA SOURCE,
/// not a shortcut. Rendering any of them would mean inventing content, and a
/// restaurant page that invents its own menu prices is worse than one that
/// admits it has none:
///
///   - **"Nour & 11 friends have been here"** (`AvatarStack`) — the social
///     graph is C-3.8, P2.
///   - **"Sunset offer — 20% off"** — promotions are R-4.2, P1/P2.
///   - **"Featured tonight"** badge — editorial/paid placement, C-2.5, P1.
///   - **The map card** — Leaflet in the reference; C-2.4 is P1 and no map
///     package is in the doc 08 stack table.
///
/// What DOES render is everything the schema actually holds: name, rating,
/// cuisines, price band, neighbourhood, description, amenities, opening hours,
/// phone, **the photo gallery, the menu and the reviews** — which is C-2.6
/// except for the map and the two P1/P2 features above.
///
/// Group D added the last three. The gallery is the one worth naming: the
/// images were already arriving and only the first was drawn, so the strip was
/// a rendering gap rather than a missing capability. See `GalleryStrip`.
class VenueScreen extends ConsumerWidget {
  const VenueScreen({required this.idOrSlug, super.key});

  final String idOrSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // One wrapper at the top of the body, like every other screen. See
      // SahraPageWidth for why the decision lives in one place.
      body: SahraPageWidth(
        child: SahraAsyncView<VenueProfile>(
        value: ref.watch(venueProfileProvider(idOrSlug)),
        onRetry: () => ref.invalidate(venueProfileProvider(idOrSlug)),
        // A profile is one object; it is never "empty". Required by the
        // signature anyway, which is the point — the alternative is a screen
        // silently rendering nothing under a heading.
        isEmpty: (_) => false,
        empty: (_) => const SizedBox.shrink(),
        loading: (_) => const _VenueSkeleton(),
        error: (context, failure) => Center(
          child: Padding(
            padding: SahraSpace.all(SahraSpace.s5),
            child: failure.code == 'restaurant_not_found'
                // A venue that has stopped taking bookings is not an error to
                // retry — it is a fact, and the way forward is elsewhere.
                ? SahraEmptyState(
                    icon: 'lantern',
                    title: l10n.venueNotFoundTitle,
                    message: l10n.venueNotFoundMessage,
                    actionLabel: l10n.venueNotFoundAction,
                    onAction: () => const SearchRoute().go(context),
                  )
                : SahraFailureView(
                    failure: failure,
                    onRetry: () => ref.invalidate(venueProfileProvider(idOrSlug)),
                  ),
          ),
        ),
        content: (context, venue) => _Content(venue: venue),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.venue});

  final VenueProfile venue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _Hero(venue: venue),
              // OUTSIDE the horizontal padding, deliberately. The reference
              // scrolls the strip edge to edge, and a thumbnail half off the
              // screen is what tells a diner there are more — the padding moves
              // onto the list's own content instead.
              //
              // ── AND IT SITS ABOVE THE DESCRIPTION, WHICH THE REFERENCE DOES
              // NOT ──
              //
              // `VenueDetailScreen.jsx` draws description → gallery. Swapping
              // them is a real deviation and it is here for a real reason:
              // full-bleed means the strip cannot live inside the page's
              // horizontal padding, so putting it between the description and
              // everything else left the description alone in a full-width
              // block of its own.
              //
              // That merged into ONE semantics node spanning the whole width,
              // and `textContrastGuideline` then sampled far more background
              // than glyph and read the paragraph's colour off an
              // anti-aliased edge — 3.73:1 for text that measures 8.77:1. The
              // copy never changed colour; the node around it did.
              //
              // Two ways out: shape the code around a measurement artefact, or
              // move one block. Moving the block also puts the photographs
              // directly under the hero, which is where a diner deciding
              // whether to look further is already looking.
              GalleryStrip(images: venue.images),
              Padding(
                padding: SahraSpace.inset(
                  start: SahraSpace.s5,
                  end: SahraSpace.s5,
                  top: SahraSpace.s4,
                  bottom: SahraSpace.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (venue.description != null) ...<Widget>[
                      Text(
                        venue.description!,
                        style: text.bodyMedium?.copyWith(color: s.textSoft),
                      ),
                      const SizedBox(height: SahraSpace.s4),
                    ],
                    if (venue.amenities.isNotEmpty) ...<Widget>[
                      Wrap(
                        spacing: SahraSpace.s2,
                        runSpacing: SahraSpace.s2,
                        children: <Widget>[
                          // Only amenities we have copy for. An unknown key is
                          // skipped rather than shown raw — `nile_view` on a
                          // restaurant page is a leaked database column.
                          for (final key in venue.amenities)
                            if (amenityLabel(key, l10n) != null)
                              SahraBadge(label: amenityLabel(key, l10n)!),
                        ],
                      ),
                      const SizedBox(height: SahraSpace.s5),
                    ],
                    // The reference's order: menu, then the map, then the info
                    // rows. Reviews are not in the reference at all; they go
                    // last, because C-2.6 lists them after the practical
                    // details and because a diner scrolling for the phone
                    // number should not have to pass four reviews first.
                    MenuSection(idOrSlug: venue.slug),
                    const SizedBox(height: SahraSpace.s5),
                    _InfoRows(venue: venue),
                    const SizedBox(height: SahraSpace.s5),
                    ReviewsSection(idOrSlug: venue.slug),
                  ],
                ),
              ),
            ],
          ),
        ),
        _BookBar(venue: venue),
      ],
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.venue});

  final VenueProfile venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final signedIn = ref.watch(currentSessionProvider) != null;
    final saved = ref.watch(saveToggleProvider(venue.id));

    return SahraPhoto(
      // FIXED HEIGHT, so the hero reserves its space before a byte arrives and
      // the controls below it do not jump when the photo lands.
      height: 280,
      // Full-bleed, so the slot is the screen. The provider picks the smallest
      // rendition at least this wide at the device's pixel ratio — a 1200px
      // file on a phone hero, a 400px one on a narrow test viewport.
      image: venueImageProvider(
        context,
        ref,
        venue.cover,
        slotWidth: MediaQuery.sizeOf(context).width,
      ),
      gradientOverlay: true,
      // The controls sit on top, so the centred image glyph would be behind
      // them.
      cue: false,
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            PositionedDirectional(
              start: SahraSpace.s5,
              top: SahraSpace.s5,
              child: SahraPhotoIconButton(
                // Mirrors under RTL — `Icons.arrow_back` carries
                // matchTextDirection, asserted in icon_direction_test.dart.
                icon: 'arrow-back',
                semanticLabel: l10n.venueBack,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            // C-2.7 — the heart, opposite the back button.
            //
            // ON THE HERO, not in a menu. `RestaurantCard` puts a save control
            // on every card in the reference, so a diner who has learned the
            // gesture on a list looks for it here; burying it would make the
            // venue screen the one place the pattern does not hold.
            //
            // Signed out it is ABSENT rather than disabled: saving needs an
            // account, and a heart that opens a sign-in wall is a promise the
            // screen has not earned yet.
            if (signedIn)
              PositionedDirectional(
                end: SahraSpace.s5,
                top: SahraSpace.s5,
                child: SahraPhotoIconButton(
                  icon: 'heart',
                  // `active` — the component already has the gold saved state
                  // from the reference. A second way to say "saved" here would
                  // be a fifth heart that drifts from the other four.
                  active: saved,
                  semanticLabel: saved
                      ? l10n.savedRemoveLabel(venue.name)
                      : l10n.savedAddLabel(venue.name),
                  onPressed: () => toggleSavedAndReport(context, ref, restaurantId: venue.id),
                ),
              ),
            PositionedDirectional(
              start: SahraSpace.s5,
              end: SahraSpace.s5,
              bottom: SahraSpace.s4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    venue.name,
                    style: text.headlineMedium?.copyWith(color: s.onPhoto),
                  ),
                  const SizedBox(height: SahraSpace.s1),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      // The stars draw NOTHING when nobody has rated the venue
                      // — see `SahraRatingStars`. So the separator that used to
                      // join them to the meta line has to go with them, or the
                      // hero reads "· Levantine · $$$ · Zamalek" with a
                      // dangling dot where a rating is not.
                      //
                      // Found in the `Venue/no-reviews` golden, one fix after
                      // the one that caused it.
                      if (venue.ratingCount > 0) ...<Widget>[
                        SahraRatingStars(
                          rating: venue.rating,
                          reviews: venue.ratingCount,
                          semanticLabel: '${venue.rating} (${venue.ratingCount})',
                        ),
                        Text(
                          ' · ',
                          style: text.bodySmall?.copyWith(color: s.onPhoto),
                        ),
                      ],
                      Text(
                        venueMeta(l10n, venue.cuisines, venue.priceBand, venue.neighborhood),
                        style: text.bodySmall?.copyWith(color: s.onPhoto),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRows extends StatelessWidget {
  const _InfoRows({required this.venue});

  final VenueProfile venue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // `DateTime.weekday` is 1=Monday..7=Sunday; the schema is 0=Sunday.
    final today = DateTime.now().weekday % 7;
    final todaysHours = venue.hoursOn(today);

    return Column(
      children: <Widget>[
        _InfoRow(
          icon: 'clock',
          title: todaysHours.isEmpty ? l10n.venueClosedToday : l10n.venueOpenTonight,
          // Every shift, not just the first — a venue with lunch AND dinner is
          // ordinary, and showing one is how "closed at 16:30" ends up on a
          // page for somewhere serving until 23:30.
          // ltrRun: an un-isolated "18:00 – 23:30" renders as "23:30 – 18:00"
          // in an Arabic paragraph — opening hours that say the venue shuts
          // before it opens. Found by looking at an ar golden; no assertion
          // can see it, because the STRING is correct and only its layout is
          // reversed.
          detail: todaysHours
              .map((h) => ltrRun(l10n.venueHoursRange(h.opensAt, h.closesAt)))
              .join(' · '),
        ),
        if (venue.address != null)
          // The address carries a house number, so it is a mixed run too.
          _InfoRow(icon: 'map-pin', title: ltrRun(venue.address!), detail: venue.city),
        if (venue.phone != null)
          // "+20 2 2735 0000" rendered as "0000 2735 2 20+" — a phone number
          // nobody can dial. Same cause, same remedy.
          _InfoRow(icon: 'phone', title: ltrRun(venue.phone!), detail: l10n.venueCall),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.detail});

  final String icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: SahraSpace.symmetric(vertical: SahraSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SahraIcon(icon, size: SahraTypeScale.h3, color: s.accentOnSurface),
          const SizedBox(width: SahraSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: text.labelLarge?.copyWith(color: s.textBody)),
                if (detail.isNotEmpty)
                  Text(detail, style: text.bodySmall?.copyWith(color: s.textSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The sticky bar: "From / Free to book" beside the primary action.
class _BookBar extends StatelessWidget {
  const _BookBar({required this.venue});

  final VenueProfile venue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surfacePage,
        border: Border(top: BorderSide(color: s.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: SahraSpace.symmetric(
            horizontal: SahraSpace.s5,
            vertical: SahraSpace.s3,
          ),
          child: Row(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.venueBookingFrom,
                    style: text.bodySmall?.copyWith(
                      color: s.textSoft,
                      // See the ticket cell: 13px at regular weight measured
                      // 3.73 even though textSoft on surfacePage computes 7.4.
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l10n.venueBookingFree,
                    style: text.labelLarge?.copyWith(
                      color: s.textBody,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: SahraSpace.s4),
              Expanded(
                child: SahraButton(
                  label: l10n.venueBook,
                  onPressed: () => BookRoute(venue.id, venue.name).go(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VenueSkeleton extends StatelessWidget {
  const _VenueSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        const SahraSkeleton(height: 280, lattice: true),
        Padding(
          padding: SahraSpace.all(SahraSpace.s5),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SahraSkeleton(height: 20, width: 220),
              SizedBox(height: SahraSpace.s3),
              SahraSkeleton(height: 14),
              SizedBox(height: SahraSpace.s2),
              SahraSkeleton(height: 14),
              SizedBox(height: SahraSpace.s2),
              SahraSkeleton(height: 14, width: 180),
            ],
          ),
        ),
      ],
    );
  }
}
