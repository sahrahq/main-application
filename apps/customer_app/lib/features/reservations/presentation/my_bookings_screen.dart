import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import '../../../shared/providers/session_providers.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../domain/my_reservation.dart';
import 'my_reservations_notifier.dart';
import 'reservation_copy.dart';

/// `docs/design/ui_kits/app/MyBookingsScreen.jsx`.
///
/// WHERE THIS AND THE REFERENCE DISAGREE:
///
///   - **The 64px photo on each card.** `GET /reservations` returns
///     `ReservationVenueResponse` — id, slug, both names, city, neighborhood,
///     timezone. No image. Fetching a profile per row to get one would be an
///     N+1 on the screen a diner opens at the restaurant door, so the card
///     leads with the venue name instead. R-2.2 (venue images) is where this
///     comes back.
///   - **The "watching for a table" banner.** Waitlist is C-3.6, P1, and there
///     are no endpoints. A banner promising to ping someone is worse than no
///     banner.
///   - **The past tab is the DiningTrail**, exactly as the reference draws it,
///     and the trail component already exists.
///
/// WHAT THE REFERENCE DOES NOT HAVE, and this must: the venue-cancellation
/// notice. `needs_acknowledgement` is the only signal a diner gets that a
/// booking they believe they hold is gone. It is drawn first, in the strongest
/// treatment on the screen, and it does not leave until it is acknowledged.
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(bookingsViewProvider);
    final signedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      body: SahraPageWidth(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: SahraSpace.inset(
                  start: SahraSpace.s5,
                  end: SahraSpace.s5,
                  top: SahraSpace.s5,
                  bottom: SahraSpace.s2,
                ),
                child: Text(
                  l10n.bookingsTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (signedIn)
                _Tabs(
                  view: view,
                  onChanged: ref.read(bookingsViewProvider.notifier).show,
                ),
              Expanded(
                child: signedIn ? const _List() : const _SignedOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.view, required this.onChanged});

  final String view;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.line)),
      ),
      child: Padding(
        padding: SahraSpace.symmetric(horizontal: SahraSpace.s5),
        child: Row(
          children: <Widget>[
            for (final entry in <(String, String)>[
              ('upcoming', l10n.bookingsUpcoming),
              ('past', l10n.bookingsPast),
            ])
              // FLEXIBLE, not Expanded and not bare.
              //
              // Bare, the two English labels are 60px wider than the screen at
              // 200% text and the Row overflowed — Arabic passed, because
              // «الجاي» and «اللي فات» are shorter than "Upcoming" and "Past",
              // which is the one direction this product's layout bugs usually
              // do NOT run in.
              //
              // Expanded would fix it too, by giving each tab half the width —
              // and a half-screen underline under a four-letter word is not
              // what the reference draws. Flexible keeps the compact underline
              // at normal sizes and only lets the label wrap when it must.
              Flexible(
                child: Padding(
                  padding: SahraSpace.inset(end: SahraSpace.s5),
                  child: _Tab(
                    label: entry.$2,
                    selected: entry.$1 == view,
                    onTap: () => onChanged(entry.$1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // 48, not the 44 in DESIGN-RULES.md, and not 44 in one direction.
          //
          // Two guidelines run here and they disagree: iOS asks for 44x44,
          // Android for 48x48. The stricter one is the requirement — a 44px
          // control is a control that fails on the platform most of this
          // market is on. Both numbers were found the same way, by the
          // guidelines failing, not by reading them: minHeight alone left
          // "Past" at 32.1 x 44 because a tab is only as wide as its word.
          //
          // The underline sits at the bottom of the padded box rather than
          // under the text, so growing the target does not detach the indicator
          // from the label it indicates.
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          alignment: AlignmentDirectional.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? s.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? s.textBody : s.textFaint,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: SahraSpace.all(SahraSpace.s5),
      child: SahraEmptyState(
        icon: 'user',
        title: l10n.bookingsSignedOutTitle,
        message: l10n.bookingsSignedOutMessage,
        actionLabel: l10n.bookingsSignedOutAction,
        onAction: () => const SignInRoute().go(context),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(bookingsViewProvider);
    final past = view == 'past';

    return SahraAsyncView<List<MyReservation>>(
      value: ref.watch(myReservationsProvider),
      onRetry: () => ref.invalidate(myReservationsProvider),
      isEmpty: (list) => list.isEmpty,
      loading: (_) => ListView(
        padding: SahraSpace.all(SahraSpace.s5),
        children: <Widget>[
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsetsDirectional.only(bottom: SahraSpace.s3),
              child: SahraSkeleton(height: 92, radius: SahraRadius.lg),
            ),
        ],
      ),
      empty: (context) => SingleChildScrollView(
        padding: SahraSpace.all(SahraSpace.s5),
        child: SahraEmptyState(
          icon: past ? 'lantern' : 'calendar',
          title: past ? l10n.bookingsEmptyPastTitle : l10n.bookingsEmptyUpcomingTitle,
          message: past ? l10n.bookingsEmptyPastMessage : l10n.bookingsEmptyUpcomingMessage,
          // No action on the past tab. "Find somewhere" under an empty history
          // is the same button as under an empty upcoming list, and offering it
          // twice makes the past tab look like a second, broken copy of the
          // first.
          actionLabel: past ? null : l10n.bookingsEmptyUpcomingAction,
          onAction: past ? null : () => const SearchRoute().go(context),
        ),
      ),
      content: (context, list) =>
          past ? _PastTrail(list: list) : _UpcomingList(list: list),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.list});

  final List<MyReservation> list;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: SahraSpace.all(SahraSpace.s5),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: SahraSpace.s3),
        itemBuilder: (context, i) => _BookingCard(reservation: list[i]),
      );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.reservation});

  final MyReservation reservation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final r = reservation;

    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: () => ReservationRoute(r.id).go(context),
        borderRadius: SahraRadius.allOf(SahraRadius.lg),
        child: Container(
          padding: SahraSpace.all(SahraSpace.s4),
          decoration: BoxDecoration(
            color: s.surfaceCard,
            // The cancelled-and-unseen card is outlined in the error colour.
            // Colour is the SECOND channel here, never the only one — the
            // notice below spells it out in words, per WCAG 1.4.1.
            border: Border.all(color: r.needsAcknowledgement ? s.error : s.line),
            borderRadius: SahraRadius.allOf(SahraRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // A Wrap, not a Row with an Expanded title.
              //
              // At 200% text "Awaiting confirmation" is wider than the card on
              // its own, so no amount of shrinking the title makes room for it
              // and the Row overflowed by 68px. A Wrap puts the badge on its
              // own line instead, which is the only honest answer when the two
              // genuinely do not fit side by side.
              Wrap(
                spacing: SahraSpace.s2,
                runSpacing: SahraSpace.s1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(venueName(r.venue, context), style: text.titleMedium),
                  SahraBadge(
                    label: reservationStatusLabel(r, l10n),
                    variant: reservationStatusVariant(r),
                  ),
                ],
              ),
              const SizedBox(height: SahraSpace.s2),
              _MetaRow(
                icon: 'calendar',
                label: reservationWhen(r, context),
                colour: s.textSoft,
              ),
              const SizedBox(height: SahraSpace.s1),
              _MetaRow(
                icon: 'users',
                label: l10n.bookingsPartyOf(r.partySize),
                colour: s.textFaint,
              ),
              if (r.needsAcknowledgement) ...<Widget>[
                const SizedBox(height: SahraSpace.s3),
                _CancelledNotice(reservation: r),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.colour});

  final String icon;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          SahraIcon(icon, size: 14, color: colour),
          const SizedBox(width: SahraSpace.s2),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colour),
            ),
          ),
        ],
      );
}

