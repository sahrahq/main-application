import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_icon.dart';

class SahraVisit {
  const SahraVisit({required this.name, required this.date, this.note});

  final String name;

  /// Already formatted and localised — the component does not know calendars.
  final String date;
  final String? note;
}

/// `docs/design/components/brand/DiningTrail.d.ts` — `{visits}`.
///
/// Past visits as a connected string of lantern nodes. The reference is
/// explicit about why it is not a photo grid: "SAHRA's product is connected
/// memories, not isolated bookings; the trail makes that literal."
///
/// The newest visit glows. Everything below it is a hollow node on a fading
/// line, so the eye starts at the top and the sequence reads without a legend.
class SahraDiningTrail extends StatelessWidget {
  const SahraDiningTrail({required this.visits, super.key});

  final List<SahraVisit> visits;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < visits.length; i++)
          _TrailRow(
            visit: visits[i],
            glow: i == 0,
            last: i == visits.length - 1,
            semantics: s,
          ),
      ],
    );
  }
}

class _TrailRow extends StatelessWidget {
  const _TrailRow({
    required this.visit,
    required this.glow,
    required this.last,
    required this.semantics,
  });

  final SahraVisit visit;
  final bool glow;
  final bool last;
  final SahraSemantics semantics;

  @override
  Widget build(BuildContext context) {
    final s = semantics;
    final theme = Theme.of(context);
    const node = 26.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: node,
                height: node,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glow ? s.premium : null,
                  border: glow ? null : Border.all(color: s.line, width: 1.5),
                  boxShadow: glow
                      ? s.shadow(<BoxShadow>[
                          BoxShadow(
                            color: s.premium.withValues(alpha: 0.55),
                            blurRadius: 18,
                          ),
                        ])
                      : null,
                ),
                alignment: Alignment.center,
                child: SahraIcon(
                  'lantern',
                  size: 16,
                  // On the glowing node the lantern sits on gold, so it takes
                  // ink; elsewhere it is the gold mark itself.
                  color: glow ? SahraSemantics.light().textBody : s.warning,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: SahraSpace.inset(top: SahraSpace.s1),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[s.line, s.line.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: SahraSpace.s4),
          Expanded(
            child: Padding(
              padding: SahraSpace.inset(bottom: last ? 0 : SahraSpace.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(visit.name, style: theme.textTheme.headlineSmall),
                  SizedBox(height: SahraSpace.s1),
                  Text(
                    visit.note == null ? visit.date : '${visit.date} · ${visit.note}',
                    style: theme.textTheme.labelMedium?.copyWith(color: s.textFaint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
