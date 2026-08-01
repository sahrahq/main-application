/// ENGINEERING-STANDARDS §4, applied to every registered component in all four
/// cells: 44pt/48dp tap targets, a semantic label on everything tappable,
/// text contrast, and no overflow at 200% text.
import '../component_registry.dart';
import '../support/harness.dart';

void main() {
  componentGoldens.forEach((name, build) {
    a11yMatrix(name, build, interactive: !nonInteractiveGoldens.contains(name));
  });
  componentGoldens.forEach(textScaleMatrix);
}
