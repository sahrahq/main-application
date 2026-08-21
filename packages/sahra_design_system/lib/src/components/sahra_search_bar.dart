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
class SahraSearchBar extends StatefulWidget {
  const SahraSearchBar({
    required this.hint,
    this.location,
    this.locationSemanticLabel,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.semanticLabel,
    super.key,
  });

  /// Already localised.
  final String hint;
  final String? location;

  /// What a screen reader says for [location]. Defaults to the visible text,
  /// which is a bare city name — a screen supplying "searching in Cairo" gives
  /// a listener the same information the sighted layout gives by position.
  final String? locationSemanticLabel;

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? semanticLabel;

  @override
  State<SahraSearchBar> createState() => _SahraSearchBarState();
}

class _SahraSearchBarState extends State<SahraSearchBar> {
  /// Owned here so a tap anywhere on the pill can focus the field. See the
  /// note on [MergeSemantics] below.
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;

    // MERGED, AND THE WHOLE PILL REALLY IS THE TARGET.
    //
    // `iOSTapTargetGuideline` measures the node carrying `SemanticsAction.tap`,
    // which is the TextField's — 235x21, and it failed. The original comment
    // here was right that a 48-point pill wrapped around a 21-point field does
    // not satisfy it, and moving the minimum onto the pill did not change that
    // by itself.
    //
    // What changes it is making the claim TRUE: the GestureDetector below
    // focuses the field from anywhere in the pill, and MergeSemantics folds the
    // field's node into the pill's, so the one node that carries the tap action
    // is the one a finger can actually hit. Both halves are needed — merging
    // without the gesture would announce a target that does nothing at its
    // edges, which is worse than the small target it replaced.
    return MergeSemantics(
      child: Semantics(
        textField: true,
        label: widget.semanticLabel ?? widget.hint,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focus.requestFocus,
          child: Container(
            // THE HEIGHT LIVES ON THE PILL NOW, not on the field's decoration.
            //
            // `InputDecoration.constraints` wraps the decorator in a ConstrainedBox
            // and the decorator sizes to its own 21-point content INSIDE it, at the
            // top. `textAlignVertical` cannot help — it aligns text within the
            // decorator, and the decorator was never the tall thing. Measured after
            // trying exactly that: field y 21–69, hint still y 21–42.
            //
            // With the minimum on the pill, the field sizes to its own text and
            // the Row centres it — so the hint, the magnifier and the city all sit
            // on one line, which is what the reference draws.
            //
            // The tap target moved with it: the accessible node is the `Semantics`
            // wrapper around this whole pill, which is 48 tall by this constraint.
            // Asserted by `component_a11y_test.dart`, not assumed — the original
            // comment claimed a pill-sized target would fail the guideline, and
            // that claim was never measured.
            constraints: const BoxConstraints(minHeight: SahraRules.minTouchTarget),
            padding: SahraSpace.symmetric(horizontal: SahraSpace.s4),
            decoration: BoxDecoration(
              color: s.surfaceSunken,
              borderRadius: SahraRadius.allOf(SahraRadius.pill),
              border: Border.all(color: s.line),
            ),
            // Default `center` alignment. `stretch` was tried and is wrong here:
            // the pill has a MINIMUM height, not a fixed one, so the row's height
            // is unbounded and stretching into it asserts "BoxConstraints forces an
            // infinite height". The pill must stay free to grow at 200% text.
            child: Row(
              children: <Widget>[
                SahraIcon('search', size: SahraSpace.s4, color: s.textFaint),
                SizedBox(width: SahraSpace.s3),
                Expanded(
                  child: TextField(
                    focusNode: _focus,
                    controller: widget.controller,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    // THE HINT WAS SITTING AT THE TOP OF THE PILL.
                    //
                    // `InputDecoration.constraints.minHeight` below forces the
                    // decorator's box to 48. `InputDecorator` does not centre its
                    // input inside a box larger than the input needs — it aligns
                    // to the TOP unless told otherwise — so with
                    // `contentPadding: EdgeInsets.zero` the 21pt hint sat in the
                    // top 21 points of a 48-point box while the magnifier and the
                    // city label, being ordinary Row children, centred normally.
                    // Measured: field y 21–69, hint y 21–42. It reads as text
                    // escaping above the pill.
                    //
                    // This is the alignment fix, not a padding number. Padding
                    // that happened to add 13.5 at the top would break the moment
                    // the minimum, the text size or the font changed.
                    textAlignVertical: TextAlignVertical.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: s.textBody),
                    decoration: InputDecoration(
                      isDense: true,
                      // ── `border: InputBorder.none` IS NOT ENOUGH ──────────
                      //
                      // `InputDecoration.border` is only the FALLBACK. When the
                      // theme sets `enabledBorder` / `focusedBorder` — and
                      // `SahraTheme.inputDecorationTheme` sets both, as
                      // `OutlineInputBorder` at radius `md` — those win, and the
                      // field drew its own rounded rectangle INSIDE the pill.
                      //
                      // Two nested outlines with different radii (md inside
                      // pill) and different heights (the decorator sizes to its
                      // own 21–24pt content and centres in the 48pt pill), so
                      // the edges could not line up and it read as two controls
                      // rather than one. Worse when focused, because
                      // `focusedBorder` switches to `accent` — a focus ring on a
                      // control that is not the one the diner sees.
                      //
                      // Every state is silenced explicitly. Naming only
                      // `enabled` and `focused` would leave the error states to
                      // reappear the first time this field gets validation.
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      // The theme also sets `filled: true` with `surfaceSunken`,
                      // which is the pill's own colour — invisible today, and a
                      // second fill to chase the moment either changes.
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.hint,
                      hintStyle:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(color: s.textFaint),
                    ),
                  ),
                ),
                if (widget.location != null) ...<Widget>[
                  // A RULE, NOT A GAP. The city used to sit flush against the
                  // field with nothing between them, so it read as a word someone
                  // had typed rather than as the scope of the search.
                  SizedBox(width: SahraSpace.s3),
                  Container(
                    width: 1,
                    height: SahraSpace.s5,
                    color: s.line,
                  ),
                  SizedBox(width: SahraSpace.s3),
                  // NOT A BUTTON, AND DELIBERATELY NOT DRESSED AS ONE.
                  //
                  // There is no chevron and no tap target because there is nothing
                  // to open: city switching is not built (SEARCH-1) — `/restaurants/
                  // search` takes no city parameter and every seeded venue is in
                  // Cairo. A chevron here would be the waitlist bell again, a
                  // control that fails on tap.
                  //
                  // It stays because a diner does need to know they are searching
                  // Cairo and not everywhere, and the semantics say which of the
                  // two things it is so a screen reader does not announce a button.
                  Semantics(
                    label: widget.locationSemanticLabel ?? widget.location,
                    readOnly: true,
                    child: Text(
                      widget.location!,
                      // The reference uses raw `gold`, which fails AA as text
                      // (2.5–2.8:1 on these surfaces). `premium` is a fill colour;
                      // the readable member of that family is what a label needs.
                      // AA outranks the reference (DESIGN-RULES.md).
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: s.warning,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