/// The restaurant cancelled and the diner has not seen it.
///
/// ACKNOWLEDGED FROM THE CARD, not only from the detail screen. The list is
/// where a diner checks tonight's plan, and requiring a tap into a detail
/// screen to clear a notice means the notice is still on the list for anyone
/// who only glanced.
class _CancelledNotice extends ConsumerWidget {
  const _CancelledNotice({required this.reservation});

  final MyReservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(acknowledgeCancellationProvider);

    return Container(
      width: double.infinity,
      padding: SahraSpace.all(SahraSpace.s3),
      decoration: BoxDecoration(
        color: s.tintFor(s.error),
        borderRadius: SahraRadius.allOf(SahraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // BOTH ARGUMENTS ISOLATED. The venue name may be Latin and the
            // reason is free text a restaurant typed — in either script,
            // possibly both. Dropped unisolated into an Arabic sentence the
            // bidi algorithm reorders the boundary punctuation, and the golden
            // showed the full stop of an English reason landing at the START of
            // the line.
            l10n.reservationCancelledNotice(
              ltrRunOrNull(venueName(reservation.venue, context))!,
              ltrRunOrNull(reservation.cancelReason) ?? l10n.errUnknown,
            ),
            style: text.bodySmall?.copyWith(
              color: s.errorOnTint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SahraSpace.s2),
          // PRIMARY, on purpose, and not the secondary this started as.
          //
          // A secondary button is a border and a label over whatever is
          // behind it — and what is behind it here is the error tint, which
          // dragged its 13px label to 3.98:1. AA outranks the reference
          // (DESIGN-RULES.md), so the button brings its own opaque fill and
          // the label is measured against that instead.
          SahraButton(
            label: l10n.bookingsAcknowledge,
            size: SahraButtonSize.sm,
            onPressed: busy
                ? null
                : () => ref
                    .read(acknowledgeCancellationProvider.notifier)
                    .acknowledge(reservation.id),
          ),
        ],
      ),
    );
  }
}

class _PastTrail extends StatelessWidget {
  const _PastTrail({required this.list});

  final List<MyReservation> list;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: SahraSpace.all(SahraSpace.s5),
      children: <Widget>[
        SahraDiningTrail(
          visits: <SahraVisit>[
            for (final r in list)
              SahraVisit(
                name: venueName(r.venue, context),
                date: reservationWhen(r, context),
                note: l10n.bookingsPartyOf(r.partySize),
              ),
          ],
        ),
      ],
    );
  }
}
