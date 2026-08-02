/// The client cannot drift from the backend without something going red.
///
/// Three links in the chain, each with its own failure:
///   controller changes -> spec stale   (apps/api: pnpm openapi:export --check)
///   spec changes       -> client stale (this file)
///   client changes     -> CALL SITE fails to compile (the compiler, in the app)
///
/// The third is the one that matters and the only one no test can assert here —
/// it is proved by the app failing to build, which the deliberate-break record
/// in the wave report demonstrates.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/generate_client.dart' as generator;

Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (File('${dir.path}/apps/api/openapi.json').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('repo root not found from ${Directory.current.path}');
}

void main() {
  final root = _repoRoot();
  final spec = File('${root.path}/apps/api/openapi.json').readAsStringSync();
  final generated = generator.generate(spec);

  group('the spec is real', () {
    final doc = jsonDecode(spec) as Map<String, dynamic>;

    test('it describes a plausible API', () {
      // Census: an empty spec would satisfy every assertion below by having
      // nothing to check.
      expect((doc['paths'] as Map).length, greaterThanOrEqualTo(20));
      expect(((doc['components'] as Map)['schemas'] as Map).length,
          greaterThanOrEqualTo(30));
    });

    test('every operation with a body declares a response schema', () {
      // The rule the generator enforces, asserted here too so the reason is
      // visible without reading the generator.
      final untyped = <String>[];
      (doc['paths'] as Map).forEach((path, ops) {
        (ops as Map).forEach((method, op) {
          final responses = (op as Map)['responses'] as Map;
          final ok = responses.keys.firstWhere(
            (k) => (k as String).startsWith('2'),
            orElse: () => '',
          );
          if (ok == '') return;
          final content = (responses[ok] as Map)['content'];
          if (content == null) return; // 204, legitimately no body
          final schema = ((content as Map)['application/json'] as Map?)?['schema'];
          if (schema == null) untyped.add('${method.toString().toUpperCase()} $path');
        });
      });
      expect(untyped, isEmpty,
          reason: 'Untyped responses would become dynamic in the client:\n'
              '${untyped.join('\n')}');
    });
  });

  group('the generated client matches the spec', () {
    for (final name in <String>['models.g.dart', 'api.g.dart']) {
      test('$name is current', () {
        final file =
            File('${root.path}/packages/sahra_api_client/lib/src/generated/$name');
        expect(file.existsSync(), isTrue, reason: '$name is not committed');
        expect(
          file.readAsStringSync().replaceAll('\r\n', '\n').trimRight(),
          generated[name]!.replaceAll('\r\n', '\n').trimRight(),
          reason: '$name is stale or hand-edited.\n'
              'Run: dart run tool/generate_client.dart',
        );
      });
    }
  });

  group('the generator refuses to emit dynamic', () {
    test('an operation returning a body with no schema is a hard error', () {
      // The guarantee, exercised rather than asserted about. If this ever
      // stops throwing, `dynamic` has become reachable and the whole point of
      // the package is gone.
      const broken = '''
      {"paths":{"/v1/x":{"get":{"responses":{"200":{"content":{"application/json":{}}}}}}},
       "components":{"schemas":{}}}
      ''';
      expect(
        () => generator.generate(broken),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no schema'),
        )),
      );
    });

    test('an untypeable schema is a hard error too', () {
      const weird = '''
      {"paths":{},"components":{"schemas":{"X":{"properties":{"y":{"type":"quantum"}}}}}}
      ''';
      expect(() => generator.generate(weird), throwsA(isA<StateError>()));
    });
  });
}
