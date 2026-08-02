import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../screen_registry.dart';
import '../support/screen_harness.dart';

/// THE 560 CAP IS ENFORCED, NOT MERELY PRESENT.
///
/// `SahraPageWidth` had a unit test proving the widget constrains what it is
/// given, and every screen did in fact wrap its body in one. What did not
/// exist was anything that would notice a screen that FORGOT. The widest
/// viewport in `sahraViewports` is 1024×768, the goldens are taken at 390, and
/// a screen sprawling across a desktop browser would have been green
/// everywhere — which is how the product owner found it by opening Chrome
/// rather than by a test failing.
///
/// So this renders every registered screen state at 1440×900 and OBSERVES
/// where the pixels landed. It does not ask whether the widget is in the tree;
/// a wrapper placed below a `ListView`, or around only half a body, is in the
/// tree and does nothing.
///
/// WHAT IS DELIBERATELY EXCLUDED. `Scaffold`, `AppBar`, the bottom navigation
/// and any full-bleed background legitimately span the window — a page
/// background that stopped at 560 with bare canvas either side would be the
/// defect this is meant to prevent, inverted. The check therefore looks at
/// TEXT, which is content by definition and has no reason to sit outside the
/// measure.
void main() {
  const Size desktop = Size(1440, 900);
  final double column = SahraLayout.maxContentWidth;

  screenCases.forEach((name, c) {
    testWidgets('page width: $name is capped at 1440', (tester) async {
      tester.view.physicalSize = desktop;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        screenHarness(Cell.enLight, c.build(Cell.enLight), overrides: c.overrides(Cell.enLight)),
      );
      await stabilise(tester);

      // The permitted band: the centred column, plus a point of tolerance for
      // sub-pixel text layout.
      final double start = (desktop.width - column) / 2 - 1;
      final double end = (desktop.width + column) / 2 + 1;

      final escaped = <String>[];
      for (final element in find.byType(RichText).evaluate()) {
        final render = element.renderObject;
        if (render is! RenderBox || !render.hasSize) continue;
        if (render.size.isEmpty) continue;
        final offset = render.localToGlobal(Offset.zero);
        final right = offset.dx + render.size.width;
        if (offset.dx < start || right > end) {
          final text = (element.widget as RichText).text.toPlainText();
          escaped.add(
            '"${text.length > 40 ? '${text.substring(0, 40)}…' : text}" '
            'at ${offset.dx.toStringAsFixed(1)}–${right.toStringAsFixed(1)}',
          );
        }
      }

      expect(
        escaped,
        isEmpty,
        reason: 'On a 1440 window, content must stay inside the centred '
            '${column.toInt()}pt column (x ${start.toStringAsFixed(0)}–'
            '${end.toStringAsFixed(0)}). These did not:\n  ${escaped.join('\n  ')}\n'
            'Wrap the screen body in SahraPageWidth.',
      );
    });
  });
}
