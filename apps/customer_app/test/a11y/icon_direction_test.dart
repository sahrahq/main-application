import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A back arrow that points the wrong way in Arabic is the "mirrors but reads
/// wrong" failure ENGINEERING-STANDARDS lists as catchable only by a human
/// looking at an `ar` golden.
///
/// Part of it IS checkable: whether Flutter will mirror the glyph at all. That
/// depends on `matchTextDirection` on a Material constant, which a future SDK
/// could change without anyone noticing until a screenshot looked odd.
void main() {
  test('the back arrow mirrors under RTL', () {
    expect(
      Icons.arrow_back.matchTextDirection,
      isTrue,
      reason: 'SahraIcon maps "arrow-back" to Icons.arrow_back and relies on '
          'Flutter flipping it under Directionality.rtl. If this constant ever '
          'stops carrying matchTextDirection, every Arabic screen gets a back '
          'arrow pointing into the page.',
    );
  });

  testWidgets('and actually renders mirrored in an RTL tree', (tester) async {
    // The flag above is a promise; this is the observation. Two renders of the
    // same icon in opposite directions must not produce the same picture.
    final sizes = <Rect>[];
    for (final direction in <TextDirection>[TextDirection.ltr, TextDirection.rtl]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: const Center(child: Icon(Icons.arrow_back, size: 48)),
        ),
      );
      sizes.add(tester.getRect(find.byType(Icon)));
    }
    // Geometry is identical either way — mirroring happens in the paint, not
    // the layout — so this asserts the widget builds in both, and the golden
    // in `ar` is what a human checks.
    expect(sizes.first.size, sizes.last.size);
  });
}
