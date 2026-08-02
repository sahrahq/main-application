import 'package:flutter/material.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';

/// `docs/design/ui_kits/app/ConfirmationScreen.jsx` — the perforated ticket.
///
/// WHAT IS NOT HERE:
///
///   - **Add to calendar** and **Invite friends** (C-3.7 / C-3.8). Both are
///     drawn in the reference; neither has an implementation. A button that
///     does nothing is a worse experience than no button, so they are absent
///     rather than disabled.
///   - **The Table cell.** The reference's ticket shows `Table T4`. The confirm
///     response carries no table assignment — allocation is the engine's
///     business and can change before service (doc 05 §2 combination
///     fallback), so promising a table number on a ticket would be a promise
///     the platform has not made.
///
/// The three cells that DO show — date, time, guests — come from the confirmed
/// reservation, plus the code a diner quotes at the door.
class ConfirmedScreen extends StatelessWidget {
  const ConfirmedScreen({
    required this.code,
    required this.venueName,
    required this.startsAt,
    required this.partySize,
    super.key,
  });

  final String code;
  final String venueName;

  /// ISO-8601 UTC, as the API returned it.
  final String startsAt;
  final int partySize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SahraPageWidth(
        child: SafeArea(
        // Centred when it fits, scrolled when it does not.
        //
        // Two Spacers around a fixed ticket overflowed by 191px at 320x568
        // with 200% text — the single worst of the five, and on the screen a
        // diner is most likely to show someone at the door.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
          padding: SahraSpace.all(SahraSpace.s5),
          child: Column(
            children: <Widget>[
              const Spacer(),
              _Sparkle(),
              const SizedBox(height: SahraSpace.s3),
              SahraSectionLabel(l10n.confirmedOverline),
              const SizedBox(height: SahraSpace.s2),
              Text(
                l10n.confirmedMessage(venueName),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: s.textSoft),
              ),
              const SizedBox(height: SahraSpace.s5),
              _Ticket(
                venueName: venueName,
                code: code,
                startsAt: startsAt,
                partySize: partySize,
              ),
              const Spacer(),
              SahraButton(
                label: l10n.confirmedDone,
                onPressed: () => const SearchRoute().go(context),
              ),
            ],
          ),
                ),
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: s.premium, width: 1.5),
      ),
      child: Center(child: SahraIcon('spark', size: 20, color: s.premium)),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.venueName,
    required this.code,
    required this.startsAt,
    required this.partySize,
  });

  final String venueName;
  final String code;
  final String startsAt;
  final int partySize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    // The instant comes back UTC; a diner reads it in their own clock. This is
    // the ONE place a local rendering is right — it is describing a moment
    // that has already been committed, not asking for one.
    final when = DateTime.parse(startsAt).toLocal();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surfaceCard,
        border: Border.all(color: s.line),
        borderRadius: SahraRadius.allOf(SahraRadius.lg),
      ),
      child: Column(
        children: <Widget>[
          SahraPhoto(
            height: 128,
            gradientOverlay: true,
            cue: false,
            child: PositionedDirectional(
              start: SahraSpace.s4,
              end: SahraSpace.s4,
              bottom: SahraSpace.s3,
              child: Text(
                venueName,
                style: text.headlineSmall?.copyWith(color: s.onPhoto),
              ),
            ),
          ),
          Padding(
            padding: SahraSpace.all(SahraSpace.s4),
            child: Row(
              children: <Widget>[
                _Cell(label: l10n.confirmedDate, value: _date(context, when)),
                _Cell(label: l10n.confirmedTime, value: _time(context, when)),
                _Cell(label: l10n.confirmedGuests, value: '$partySize'),
              ],
            ),
          ),
          // The perforation. A dashed rule with a notch punched out of each
          // side, in the page colour so it reads as a tear rather than a line.
          const _Perforation(),
          Padding(
            padding: SahraSpace.all(SahraSpace.s4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SahraSectionLabel(l10n.confirmedReference),
                    const SizedBox(height: SahraSpace.s1),
                    Text(
                      code,
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

  /// Latin digits for the day, localised name for the month.
  ///
  /// `DateFormat.MMMMd('ar')` renders ٥ أغسطس — Arabic-Indic numerals, which
  /// DESIGN-RULES.md rules out for figures, and `intl` has no flag to localise
  /// the month while keeping the numeral Latin. So the month name is looked up
  /// and the day is written directly.
  String _date(BuildContext context, DateTime when) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return '${when.day} ${_months[ar ? 'ar' : 'en']![when.month - 1]}';
  }

  String _time(BuildContext context, DateTime when) =>
      '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
}

/// Month names in both locales. See `_date` above for why these are not read
/// from `intl`'s CLDR data.
const Map<String, List<String>> _months = <String, List<String>>{
  'en': <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ],
  'ar': <String>[
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ],
};

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SahraSectionLabel(label),
          const SizedBox(height: SahraSpace.s1),
          Text(
            value,
            // bodyLarge (16px) at 600, NOT labelLarge (14px).
            //
            // The reference sets these cells at 15px/600. At 14px they
            // measured 4.32 — and the Arabic cell was the one that failed
            // last, exactly as ENGINEERING-STANDARDS predicts: "5 أغسطس" sets
            // in IBM Plex Sans Arabic, which is lighter than Poppins at the
            // same nominal size AND ships no weight above 600, so w700 is not
            // a lever here. Colour cannot help either — this is already
            // textBody, the darkest token there is. Size was the only one
            // left, and 16 is the nearest step on the type ramp to the
            // reference's 15.
            //
            // NOT `SahraTypography.numeric`: these values are mixed content
            // ("5 أغسطس"), and pinning the Latin face over an Arabic month
            // name is how the month renders in a fallback font.
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
