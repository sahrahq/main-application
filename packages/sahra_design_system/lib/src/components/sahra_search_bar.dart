import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';
import 'sahra_icon.dart';

/// `docs/design/components/navigation/SearchBar.d.ts` —
/// `{placeholder, location, onChange}`.
///
/// The pill at the top of Discover. The trailing city is not decoration — it
/// is the scope of the search, and a diner needs to see they are searching
/// Cairo and not everywhere.
class SahraSearchBar extends StatelessWidget {
  const SahraSearchBar({
    required this.hint,
    this.location,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.semanticLabel,
    super.key,
  });

  /// Already localised.
  final String hint;
  final String? location;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    return Semantics(
      textField: true,
      label: semanticLabel ?? hint,
      child: Container(
        padding: SahraSpace.symmetric(horizontal: SahraSpace.s4),
        decoration: BoxDecoration(
          color: s.surfaceSunken,
          borderRadius: SahraRadius.allOf(SahraRadius.pill),
          border: Border.all(color: s.line),
        ),
        child: Row(
          children: <Widget>[
            SahraIcon('search', size: SahraSpace.s4, color: s.textFaint),
            SizedBox(width: SahraSpace.s3),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: s.textBody),
                decoration: InputDecoration(
                  isDense: true,
                  // The minimum lives on the FIELD, not the pill around it —
                  // the field is what owns the tap action, and a 48dp pill
                  // wrapped around a 21dp target still fails the guideline.
                  constraints: const BoxConstraints(
                    minHeight: SahraRules.minTouchTarget,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: s.textFaint),
                ),
              ),
            ),
            if (location != null) ...<Widget>[
              SizedBox(width: SahraSpace.s3),
              Text(
                location!,
                // The reference uses raw `gold`, which fails AA as text
                // (2.5–2.8:1 on these surfaces). `premium` is a fill colour;
                // the readable member of that family is what a label needs.
                // AA outranks the reference (DESIGN-RULES.md).
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: s.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
