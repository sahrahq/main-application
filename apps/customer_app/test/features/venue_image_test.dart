import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/features/restaurants/domain/venue.dart';

/// PICKING A RENDITION IS A COST DECISION, so it gets its own tests.
///
/// The server stores three sizes precisely so a 64pt thumbnail does not
/// download a 1200px hero. A client that always took the largest would look
/// identical on a laptop, pass every screen test, and spend twenty times the
/// egress on every scroll — and egress is the ceiling that binds on the free
/// tier (doc 10 §3b).
///
/// None of that is visible in a widget test. It is visible here.
void main() {
  VenueImage image({Map<String, String>? urls}) => VenueImage(
        id: 'i1',
        urls: urls ??
            const <String, String>{
              '160': 'https://cdn/160.webp',
              '400': 'https://cdn/400.webp',
              '1200': 'https://cdn/1200.webp',
            },
        width: 1600,
        height: 1200,
        isCover: true,
      );

  group('smallest that fits', () {
    test('a 64pt thumbnail at 1x takes the 160', () {
      expect(image().urlFor(logicalWidth: 64), 'https://cdn/160.webp');
    });

    test('THE SAME THUMBNAIL AT 3x TAKES THE 400', () {
      // 64 x 3 = 192, which the 160 cannot cover. This is the case a
      // pixel-ratio-blind implementation gets wrong in the other direction:
      // a crisp-looking laptop and a blurry flagship phone.
      expect(image().urlFor(logicalWidth: 64, pixelRatio: 3), 'https://cdn/400.webp');
    });

    test('a 390pt phone hero at 2x takes the 1200', () {
      expect(image().urlFor(logicalWidth: 390, pixelRatio: 2), 'https://cdn/1200.webp');
    });

    test('an exact match takes that size, not the one above', () {
      // 400 >= 400. An off-by-one here doubles the bytes for every card in a
      // list, which is the kind of cost nobody notices until the bill.
      expect(image().urlFor(logicalWidth: 400), 'https://cdn/400.webp');
    });
  });

  group('when nothing is big enough', () {
    test('it falls UP to the largest rather than returning null', () {
      // A tablet hero wider than 1200. Serving the largest stored size is
      // right: slightly soft beats an empty box where a photo should be.
      expect(image().urlFor(logicalWidth: 2000), 'https://cdn/1200.webp');
    });
  });

  group('degenerate inputs produce null, never a crash', () {
    test('no urls at all', () {
      expect(image(urls: const <String, String>{}).urlFor(logicalWidth: 100), isNull);
    });

    test('keys that are not widths', () {
      // A server that started keying by name — "thumb", "hero" — would break
      // the contract. Returning null puts the designed placeholder on screen
      // rather than throwing inside a build method.
      expect(
        image(urls: const <String, String>{'thumb': 'https://cdn/t.webp'})
            .urlFor(logicalWidth: 100),
        isNull,
      );
    });
  });

  group('the aspect ratio the layout reserves', () {
    test('comes from the ORIGINAL dimensions', () {
      expect(image().aspectRatio, closeTo(1600 / 1200, 0.001));
    });

    test('a zero height does not divide by zero', () {
      // A malformed row must not take a screen down. The DB has a CHECK
      // against it; this is the client not depending on that being true.
      const broken = VenueImage(
        id: 'i2',
        urls: <String, String>{},
        width: 100,
        height: 0,
        isCover: false,
      );
      expect(broken.aspectRatio, 1);
    });
  });
}
