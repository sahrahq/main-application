import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'fixture_image.dart';

/// THE FIXTURE IMAGE MUST ACTUALLY DECODE.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS TEST EXISTS
/// ─────────────────────────────────────────────────────────────────────────
///
/// The first version of `kFixtureImageBytes` was hand-written base64. It had a
/// correct PNG signature — enough to satisfy a "is this a PNG" check — and a
/// corrupt IDAT. Flutter's codec refused it, `SahraPhoto` fell back to its
/// placeholder, and the goldens named `Venue/with-photos` were regenerated
/// picturing a venue with NO photos.
///
/// The golden then passed, because a golden only asks "does this still look
/// like last time". Only the accessibility matrix noticed, and only because
/// the failed decode raised.
///
/// This is the same shape as the stale fixture date, one layer down: an
/// artefact produced FOR a picture that cannot produce the picture. So it is
/// checked the only way that counts — by decoding it and reading back its
/// dimensions.
void main() {
  test('it is a real image, not merely PNG-shaped', () async {
    final codec = await ui.instantiateImageCodec(kFixtureImageBytes);
    final frame = await codec.getNextFrame();

    expect(frame.image.width, greaterThan(0));
    expect(frame.image.height, greaterThan(0));
  });

  test('and it is small enough to keep inline', () {
    // A fixture that grows into a real photograph belongs in a file, not in a
    // Dart string literal that everybody scrolls past.
    expect(kFixtureImageBytes.length, lessThan(2048));
  });
}
