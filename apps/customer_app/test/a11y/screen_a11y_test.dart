import '../screen_registry.dart';
import '../support/screen_harness.dart';

/// §4, on whole screens: 44/48pt targets, semantic labels, contrast, and 200%
/// text — in all four cells.
void main() {
  screenCases.forEach((name, c) {
    screenA11y(name, c.build, overrides: c.overrides, interactive: c.interactive, after: c.after);
    screenTextScale(name, c.build, overrides: c.overrides, after: c.after);
  });
}
