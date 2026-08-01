/// Four goldens per component variant: ar/en × light/dark.
///
/// This is how visual quality is reviewed without reading code, so it is not
/// sampled. Run `flutter test --update-goldens` to regenerate, and LOOK at the
/// result — the machine catches change, never wrongness.
import '../component_registry.dart';
import '../support/harness.dart';

void main() {
  componentGoldens.forEach(goldenMatrix);
}
