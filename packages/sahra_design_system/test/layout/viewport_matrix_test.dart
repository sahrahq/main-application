import 'package:sahra_test_harness/sahra_test_harness.dart';

import '../component_registry.dart';
import '../support/harness.dart';

/// Every component, at every real device size.
///
/// Goldens are taken at ONE size and prove nothing about any other. This is
/// the other half: a component that fits a 390pt phone and overflows a 320pt
/// one is broken for the smallest phone SAHRA supports, and nothing else in
/// the suite notices.
///
/// Run in the `ar` cell only, deliberately. Arabic is the harder direction —
/// IBM Plex Sans Arabic sets wider than Poppins at the same nominal size, and
/// the plural forms are longer — so a layout that survives `ar` survives `en`.
/// All four cells would be 96 tests per component for a property that does not
/// vary by theme.
void main() {
  componentGoldens.forEach((name, build) {
    viewportMatrix(
      name,
      (vp) => harness(Cell.arLight, build(Cell.arLight), textScale: vp.textScale),
      // A component is not a page. DateStrip and the chip rows ARE horizontal
      // scrollers; rendered alone in a harness they are the outermost
      // scrollable there is, and checking them against the page rule failed
      // four components for being what they are.
      isPage: false,
    );
  });
}
