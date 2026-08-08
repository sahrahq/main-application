import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// A real, decodable image for goldens — WITHOUT a network.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY NOT `CachedNetworkImageProvider` IN A GOLDEN
/// ─────────────────────────────────────────────────────────────────────────
///
/// `flutter_test` answers every HTTP request with a 400 and never opens a
/// socket, so a network provider in a golden draws nothing — and "nothing"
/// looks exactly like the designed empty state. A golden named "with a photo"
/// would picture a venue with no photo, and pass forever.
///
/// That is the fixture-date failure again in a new place: the picture stops
/// meaning what its name says, and no assertion notices. So the goldens use a
/// real decodable image and the NETWORK layer is tested separately, by
/// `venue_image_test.dart` (which rendition is chosen) and by the API's own
/// suite (that the bytes exist and are the right size).
///
/// Eight pixels of solid terracotta. Small enough to inline, real enough to
/// decode, and obviously a fixture if it ever leaks into a screenshot.
final Uint8List kFixtureImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR42mNYbquO'
  'FTEMLQkANU5CwbkqF8wAAAAASUVORK5CYII=',
);

ImageProvider fixtureImage() => MemoryImage(kFixtureImageBytes);
