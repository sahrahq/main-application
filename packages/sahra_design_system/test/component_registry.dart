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
  // ── Icon ────────────────────────────────────────────────────────────────
  'Icon/drawn-set': (cell) => Wrap(
        spacing: SahraSpace.s4,
        runSpacing: SahraSpace.s4,
        children: <Widget>[
          for (final name in SahraIcon.drawnIcons) SahraIcon(name, size: 28),
        ],
      ),
  'Icon/fallback-set': (cell) => Wrap(
        spacing: SahraSpace.s4,
        runSpacing: SahraSpace.s4,
        children: <Widget>[
          for (final name in SahraIcon.fallbackIcons.take(8)) SahraIcon(name, size: 28),
        ],
      ),

  // ── Mashrabiya ──────────────────────────────────────────────────────────
  'Mashrabiya/tile': (cell) => const SizedBox(
        width: 220,
        height: 160,
        child: SahraMashrabiya(),
      ),
  'Mashrabiya/fade': (cell) => const SizedBox(
        width: 220,
        height: 160,
        child: SahraMashrabiya(fade: true),
      ),

  // ── Badge ───────────────────────────────────────────────────────────────
  'Badge/all-variants': (cell) => Wrap(
        spacing: SahraSpace.s2,
        runSpacing: SahraSpace.s2,
        children: <Widget>[
          SahraBadge(
            label: _label(cell, en: 'Featured', ar: 'مميز'),
            variant: SahraBadgeVariant.featured,
          ),
          SahraBadge(
            label: _label(cell, en: 'Gold', ar: 'ذهبي'),
            variant: SahraBadgeVariant.gold,
          ),
          SahraBadge(
            label: _label(cell, en: 'Confirmed', ar: 'مؤكد'),
            variant: SahraBadgeVariant.success,
          ),
          SahraBadge(
            label: _label(cell, en: 'Few left', ar: 'أماكن قليلة'),
            variant: SahraBadgeVariant.warning,
          ),
          SahraBadge(
            label: _label(cell, en: 'Full', ar: 'ممتلئ'),
            variant: SahraBadgeVariant.error,
          ),
          SahraBadge(
            label: _label(cell, en: 'Levantine', ar: 'شامي'),
          ),
        ],
      ),

  // ── Chip ────────────────────────────────────────────────────────────────
  'Chip/row': (cell) => Wrap(
        spacing: SahraSpace.s2,
        children: <Widget>[
          SahraChip(
            label: _label(cell, en: 'Tonight', ar: 'الليلة'),
            active: true,
            onPressed: () {},
          ),
          SahraChip(
            label: _label(cell, en: 'Outdoor', ar: 'في الخارج'),
            onPressed: () {},
          ),
          SahraChip(
            label: _label(cell, en: 'Shisha', ar: 'شيشة'),
            icon: const SahraIcon('shisha', size: 14),
            onPressed: () {},
          ),
        ],
      ),

  // ── Input ───────────────────────────────────────────────────────────────
  'Input/box': (cell) => SizedBox(
        width: 320,
        child: SahraInput(
          label: _label(cell, en: 'Phone number', ar: 'رقم التليفون'),
          hint: _label(cell, en: '01x xxx xxxx', ar: '01x xxx xxxx'),
          help: _label(cell, en: 'We send a code by WhatsApp', ar: 'هنبعت كود على واتساب'),
        ),
      ),
  'Input/error': (cell) => SizedBox(
        width: 320,
        child: SahraInput(
          label: _label(cell, en: 'Phone number', ar: 'رقم التليفون'),
          error: _label(cell, en: 'That number is not valid', ar: 'الرقم ده مش صحيح'),
        ),
      ),
  'Input/line': (cell) => SizedBox(
        width: 320,
        child: SahraInput(
          variant: SahraInputVariant.line,
          label: _label(cell, en: 'Search', ar: 'بحث'),
          hint: _label(cell, en: 'Koshary, Zamalek…', ar: 'كشري، الزمالك…'),
        ),
      ),

  // ── Avatar ──────────────────────────────────────────────────────────────
  'Avatar/initials': (cell) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SahraAvatar(name: _label(cell, en: 'Nour Hassan', ar: 'نور حسن')),
          SizedBox(width: SahraSpace.s3),
          SahraAvatar(name: _label(cell, en: 'Omar Fathy', ar: 'عمر فتحي'), size: 56),
        ],
      ),

  // ── RatingStars ─────────────────────────────────────────────────────────
  'RatingStars/with-reviews': (cell) => const SahraRatingStars(rating: 4.8, reviews: 312),
  'RatingStars/large': (cell) =>
      const SahraRatingStars(rating: 4.6, reviews: 812, size: 18),
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
const Set<String> exportedComponents = <String>{
  'Button', 'Icon', 'Mashrabiya', 'Badge', 'Chip', 'Input', 'Avatar', 'RatingStars',
};

/// Entries with no tap action BY DESIGN — a disabled control, or a purely
/// decorative component like Mashrabiya.
///
/// Listed explicitly rather than inferred, because "this one has no tap
/// action" is exactly the excuse a genuinely broken component would offer.
const Set<String> nonInteractiveGoldens = <String>{
  'Button/disabled',
  // Pure display or decoration — no tap action to expose.
  'Icon/drawn-set', 'Icon/fallback-set',
  'Mashrabiya/tile', 'Mashrabiya/fade',
  'Badge/all-variants',
  'Avatar/initials',
  'RatingStars/with-reviews', 'RatingStars/large',
  // A text field's semantics are a textField, not a tappable button.
  'Input/box', 'Input/error', 'Input/line',
};

String _label(Cell cell, {required String en, required String ar}) =>
    cell.locale.languageCode == 'ar' ? ar : en;
