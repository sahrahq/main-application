import 'package:flutter_test/flutter_test.dart';

import 'screen_registry.dart';

/// THE FIXTURES HAVE TO KEEP MEANING WHAT THEY SAY.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS FILE EXISTS
/// ─────────────────────────────────────────────────────────────────────────
///
/// `Reservation/confirmed` was pinned to 2026-08-05. When modify shipped on
/// 2026-08-08 the screen started hiding its move button for any booking whose
/// time had passed — correctly — and that golden silently stopped picturing a
/// live booking. **Nothing failed.** 103 goldens, 194 accessibility checks and
/// 168 viewport checks all stayed green while the picture changed meaning,
/// because every one of them asks "does this still look like last time" and
/// the answer was yes: it had looked like a past booking before too.
///
/// This is the same class of hole as the unreachable screen, one level down. A
/// fixture that goes stale does not break a test; it quietly narrows what the
/// test covers, and the coverage number stays exactly where it was.
///
/// So the fixture date is fixed — a golden cannot depend on the clock — and
/// this asserts the fixed value is still ahead of it. A year of notice, and a
/// failure that names the file to edit.
void main() {
  test('the fixture date is still in the future', () {
    final fixture = DateTime.parse('${kFixtureDate}T18:00:00.000Z');

    expect(
      fixture.isAfter(DateTime.now().toUtc()),
      isTrue,
      reason:
          'kFixtureDate ($kFixtureDate) has passed. Every screen state built on '
          'it now renders as a booking in the PAST: no modify button, and the '
          'goldens named "confirmed" no longer show a confirmed booking that '
          'can be changed. Move it forward in test/screen_registry.dart and '
          'regenerate the goldens.',
    );
  });

  test('and far enough ahead to be worth trusting', () {
    // A month of warning is not warning. This fails while there is still time
    // to move it deliberately rather than in the middle of something else.
    final fixture = DateTime.parse('${kFixtureDate}T18:00:00.000Z');
    final soon = DateTime.now().toUtc().add(const Duration(days: 90));

    expect(
      fixture.isAfter(soon),
      isTrue,
      reason: 'kFixtureDate ($kFixtureDate) expires within 90 days. Move it '
          'forward now, while this is a one-line change rather than a '
          'surprise in someone else\'s batch.',
    );
  });
}
