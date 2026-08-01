// "No hardcoded colors, spacing, or radii anywhere. Ever."
//
// A rule nothing enforces is a rule that decays the first busy afternoon. This
// walks the package source and fails on the patterns that break it, so the
// rule is a build failure rather than a code-review habit.
//
// It runs against lib/ only. The generated token file is the one legitimate
// home for colour literals, and the tool/ and test/ directories are not
// shipped UI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _libDir() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final d = Directory('${dir.path}/packages/sahra_design_system/lib');
    if (d.existsSync()) return d;
    if (Directory('${dir.path}/lib').existsSync() &&
        File('${dir.path}/pubspec.yaml').existsSync()) {
      return Directory('${dir.path}/lib');
    }
    dir = dir.parent;
  }
  throw StateError('lib/ not found from ${Directory.current.path}');
}

/// Everything under lib/ except the generated token file.
List<File> _sources() => _libDir()
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.replaceAll(r'\', '/').endsWith('generated/tokens.g.dart'))
    .toList();

/// Strip comments so prose about `EdgeInsets.only(left:)` does not trip a rule
/// about writing it.
String _code(File f) => f
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .split('\n')
    .map((l) {
      final i = l.indexOf('//');
      return i == -1 ? l : l.substring(0, i);
    })
    .join('\n');

void main() {
  final sources = _sources();

  test('there is something to check', () {
    expect(sources, isNotEmpty);
  });

  group('no hardcoded design values in widget code', () {
    test('no colour literals outside the generated tokens', () {
      final offenders = <String>[];
      for (final f in sources) {
        final code = _code(f);
        for (final pattern in <RegExp>[
          RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)'),
          RegExp(r'Colors\.[a-zA-Z]+'),
          RegExp(r'Color\.fromARGB'),
          RegExp(r'Color\.fromRGBO'),
        ]) {
          for (final m in pattern.allMatches(code)) {
            offenders.add('${f.uri.pathSegments.last}: ${m.group(0)}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Colours must come from SahraTokens / SahraSemantics:\n${offenders.join('\n')}',
      );
    });

    test('no bare numbers in EdgeInsets / BorderRadius / SizedBox', () {
      final offenders = <String>[];
      for (final f in sources) {
        final code = _code(f);
        for (final pattern in <RegExp>[
          // A literal number rather than a SahraSpace / SahraRadius constant.
          RegExp(r'EdgeInsets(Directional)?\.[a-zA-Z]+\([^)]*\b\d+\.?\d*\b'),
          RegExp(r'BorderRadius(Directional)?\.circular\(\s*\d'),
          RegExp(r'Radius\.circular\(\s*\d'),
          RegExp(r'SizedBox\((height|width):\s*\d'),
        ]) {
          for (final m in pattern.allMatches(code)) {
            // EdgeInsets.zero and Size(...) built from SahraRules are fine.
            if (m.group(0)!.contains('zero')) continue;
            offenders.add('${f.uri.pathSegments.last}: ${m.group(0)}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Spacing and radii must come from SahraSpace / SahraRadius:\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('RTL is not optional', () {
    test('no direction-blind EdgeInsets.only(left:/right:)', () {
      final offenders = <String>[];
      for (final f in sources) {
        final code = _code(f);
        for (final pattern in <RegExp>[
          RegExp(r'EdgeInsets\.only\([^)]*\b(left|right)\s*:'),
          RegExp(r'EdgeInsets\.fromLTRB\('),
          RegExp(r'Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)'),
          RegExp(r'BorderRadius\.only\('),
          RegExp(r'Positioned\((?![^)]*(start|end))[^)]*\b(left|right)\s*:'),
        ]) {
          for (final m in pattern.allMatches(code)) {
            offenders.add('${f.uri.pathSegments.last}: ${m.group(0)}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Use the directional variants — in Arabic the leading edge is on '
            'the RIGHT, and a hardcoded left mirrors the layout wrongly without '
            'ever failing:\n${offenders.join('\n')}',
      );
    });
  });
}
