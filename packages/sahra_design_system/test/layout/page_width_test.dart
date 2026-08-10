import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../support/harness.dart';

/// 3b — content has a maximum readable width and centres beyond it.
void main() {
  Future<Rect> boxAt(WidgetTester tester, Size viewport) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        Cell.arLight,
        // `width: double.infinity` — the probe must WANT all the space, or it
        // measures its own preference rather than the cap. A bare SizedBox
        // with only a height reports 0 and proves nothing.
        const SahraPageWidth(
          child: SizedBox(key: Key('content'), width: double.infinity, height: 100),
        ),
      ),
    );
    await stabilise(tester);
    return tester.getRect(find.byKey(const Key('content')));
  }

  testWidgets('a phone gets the full width — nothing is taken away', (tester) async {
    // The rule must be invisible on the device the app was designed for.
    final r = await boxAt(tester, const Size(390, 844));
    expect(r.width, lessThanOrEqualTo(390));
    expect(r.width, greaterThan(300));
  });

  testWidgets('the 375 design canvas is untouched', (tester) async {
    final r = await boxAt(tester, SahraLayout.designCanvas);
    expect(r.width, lessThanOrEqualTo(SahraLayout.designCanvas.width));
  });

  testWidgets('a tablet is CAPPED, not stretched', (tester) async {
    final r = await boxAt(tester, const Size(1024, 768));
    expect(r.width, SahraLayout.maxContentWidth);
  });

  testWidgets('and a desktop window is capped at the same width', (tester) async {
    // The actual complaint: "the layout is stretched and wrong on a desktop
    // window". One number, one behaviour, whatever the excess.
    final r = await boxAt(tester, const Size(1920, 1080));
    expect(r.width, SahraLayout.maxContentWidth);
  });

  testWidgets('it is CENTRED horizontally, not left-aligned', (tester) async {
    final r = await boxAt(tester, const Size(1024, 768));
    final leftGap = r.left;
    final rightGap = 1024 - r.right;
    expect((leftGap - rightGap).abs(), lessThan(1));
  });

  testWidgets('content starts at the TOP, not floated into the middle', (tester) async {
    // `Alignment.center` would push a short screen's content into the middle
    // of a tall window, which reads as broken rather than as centred.
    final r = await boxAt(tester, const Size(1024, 1400));
    expect(r.top, lessThan(1400 / 3));
  });

  test('the number is 560, and 768 is above it on purpose', () {
    // Tablet portrait must get the centred PHONE layout rather than a
    // stretched one — management_app is the tablet-first surface and its
    // screens will be drawn for tablets, not inherited from these.
    expect(SahraLayout.maxContentWidth, 560);
    expect(SahraLayout.maxContentWidth, lessThan(768));
    // ~1.5x the canvas the screens were actually drawn on.
    expect(SahraLayout.maxContentWidth / SahraLayout.designCanvas.width,
        closeTo(1.5, 0.05));
  });
}
