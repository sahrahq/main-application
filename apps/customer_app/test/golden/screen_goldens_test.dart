import '../screen_registry.dart';
import '../support/screen_harness.dart';

/// Four goldens per screen STATE (ENGINEERING-STANDARDS §3).
void main() {
  screenCases.forEach((name, c) {
    screenGoldens(name, c.build, overrides: c.overrides);
  });
}
