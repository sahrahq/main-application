import 'package:sahra_test_harness/sahra_test_harness.dart';

import '../screen_registry.dart';
import '../support/screen_harness.dart';

/// Every screen STATE, at every real device size.
///
/// The screens are where this matters most: a component is given whatever
/// width its parent offers, but a screen owns the width, and a screen is the
/// thing that has a sticky footer, a hero, and a list all competing for the
/// same 568 vertical points.
///
/// `ar` only — Arabic is the wider, harder direction, and this property does
/// not vary by theme. `isPage: true` (the default) because these ARE pages:
/// a horizontally scrolling page is a layout that did not fit and gave up.
void main() {
  screenCases.forEach((name, c) {
    viewportMatrix(
      name,
      (vp) => screenHarness(
        Cell.arLight,
        c.build(Cell.arLight),
        overrides: c.overrides(Cell.arLight),
        textScale: vp.textScale,
      ),
    );
  });
}
