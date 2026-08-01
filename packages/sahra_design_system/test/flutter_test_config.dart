import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs ONCE before every test in this package. Flutter picks this file up by
/// name — there is no import anywhere.
///
/// THE REASON THIS FILE EXISTS: Flutter's test renderer ships no fonts. Every
/// glyph draws as a filled box unless a font is explicitly loaded. Goldens
/// taken that way are stable, diffable, reviewable — and worthless. They would
/// have hidden exactly the bug fixed in f9a6283, where the tokens named three
/// families the repo did not contain.
///
/// Loading here rather than per-test means a new golden file cannot be written
/// against boxes by someone who forgot the setup.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadSahraFonts();
  return testMain();
}

/// family name → the asset paths declared in pubspec.yaml.
///
/// Kept in step with pubspec by `font_guard_test.dart`, which reads the
/// pubspec and fails if a declared family is missing from this map.
const Map<String, List<String>> sahraFontAssets = <String, List<String>>{
  'Poppins': <String>[
    'fonts/Poppins-Light.ttf',
    'fonts/Poppins-Regular.ttf',
    'fonts/Poppins-Medium.ttf',
    'fonts/Poppins-SemiBold.ttf',
    'fonts/Poppins-Bold.ttf',
  ],
  'IBM Plex Sans Arabic': <String>[
    'fonts/IBMPlexSansArabic-Regular.ttf',
    'fonts/IBMPlexSansArabic-Medium.ttf',
    'fonts/IBMPlexSansArabic-SemiBold.ttf',
  ],
  'Reem Kufi': <String>['fonts/ReemKufi-Variable.ttf'],
  'Newsreader': <String>['fonts/Newsreader-Variable.ttf'],
};

bool _loaded = false;

/// Load the bundled families into the test renderer.
///
/// Reads from disk rather than through `rootBundle`, because the package's
/// assets are not bundled when it is under test as a library.
Future<void> loadSahraFonts() async {
  if (_loaded) return;
  final root = _packageRoot();

  for (final entry in sahraFontAssets.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      final file = File('${root.path}/$asset');
      if (!file.existsSync()) {
        throw StateError(
          'Font asset missing: $asset for "${entry.key}".\n'
          'Goldens taken without it would render blank boxes and prove nothing.',
        );
      }
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }
  _loaded = true;
}

Directory _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: sahra_design_system')) {
      return dir;
    }
    final nested = Directory('${dir.path}/packages/sahra_design_system');
    if (nested.existsSync()) return nested;
    dir = dir.parent;
  }
  throw StateError('sahra_design_system root not found from ${Directory.current.path}');
}
