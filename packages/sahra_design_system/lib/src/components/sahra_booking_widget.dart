import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_button.dart';
import 'sahra_chip.dart';
import 'sahra_icon.dart';

/// Copy for [SahraBookingWidget], supplied already localised.
///
/// A design-system component owns no strings, and this one needs eight of
/// them — so they arrive as a group rather than as eight loose parameters that
/// are easy to leave in English.
class SahraBookingCopy {
  const SahraBookingCopy({
    required this.overline,
    required this.partySize,
    required this.book,
    required this.confirmedTitle,
    required this.confirmedBody,
    required this.changePlans,
    required this.decreaseParty,
    required this.increaseParty,
  });

  final String overline;
  final String partySize;
  final String book;
  final String confirmedTitle;

  /// Receives the party size, time and venue already interpolated.
  final String confirmedBody;
  final String changePlans;

  /// Accessible names for the stepper — the only label a screen reader gets.
  final String decreaseParty;
  final String increaseParty;
}

/// `docs/design/components/venue/BookingWidget.d.ts` —
/// `{venue, times, defaultTime, defaultParty, onBook}`.
///
/// The booking card: party stepper, slot chips, confirm. Composed from
/// [SahraButton], [SahraChip] and [SahraIcon] — nothing here draws a control
/// of its own.
///
/// THE SLOTS ARE A HINT, NOT AN OFFER. Availability is decided server-side at
/// the moment of the write (doc 05 §1), so a time shown here can be gone by
/// the time it is tapped. The widget therefore reports the choice and lets the
/// caller deal with `slot_taken`; it never presents a booking as done on its
/// own authority. [confirmed] is driven from outside for exactly that reason.
class SahraBookingWidget extends StatefulWidget {
  const SahraBookingWidget({
    required this.venue,
    required this.times,
    required this.copy,
    this.defaultTime,
    this.defaultParty = 2,
    this.confirmed = false,
    this.onBook,
    this.onChangePlans,
    this.width = 320,
    super.key,
  });

  final String venue;

  /// Local wall-clock strings, already formatted by the caller — the widget
  /// does not know about timezones and must not guess.
  final List<String> times;
  final SahraBookingCopy copy;
  final String? defaultTime;
  final int defaultParty;

  /// Set by the CALLER once the server confirmed. Never inferred from a tap.
  final bool confirmed;

  final void Function(int party, String time)? onBook;
  final VoidCallback? onChangePlans;
  final double width;

  static const int minParty = 1;
  static const int maxParty = 12;

  @override
  State<SahraBookingWidget> createState() => _SahraBookingWidgetState();
}

class _SahraBookingWidgetState extends State<SahraBookingWidget> {
  late int _party = widget.defaultParty;
  late String _time = widget.defaultTime ?? widget.times.first;

  void _step(int delta) => setState(() {
        _party = (_party + delta).clamp(SahraBookingWidget.minParty, SahraBookingWidget.maxParty);
      });

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return Container(
      width: widget.width,
      padding: SahraSpace.all(SahraSpace.s5),
      decoration: BoxDecoration(
        color: s.surfaceCard,
        borderRadius: SahraRadius.allOf(SahraRadius.lg),
        border: Border.all(color: s.line),
        // On dark, elevation is a lighter surface rather than a shadow.
        boxShadow: s.shadow(SahraElevation.e2),
      ),
      child: widget.confirmed ? _confirmed(context, s) : _form(context, s),
    );
  }

  Widget _form(BuildContext context, SahraSemantics s) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.copy.overline.toUpperCase(),
          // NOT the 11px overline token, and not caption either.
          //
          // A COLOURED micro-label fails textContrastGuideline at both sizes
          // even though the pair computes to 6:1 — the antialiased strokes are
          // too thin to carry the colour. And it fails in ARABIC ONLY: IBM
          // Plex Sans Arabic sets lighter than Poppins at the same nominal
          // size, so Arabic needs more size or weight than Latin for the same
          // effective contrast. Third instance of this class; see the wave-3
          // report.
          style: theme.textTheme.labelSmall?.copyWith(
            color: s.accentOnSurface,
            fontSize: SahraTypeScale.bodyS,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: SahraSpace.s3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              widget.copy.partySize,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            Row(
              children: <Widget>[
                SahraButton(
                  iconOnly: true,
                  size: SahraButtonSize.sm,
                  variant: SahraButtonVariant.ghost,
                  icon: const SahraIcon('x', size: 14),
                  label: widget.copy.decreaseParty,
                  onPressed: _party > SahraBookingWidget.minParty ? () => _step(-1) : null,
                ),
                SizedBox(
                  width: SahraSpace.s10,
                  child: Text(
                    // Latin digits in both locales (DESIGN-RULES.md).
                    '$_party',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                SahraButton(
                  iconOnly: true,
                  size: SahraButtonSize.sm,
                  variant: SahraButtonVariant.ghost,
                  icon: const SahraIcon('plus', size: 14),
                  label: widget.copy.increaseParty,
                  onPressed: _party < SahraBookingWidget.maxParty ? () => _step(1) : null,
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: SahraSpace.s4),
        Wrap(
          spacing: SahraSpace.s2,
          runSpacing: SahraSpace.s2,
          children: <Widget>[
            for (final t in widget.times)
              SahraChip(
                label: t,
                active: t == _time,
                onPressed: () => setState(() => _time = t),
              ),
          ],
        ),
        SizedBox(height: SahraSpace.s5),
        SizedBox(
          width: double.infinity,
          child: SahraButton(
            label: widget.copy.book,
            onPressed: widget.onBook == null ? null : () => widget.onBook!(_party, _time),
          ),
        ),
      ],
    );
  }

  Widget _confirmed(BuildContext context, SahraSemantics s) {
    final theme = Theme.of(context);

    return Semantics(
      // A confirmation is the one thing on this card a screen reader must not
      // miss, so it announces itself when it appears.
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SahraIcon('check', size: SahraSpace.s8, color: s.success),
          SizedBox(height: SahraSpace.s2),
          Text(widget.copy.confirmedTitle, style: theme.textTheme.headlineSmall),
          SizedBox(height: SahraSpace.s2),
          Text(
            widget.copy.confirmedBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: s.textSoft),
          ),
          SizedBox(height: SahraSpace.s3),
          SahraButton(
            label: widget.copy.changePlans,
            variant: SahraButtonVariant.ghost,
            size: SahraButtonSize.sm,
            onPressed: widget.onChangePlans,
          ),
        ],
      ),
    );
  }
}
