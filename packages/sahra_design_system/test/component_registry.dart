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
  // Cancelling a booking, deleting an account — things that cannot be undone.
  // Its foreground flips by theme; `palette_contrast_test` proves both clear
  // AA and that white genuinely fails on the night fill.
  'Button/destructive': (cell) => SahraButton(
        variant: SahraButtonVariant.destructive,
        label: _label(cell, en: 'Cancel booking', ar: 'إلغاء الحجز'),
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
  'RatingStars/large': (cell) => const SahraRatingStars(rating: 4.6, reviews: 812, size: 18),
  // ══ WAVE 3 — the composites ══════════════════════════════════════════════

  'BookingWidget/form': (cell) => SahraBookingWidget(
        venue: _label(cell, en: 'Layali Lounge', ar: 'ليالي لاونج'),
        times: const <String>['19:30', '21:00', '22:30'],
        onBook: (_, __) {},
        copy: _bookingCopy(cell),
      ),
  'BookingWidget/confirmed': (cell) => SahraBookingWidget(
        venue: _label(cell, en: 'Layali Lounge', ar: 'ليالي لاونج'),
        times: const <String>['19:30', '21:00', '22:30'],
        confirmed: true,
        onChangePlans: _noop,
        copy: _bookingCopy(cell),
      ),

  'DiningTrail/visits': (cell) => SizedBox(
        width: 320,
        child: SahraDiningTrail(
          visits: <SahraVisit>[
            SahraVisit(
              name: _label(cell, en: 'Sequoia', ar: 'سيكويا'),
              date: _label(cell, en: 'Last Thursday', ar: 'الخميس اللي فات'),
              note: _label(cell, en: 'Nile terrace', ar: 'تراس النيل'),
            ),
            SahraVisit(
              name: _label(cell, en: 'Zooba', ar: 'زوبا'),
              date: _label(cell, en: '12 July', ar: '12 يوليو'),
            ),
            SahraVisit(
              name: _label(cell, en: 'Abou Tarek', ar: 'أبو طارق'),
              date: _label(cell, en: '3 June', ar: '3 يونيو'),
            ),
          ],
        ),
      ),

  'RestaurantCard/full': (cell) => SahraRestaurantCard(
        name: _label(cell, en: 'Zooba', ar: 'زوبا'),
        rating: 4.8,
        reviews: 312,
        cuisine: _label(cell, en: 'Egyptian', ar: 'مصري'),
        neighbourhood: _label(cell, en: 'Zamalek', ar: 'الزمالك'),
        price: r'$$',
        featured: true,
        featuredLabel: _label(cell, en: 'Featured', ar: 'مميز'),
        availability: _label(cell, en: 'Tonight 19:30', ar: 'الليلة 19:30'),
        saveLabel: _label(cell, en: 'Save Zooba', ar: 'احفظ زوبا'),
        onSave: _noop,
        onTap: _noop,
        semanticLabel: _label(
          cell,
          en: 'Zooba, rated 4.8 from 312 reviews, Egyptian, Zamalek',
          ar: 'زوبا، تقييم 4.8 من 312 مراجعة، مصري، الزمالك',
        ),
      ),
  'RestaurantCard/plain': (cell) => SahraRestaurantCard(
        name: _label(cell, en: 'Sequoia Nile', ar: 'سيكويا النيل'),
        rating: 4.6,
        reviews: 812,
        cuisine: _label(cell, en: 'Mediterranean', ar: 'متوسطي'),
      ),

  // ══ WAVE 2 ═══════════════════════════════════════════════════════════════

  'Skeleton/lines': (cell) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SahraSkeleton(width: 220, height: 16),
          SizedBox(height: 8),
          SahraSkeleton(width: 160, height: 12),
        ],
      ),
  'Skeleton/card': (cell) => const SahraSkeletonCard(),

  'EmptyState/with-action': (cell) => SizedBox(
        width: 380,
        child: SahraEmptyState(
          icon: 'lantern',
          title: _label(cell, en: 'Nothing saved yet', ar: 'لسه مافيش حاجة محفوظة'),
          message: _label(
            cell,
            en: 'Tap the heart on a restaurant and it will wait for you here.',
            ar: 'دوس على القلب في أي مطعم وهتلاقيه مستنيك هنا.',
          ),
          actionLabel: _label(cell, en: 'Browse Discover', ar: 'اكتشف'),
          onAction: _noop,
        ),
      ),
  'EmptyState/bare': (cell) => SizedBox(
        width: 380,
        child: SahraEmptyState(
          icon: 'search',
          title: _label(cell, en: 'No tables at that time', ar: 'مافيش طاولات في الميعاد ده'),
        ),
      ),

  'SearchBar/with-location': (cell) => SizedBox(
        width: 360,
        child: SahraSearchBar(
          hint: _label(cell, en: 'Koshary, Zamalek…', ar: 'كشري، الزمالك…'),
          location: _label(cell, en: 'Cairo', ar: 'القاهرة'),
        ),
      ),

  'TabBar/default': (cell) => SizedBox(
        width: 380,
        child: SahraTabBar(
          activeId: 'discover',
          onChanged: (_) {},
          items: <SahraTab>[
            SahraTab(
              id: 'discover',
              label: _label(cell, en: 'Discover', ar: 'اكتشف'),
              icon: 'compass',
            ),
            SahraTab(
              id: 'search',
              label: _label(cell, en: 'Search', ar: 'بحث'),
              icon: 'search',
            ),
            SahraTab(
              id: 'account',
              label: _label(cell, en: 'Account', ar: 'حسابي'),
              icon: 'user',
            ),
          ],
        ),
      ),

  'AvatarStack/overflow': (cell) => SahraAvatarStack(
        people: <SahraPerson>[
          SahraPerson(name: _label(cell, en: 'Nour Hassan', ar: 'نور حسن')),
          SahraPerson(name: _label(cell, en: 'Omar Fathy', ar: 'عمر فتحي')),
          SahraPerson(name: _label(cell, en: 'Salma Adel', ar: 'سلمى عادل')),
          SahraPerson(name: _label(cell, en: 'Yara Nabil', ar: 'يارا نبيل')),
          SahraPerson(name: _label(cell, en: 'Kareem Saad', ar: 'كريم سعد')),
        ],
        label: _label(cell, en: 'are going', ar: 'رايحين'),
      ),

  // ══ DISCOVERED while building the customer booking path ═════════════════
  //
  // Six pieces the three screens repeat that are not among the sixteen. Each
  // gets the same harness as a planned component — the alternative is a
  // "just this once" inline widget, and there is never only one of those.

  'Photo/placeholder': (cell) => const SizedBox(
        width: 320,
        child: SahraPhoto(height: 180, radius: 16),
      ),
  'Photo/with-overlay-text': (cell) => SizedBox(
        width: 320,
        child: SahraPhoto(
          height: 180,
          radius: 16,
          gradientOverlay: true,
          label: _label(cell, en: 'TONIGHT', ar: 'الليلة'),
        ),
      ),

  'PhotoIconButton/row': (cell) => SizedBox(
        width: 260,
        // Over a photo, because that is the only place it appears and a
        // golden of it on a plain surface would prove nothing about the one
        // contrast case no guideline can check.
        child: SahraPhoto(
          height: 120,
          radius: 16,
          child: Padding(
            padding: SahraSpace.all(SahraSpace.s3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                SahraPhotoIconButton(
                  icon: 'arrow-back',
                  semanticLabel: _label(cell, en: 'Back', ar: 'رجوع'),
                  onPressed: _noop,
                ),
                SahraPhotoIconButton(
                  icon: 'heart',
                  active: true,
                  semanticLabel: _label(cell, en: 'Saved', ar: 'محفوظ'),
                  onPressed: _noop,
                ),
              ],
            ),
          ),
        ),
      ),

  'SectionLabel/three': (cell) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SahraSectionLabel(_label(cell, en: 'Date', ar: 'التاريخ')),
          SizedBox(height: SahraSpace.s3),
          SahraSectionLabel(_label(cell, en: 'Party size', ar: 'عدد الأفراد')),
          SizedBox(height: SahraSpace.s3),
          SahraSectionLabel(_label(cell, en: 'Time', ar: 'الوقت')),
        ],
      ),

  'PartyStepper/mid': (cell) => SahraPartyStepper(
        value: 4,
        onChanged: (_) {},
        unitLabel: _label(cell, en: 'guests', ar: 'أفراد'),
        decreaseLabel: _label(cell, en: 'One fewer guest', ar: 'فرد أقل'),
        increaseLabel: _label(cell, en: 'One more guest', ar: 'فرد زيادة'),
      ),
  'PartyStepper/at-minimum': (cell) => SahraPartyStepper(
        value: 1,
        onChanged: (_) {},
        unitLabel: _label(cell, en: 'guest', ar: 'فرد'),
        decreaseLabel: _label(cell, en: 'One fewer guest', ar: 'فرد أقل'),
        increaseLabel: _label(cell, en: 'One more guest', ar: 'فرد زيادة'),
      ),

  'DateStrip/week': (cell) => SizedBox(
        width: 380,
        child: SahraDateStrip(
          selectedId: '2026-08-05',
          onSelected: (_) {},
          days: <SahraDay>[
            SahraDay(
              id: '2026-08-05',
              label: _label(cell, en: 'Tonight', ar: 'الليلة'),
              number: '5',
              semanticLabel: _label(cell, en: 'Tonight, 5 August', ar: 'الليلة، 5 أغسطس'),
            ),
            SahraDay(
              id: '2026-08-06',
              label: _label(cell, en: 'Thu', ar: 'الخميس'),
              number: '6',
              semanticLabel: _label(cell, en: 'Thursday 6 August', ar: 'الخميس 6 أغسطس'),
            ),
            SahraDay(
              id: '2026-08-07',
              label: _label(cell, en: 'Fri', ar: 'الجمعة'),
              number: '7',
              semanticLabel: _label(cell, en: 'Friday 7 August', ar: 'الجمعة 7 أغسطس'),
            ),
            SahraDay(
              id: '2026-08-08',
              label: _label(cell, en: 'Sat', ar: 'السبت'),
              number: '8',
              semanticLabel: _label(cell, en: 'Saturday 8 August', ar: 'السبت 8 أغسطس'),
            ),
          ],
        ),
      ),

  'ResultRow/available': (cell) => SizedBox(
        width: 380,
        child: SahraResultRow(
          name: _label(cell, en: 'Layali Lounge', ar: 'ليالي لاونج'),
          rating: 4.8,
          reviews: 312,
          meta: _label(cell, en: r'Levantine · $$$', ar: r'شامي · $$$'),
          availability: _label(cell, en: 'Next: 21:00', ar: 'القادم: 21:00'),
          saveLabel: _label(cell, en: 'Save Layali Lounge', ar: 'احفظ ليالي لاونج'),
          onSave: _noop,
          onTap: _noop,
          semanticLabel: _label(
            cell,
            en: 'Layali Lounge, rated 4.8 from 312 reviews, Levantine, next table 21:00',
            ar: 'ليالي لاونج، تقييم 4.8 من 312 مراجعة، شامي، أقرب طاولة 21:00',
          ),
        ),
      ),
  'ResultRow/no-availability': (cell) => SizedBox(
        width: 380,
        child: SahraResultRow(
          name: _label(cell, en: 'El Fishawy', ar: 'الفيشاوي'),
          rating: 4.5,
          reviews: 2841,
          meta: _label(cell, en: r'Egyptian · $', ar: r'مصري · $'),
          onTap: _noop,
          semanticLabel: _label(
            cell,
            en: 'El Fishawy, rated 4.5 from 2841 reviews, Egyptian',
            ar: 'الفيشاوي، تقييم 4.5 من 2841 مراجعة، مصري',
          ),
        ),
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
const Set<String> exportedComponents = <String>{
  'Button',
  'Icon',
  'Mashrabiya',
  'Badge',
  'Chip',
  'Input',
  'Avatar',
  'RatingStars',
  'Skeleton',
  'EmptyState',
  'SearchBar',
  'TabBar',
  'AvatarStack',
  'BookingWidget',
  'DiningTrail',
  'RestaurantCard',
  // Discovered while building the customer booking path — not part of the
  // original sixteen, held to the same bar. Counted SEPARATELY: the sixteen
  // came from the design package, these came from the screens.
  'Photo',
  'PhotoIconButton',
  'SectionLabel',
  'PartyStepper',
  'DateStrip',
  'ResultRow',
};

/// The sixteen from the design package, as distinct from what building the
/// screens turned up. Kept apart so "16 of 16 done" stays a true statement.
const Set<String> designPackageComponents = <String>{
  'Button',
  'Icon',
  'Mashrabiya',
  'Badge',
  'Chip',
  'Input',
  'Avatar',
  'RatingStars',
  'Skeleton',
  'EmptyState',
  'SearchBar',
  'TabBar',
  'AvatarStack',
  'BookingWidget',
  'DiningTrail',
  'RestaurantCard',
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
  'SearchBar/with-location',
  // Wave 2 display-only.
  'Skeleton/lines', 'Skeleton/card',
  'EmptyState/bare',
  'AvatarStack/overflow',
  // Wave 3 display-only.
  'DiningTrail/visits',
  'RestaurantCard/plain',
  // Discovered components with no tap action.
  'Photo/placeholder', 'Photo/with-overlay-text',
  'SectionLabel/three',
  'ResultRow/no-availability',
};

/// A real callback: a null one disables the button, and a disabled control
/// exposes no tap action — which the a11y guard correctly refuses.
void _noop() {}

SahraBookingCopy _bookingCopy(Cell cell) => SahraBookingCopy(
      overline: _label(cell, en: 'Tonight', ar: 'الليلة'),
      partySize: _label(cell, en: 'Party size', ar: 'عدد الأفراد'),
      book: _label(cell, en: 'Book a table', ar: 'احجز طاولة'),
      confirmedTitle: _label(cell, en: "You're in.", ar: 'تمام، اتحجزت.'),
      confirmedBody: _label(
        cell,
        en: 'Your table for 2 is set for 21:00. We told them you are coming.',
        ar: 'طاولتك لاتنين الساعة 21:00. قلنالهم إنك جاي.',
      ),
      changePlans: _label(cell, en: 'Change plans', ar: 'غيّر الخطة'),
      decreaseParty: _label(cell, en: 'Fewer guests', ar: 'ضيوف أقل'),
      increaseParty: _label(cell, en: 'More guests', ar: 'ضيوف أكتر'),
    );

String _label(Cell cell, {required String en, required String ar}) =>
    cell.locale.languageCode == 'ar' ? ar : en;
