import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../shared/widgets/sahra_async_view.dart';
import '../../restaurants/presentation/venue_notifier.dart';
import '../domain/my_reservation.dart';
import '../../../shared/widgets/tappable_contact.dart';
import 'my_reservations_notifier.dart';
import 'reservation_actions.dart';
import 'reservation_copy.dart';

/// One booking in full — the ticket a diner shows at the door.
///
/// NO `.jsx` OF ITS OWN. The design package has fourteen screen references and
/// a reservation detail is not among them; `ConfirmationScreen.jsx` is the
/// nearest, and it is the post-booking celebration rather than a record you
/// come back to. So this reuses that reference's vocabulary — the perforated
/// ticket, the four-cell row, the code in the mono face — and adds the things a
/// celebration screen has no reason to carry: status, what the diner asked for,
/// and what to do if it needs to change. Reported as a gap rather than invented
/// silently.
///
/// MODIFY AND CANCEL WORK. Both landed in Group A against their own endpoints —
/// `PATCH /reservations/{id}` and `POST /reservations/{id}/cancel`, the second
/// deliberately NOT the venue's `POST /owner/reservations/{id}/cancel`, because
/// the actor recorded on the row is what the whole acknowledgement model keys
/// off.
///
/// They were shipped disabled for one batch, under a line saying so. That was
/// the right call while the endpoints did not exist — a diner who finds no
/// cancel button concludes the app cannot do it and stops looking — but a
/// disabled button is a promise with a date on it, and this is the date.
class ReservationScreen extends ConsumerWidget {
  const ReservationScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: SahraAppBar(
        title: Text(l10n.reservationTitle),
        leading: IconButton(
          icon: const SahraIcon('arrow-back'),
          tooltip: l10n.venueBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SahraPageWidth(
        child: SahraAsyncView<MyReservation>(
          value: ref.watch(reservationDetailProvider(id)),
          onRetry: () => ref.invalidate(reservationDetailProvider(id)),
          // A single reservation is never "empty" — it either loaded or it did
          // not. Saying so explicitly beats an `isEmpty` that lies about a
          // condition it cannot express.
          isEmpty: (_) => false,
          empty: (_) => const SizedBox.shrink(),
          loading: (_) => ListView(
            padding: SahraSpace.all(SahraSpace.s5),
            children: const <Widget>[
              SahraSkeleton(height: 220, radius: SahraRadius.lg),
              SizedBox(height: SahraSpace.s4),
              SahraSkeleton(height: 120, radius: SahraRadius.lg),
            ],
          ),
          content: (context, r) => _Detail(reservation: r),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.reservation});

  final MyReservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final r = reservation;

    return ListView(
      padding: SahraSpace.all(SahraSpace.s5),
      children: <Widget>[
        if (r.needsAcknowledgement) ...<Widget>[
          _CancelledNotice(reservation: r),
          const SizedBox(height: SahraSpace.s4),
        ],
        _Ticket(reservation: r),
        if (r.specialRequests != null || r.occasion != null) ...<Widget>[
          const SizedBox(height: SahraSpace.s5),
          if (r.occasion != null) _Detail_Row(label: l10n.reservationOccasion, value: r.occasion!),
          if (r.specialRequests != null)
            _Detail_Row(label: l10n.reservationSpecialRequests, value: r.specialRequests!),
        ],
        const SizedBox(height: SahraSpace.s6),
        _Actions(reservation: r),
      ],
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.reservation});

  final MyReservation reservation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final r = reservation;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surfaceCard,
        border: Border.all(color: s.line),
        borderRadius: SahraRadius.allOf(SahraRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SahraPhoto(
            height: 128,
            gradientOverlay: true,
            cue: false,
            child: PositionedDirectional(
              start: SahraSpace.s4,
              end: SahraSpace.s4,
              bottom: SahraSpace.s3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    venueName(r.venue, context),
                    style: text.headlineSmall?.copyWith(color: s.onPhoto),
                  ),
                  Text(
                    <String>[
                      if (r.venue.neighborhood != null) r.venue.neighborhood!,
                      r.venue.city,
                    ].join(' · '),
                    style: text.bodySmall?.copyWith(color: s.onPhoto),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: SahraSpace.all(SahraSpace.s4),
            child: Wrap(
              spacing: SahraSpace.s4,
              runSpacing: SahraSpace.s3,
              children: <Widget>[
                _Cell(label: l10n.reservationWhen, value: reservationWhen(r, context)),
                _Cell(label: l10n.reservationParty, value: '${r.partySize}'),
                _Cell(
                  label: l10n.reservationStatus,
                  value: reservationStatusLabel(r, l10n),
                ),
              ],
            ),
          ),
          const _Perforation(),
          Padding(
            padding: SahraSpace.all(SahraSpace.s4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SahraSectionLabel(l10n.reservationReference),
                    const SizedBox(height: SahraSpace.s1),
                    Text(
                      r.code,
                      style: SahraTypography.numeric(
                        text.labelLarge!.copyWith(
                          color: s.textBody,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SahraIcon('lantern', size: 20, color: s.premium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Wrap cell. Not `Expanded` in a Row, as the confirmation ticket uses:
/// this screen's third cell is a status word that can be "Cancelled by the
/// restaurant", and three equal columns turn that into four wrapped lines
/// beside two nearly-empty ones.
class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SahraSectionLabel(label),
          const SizedBox(height: SahraSpace.s1),
          // bodyLarge at 600, matching the confirmation ticket — see the note
          // there about why 14px failed contrast in Arabic and 16 does not.
          Text(
            value,
            style: text.bodyLarge?.copyWith(
              color: s.textBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: camel_case_types
class _Detail_Row extends StatelessWidget {
  const _Detail_Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: SahraSpace.inset(bottom: SahraSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SahraSectionLabel(label),
          const SizedBox(height: SahraSpace.s1),
          // ISOLATED. These are free text the DINER typed — "A quiet table away
          // from the speakers, please." — and a Latin sentence rendered in an
          // RTL paragraph puts its full stop at the START of the line. It did,
          // in the Arabic golden, and no assertion noticed.
          Text(ltrRun(value), style: text.bodyMedium?.copyWith(color: s.textBody)),
        ],
      ),
    );
  }
}

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
      padding: SahraSpace.all(SahraSpace.s4),
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
            style: text.bodyMedium?.copyWith(
              color: s.errorOnTint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SahraSpace.s3),
          // Primary — see the note on the same button in
          // `my_bookings_screen.dart`. A secondary button over the error tint
          // measures 3.98:1.
          SahraButton(
            label: l10n.bookingsAcknowledge,
            size: SahraButtonSize.sm,
            onPressed: busy
                ? null
                : () =>
                    ref.read(acknowledgeCancellationProvider.notifier).acknowledge(reservation.id),
          ),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.reservation});

  final MyReservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;
    final r = reservation;

    // Nothing to change about a booking that is already over or already
    // cancelled. The buttons are gone rather than disabled here — "cancel" on a
    // cancelled booking is not a missing feature, it is a nonsense.
    if (r.isCancelled || r.status == 'completed' || r.status == 'no_show') {
      return const SizedBox.shrink();
    }

    // A walk-in or a phoned-through booking was never made in this app, and
    // there is no diner-side handle on it at all.
    if (!r.isAppBooking) return const SizedBox.shrink();

    // Both live now (Group A). The disabled pair and the "not yet available"
    // line they sat under are gone — a button that has become real must stop
    // apologising for itself, and the line explaining why it did nothing would
    // otherwise outlive the reason.
    //
    // MODIFY IS HIDDEN ONCE THE BOOKING HAS STARTED, cancel is not. The server
    // refuses a move after `starts_at` (`reservation_not_modifiable`) because
    // moving a booking whose time has passed is incoherent, but a late cancel
    // is strictly better for the venue than the no-show it replaces. Showing a
    // modify button that can only fail would be a promise the API will break.
    final canMove = DateTime.tryParse(r.startsAt)?.isAfter(DateTime.now()) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (canMove) ...<Widget>[
          SahraButton(
            label: l10n.reservationModify,
            variant: SahraButtonVariant.secondary,
            onPressed: () => showMoveSheet(context, ref, reservation: r),
          ),
          const SizedBox(height: SahraSpace.s3),
        ],
        SahraButton(
          label: l10n.reservationCancel,
          variant: SahraButtonVariant.ghost,
          onPressed: () => showCancelSheet(context, ref, reservation: r),
        ),
        const SizedBox(height: SahraSpace.s5),
        // KEPT, and not as a leftover. The venue's number is the answer to
        // everything these two buttons do not cover — a dietary note, a late
        // arrival, a table by the window — and it was the only answer at all
        // before this batch.
        Text(
          l10n.reservationCallInstead,
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: s.textSoft),
        ),
        const SizedBox(height: SahraSpace.s2),
        _VenuePhone(slug: r.venue.slug),
      ],
    );
  }
}

/// The restaurant's number, so "call them instead" is actionable.
///
/// A SECOND REQUEST, and deliberately: `GET /reservations/{id}` returns id,
/// slug, both names, city, neighborhood and timezone — no phone. Rather than
/// widen that response for one screen, the detail loads the public profile it
/// already has a provider for, keyed by slug so it is the same cache entry the
/// venue screen fills.
///
/// IT DIALS NOW. `url_launcher` was approved on 2026-08-08 for `tel:` and
/// `mailto:` together (doc 08 §5), so the number opens the dialler — and stays
/// readable and copyable where nothing can open it, which is the half that
/// matters. See `SahraTappableContact`.
class _VenuePhone extends ConsumerWidget {
  const _VenuePhone({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final phone = ref.watch(venueProfileProvider(slug)).valueOrNull?.phone;

    // No phone, no row. A blank "Call the restaurant:" with nothing after it is
    // worse than the silence.
    if (phone == null || phone.isEmpty) return const SizedBox.shrink();

    return SahraTappableContact(
      display: phone,
      // Built from the profile's own value, never re-parsed from what is drawn.
      uri: Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
      semanticLabel: l10n.reservationCallVenue,
      textAlign: TextAlign.center,
      style: SahraTypography.numeric(
        text.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    return SizedBox(
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLine(s.line),
          ),
          PositionedDirectional(start: -7, child: _Notch(s)),
          PositionedDirectional(end: -7, child: _Notch(s)),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch(this.s);
  final SahraSemantics s;

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: s.surfacePage,
          border: Border.all(color: s.line),
        ),
      );
}

class _DashedLine extends CustomPainter {
  _DashedLine(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.colour != colour;
}
