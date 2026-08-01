import 'package:flutter/material.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import 'support/harness.dart';

/// Every component, with the variants that must be pictured.
///
/// This is the list `golden_coverage_test.dart` checks against the actual
/// exported widgets, so a component added without goldens fails the suite
/// rather than quietly shipping unpictured.
///
/// Copy is supplied per-cell and in real Arabic. A golden showing Latin text
/// under `ar` proves the layout mirrors and nothing about how the Arabic
/// actually sets — which is the half that goes wrong.
final Map<String, Widget Function(Cell)> componentGoldens = <String, Widget Function(Cell)>{
  'Button/primary': (cell) => SahraButton(
        label: _label(cell, en: 'Book a table', ar: 'احجز طاولة'),
        onPressed: () {},
      ),
  'Button/secondary': (cell) => SahraButton(
        variant: SahraButtonVariant.secondary,
        label: _label(cell, en: 'See the menu', ar: 'شوف المنيو'),
        onPressed: () {},
      ),
  'Button/ghost': (cell) => SahraButton(
        variant: SahraButtonVariant.ghost,
        label: _label(cell, en: 'Not now', ar: 'مش دلوقتي'),
        onPressed: () {},
      ),
  'Button/gold': (cell) => SahraButton(
        variant: SahraButtonVariant.gold,
        label: _label(cell, en: 'Celebrate', ar: 'احتفل'),
        onPressed: () {},
      ),
  'Button/disabled': (cell) => SahraButton(
        label: _label(cell, en: 'Fully booked', ar: 'محجوز بالكامل'),
        onPressed: null,
      ),
  'Button/pill-with-icon': (cell) => SahraButton(
        pill: true,
        icon: const Icon(Icons.add),
        label: _label(cell, en: 'Add a guest', ar: 'ضيف ضيف'),
        onPressed: () {},
      ),
  'Button/sizes': (cell) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SahraButton(
            size: SahraButtonSize.sm,
            label: _label(cell, en: 'Small', ar: 'صغير'),
            onPressed: () {},
          ),
          SizedBox(height: SahraSpace.s3),
          SahraButton(
            size: SahraButtonSize.md,
            label: _label(cell, en: 'Medium', ar: 'متوسط'),
            onPressed: () {},
          ),
          SizedBox(height: SahraSpace.s3),
          SahraButton(
            size: SahraButtonSize.lg,
            label: _label(cell, en: 'Large', ar: 'كبير'),
            onPressed: () {},
          ),
        ],
      ),
};

/// Widgets that must appear in [componentGoldens], by the name they are
/// registered under. Kept beside the registry so adding a component is one
/// edit in one file.
const Set<String> exportedComponents = <String>{'Button'};

/// Entries with no tap action BY DESIGN — a disabled control, or a purely
/// decorative component like Mashrabiya.
///
/// Listed explicitly rather than inferred, because "this one has no tap
/// action" is exactly the excuse a genuinely broken component would offer.
const Set<String> nonInteractiveGoldens = <String>{'Button/disabled'};

String _label(Cell cell, {required String en, required String ar}) =>
    cell.locale.languageCode == 'ar' ? ar : en;
