import 'package:flutter/material.dart';

import '../theme/sahra_scales.dart';
import '../theme/sahra_semantics.dart';

enum SahraInputVariant { box, line }

/// `docs/design/components/core/Input.d.ts` —
/// `{label, help, error, variant: box|line, placeholder, type}`.
///
/// Copy is a prop — label, hint, help and error all arrive already localised.
///
/// ERRORS ARE NOT COLOUR ALONE. A red border tells a colour-blind user
/// nothing, so an error always renders its message as text AND is announced
/// through `Semantics(...)`. WCAG 1.4.1: colour is never the only channel.
class SahraInput extends StatefulWidget {
  const SahraInput({
    this.label,
    this.hint,
    this.help,
    this.error,
    this.variant = SahraInputVariant.box,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    super.key,
  });

  final String? label;
  final String? hint;
  final String? help;

  /// Non-null puts the field in its error state — border, message and the
  /// semantic announcement together.
  final String? error;

  final SahraInputVariant variant;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  /// 1 for a single-line field; more for a paragraph.
  ///
  /// Added for the review composer, which is the first multi-line field in the
  /// product. Kept as a plain `int` rather than a variant because the height is
  /// the only thing that differs — a "textarea" variant would duplicate the
  /// whole border, focus and error treatment to change one property.
  final int maxLines;

  /// A hard ceiling on characters, enforced as the diner types.
  ///
  /// The COUNTER IS OFF (`counterText: ''`). Flutter draws one by default and
  /// it is a running "12/2000" under a field whose limit nobody is near —
  /// pressure on a review nobody asked to write at length. The limit exists to
  /// match a CHECK constraint, not to set an expectation.
  final int? maxLength;

  @override
  State<SahraInput> createState() => _SahraInputState();
}

class _SahraInputState extends State<SahraInput> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);
  bool _focused = false;

  void _onFocusChange() => setState(() => _focused = _focus.hasFocus);

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.sahra;
    final theme = Theme.of(context);
    final isLine = widget.variant == SahraInputVariant.line;
    final hasError = widget.error != null;

    final border = hasError
        ? s.error
        : _focused
            ? s.accent
            : s.line;

    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      onChanged: widget.onChanged,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      style: theme.textTheme.bodyMedium?.copyWith(color: s.textBody),
      decoration: InputDecoration(
        isDense: true,
        // A text field is a tap target too. At the reference's padding it came
        // out 45dp — under Android's 48 — which androidTapTargetGuideline
        // caught. Easy to miss by eye because the field LOOKS big enough.
        constraints: const BoxConstraints(minHeight: SahraRules.minTouchTarget),
        counterText: '',
        hintText: widget.hint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: s.textFaint),
        filled: !isLine,
        fillColor: isLine ? null : s.surfaceCard,
        contentPadding: SahraSpace.symmetric(
          horizontal: isLine ? 0 : SahraSpace.s4,
          vertical: SahraSpace.s3,
        ),
        border: _border(isLine, border),
        enabledBorder: _border(isLine, border),
        focusedBorder: _border(isLine, border),
        errorBorder: _border(isLine, s.error),
        focusedErrorBorder: _border(isLine, s.error),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            // The `line` variant labels in overline style, per the reference.
            isLine ? widget.label!.toUpperCase() : widget.label!,
            style: isLine
                ? theme.textTheme.labelSmall?.copyWith(color: s.textFaint)
                : theme.textTheme.bodySmall?.copyWith(
                    color: s.textBody,
                    fontWeight: FontWeight.w600,
                  ),
          ),
          SizedBox(height: SahraSpace.s2),
        ],
        Semantics(
          textField: true,
          label: widget.label,
          // Announced, not merely painted red.
          hint: widget.error ?? widget.help,
          child: field,
        ),
        if (hasError || widget.help != null) ...<Widget>[
          SizedBox(height: SahraSpace.s2),
          Text(
            widget.error ?? widget.help!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: hasError ? s.error : s.textFaint,
            ),
          ),
        ],
      ],
    );
  }

  InputBorder _border(bool isLine, Color colour) => isLine
      ? UnderlineInputBorder(borderSide: BorderSide(color: colour, width: 1.5))
      : OutlineInputBorder(
          borderRadius: SahraRadius.allOf(SahraRadius.md),
          borderSide: BorderSide(color: colour, width: 1.5),
        );
}
