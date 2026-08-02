import 'package:flutter/material.dart';

import '../theme/sahra_semantics.dart';

/// `docs/design/ui_kits/app/BookingFlowScreen.jsx` — the local `Label`
/// component: 11px, weight 700, `.14em` tracking, uppercase in Latin and
/// **not** uppercase in Arabic (`textTransform: ar ? 'none' : 'uppercase'`).
///
/// Discovered while building the booking path; used three times on one screen
/// (DATE / PARTY SIZE / TIME) and again on the confirmation ticket.
///
/// IT EXISTS TO OWN ONE DECISION. The reference colours it `--text-faint`. At
/// 11px that is the exact shape that has now failed `textContrastGuideline`
/// three times (Badge, the BookingWidget overline, the audit page) — and it
/// fails in Arabic before it fails in Latin, because IBM Plex Sans Arabic sets
/// lighter than Poppins at the same nominal size. Centralising it means the
/// answer is decided once and checked once, rather than re-litigated on every
/// screen that needs a small label.
class SahraSectionLabel extends StatelessWidget {
  const SahraSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Text(
      // Arabic has no letter case, so `toUpperCase` is a no-op on it — but
      // running it anyway would uppercase any Latin fragment inside an Arabic
      // string, which is precisely what the reference's `textTransform: none`
      // is avoiding.
      isArabic ? label : label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            // textSoft, not textFaint. See the class note — this is the AA
            // rule from DESIGN-RULES.md applied at the one place that decides.
            color: context.sahra.textSoft,
            // 700, matching `BookingFlowScreen.jsx`'s Label exactly. The
            // labelSmall token is 600, and at 11px that one step is the whole
            // AA margin: `textContrastGuideline` measures RENDERED coverage,
            // and thinner strokes are mostly antialiased edge. Measured 3.70
            // at 600, which is a fail; the reference was right and the token
            // default was the deviation.
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
