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
import 'package:sahra_api_client/src/generated/api.g.dart';

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

    // ── the one that got through ───────────────────────────────────────────
    //
    // `@ApiPropertyOptional({ nullable: true })` with no `type` makes Nest
    // emit `{"nullable":true,"type":"object"}` — byte-identical to a genuine
    // free-form map. The generator had ONE deliberate exception for
    // `type: object` (defaultTurnMinutes is really a map), and that exception
    // silently swallowed 28 string, number and date fields across the whole
    // client: SearchResponse.next_cursor, ReservationResponse.holdExpiresAt
    // and UserResponse.email were all `Map<String, dynamic>`.
    //
    // Nobody argued for the escape hatch. The framework created it. So the
    // rule is now: a map must SAY what it maps to.
    test('a bare `type: object` property is a hard error, not a map', () {
      const bare = '''
      {"paths":{},"components":{"schemas":{
        "X":{"properties":{"maybeName":{"type":"object","nullable":true}}}}}}
      ''';
      expect(
        () => generator.generate(bare),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('additionalProperties'))),
      );
    });

    test('a map that declares its value type is fine, and is typed', () {
      const declared = '''
      {"paths":{},"components":{"schemas":{
        "X":{"properties":{"turns":{"type":"object","additionalProperties":{"type":"integer"}}}}}}}
      ''';
      final out = generator.generate(declared)['models.g.dart']!;
      expect(out, contains('Map<String, int>?'));
    });

    test('`additionalProperties: true` is a deliberate free-form object', () {
      // `policies` really is open-ended JSON. The difference between this and
      // the case above is not the resulting type — it is that somebody typed
      // the words. A decision is allowed; an accident is not.
      const freeForm = '''
      {"paths":{},"components":{"schemas":{
        "X":{"properties":{"policies":{"type":"object","additionalProperties":true}}}}}}
      ''';
      final out = generator.generate(freeForm)['models.g.dart']!;
      expect(out, contains('Map<String, dynamic>? policies'));
    });
  });

  group('no field in the committed client is an untyped map', () {
    // The census: count what the scan actually READ, never what it should
    // have found. A regex that silently matches nothing would otherwise report
    // a clean bill of health for a file it never opened.
    test('every generated field has a real Dart type', () {
      final models = File('lib/src/generated/models.g.dart').readAsStringSync();
      final fields = RegExp(r'^  final ([\w<>, ?]+) (\w+);$', multiLine: true)
          .allMatches(models)
          .map((m) => '${m.group(1)} ${m.group(2)}')
          .toList();

      expect(
        fields.length,
        greaterThan(100),
        reason: 'Only ${fields.length} fields parsed out of a ${models.length}-byte file — '
            'the scanner is broken, not the client.',
      );

      // `policies` is the ONE field allowed to be free-form, and it is named
      // here rather than pattern-matched: an allowance that grows by itself is
      // the escape hatch coming back.
      const deliberatelyFreeForm = <String>{'Map<String, dynamic>? policies'};

      final maps = fields
          .where((f) => f.startsWith('Map<String, dynamic>'))
          .where((f) => !deliberatelyFreeForm.contains(f))
          .toList();
      expect(
        maps,
        isEmpty,
        reason: '${maps.length} field(s) are untyped maps. A `Map<String, dynamic>` '
            'here compiles at every call site and fails at runtime:\n  ${maps.join('\n  ')}',
      );
    });
  });

  group('endpoints the client deliberately does not expose', () {
    // A method that failed to generate looks exactly like an endpoint that
    // does not exist. The generator records its skips in the output; this pins
    // the list, so one more disappearing is a decision somebody makes rather
    // than a thing that happens.
    test('the skip list is exactly the one we agreed', () {
      expect(kUngeneratedEndpoints, <String>[
        // Admin-only, and there is no admin Flutter surface. Teaching
        // SahraTransport to build multipart bodies for a caller that does not
        // exist would be surface with no user. See doc 10 §3b.
        'POST /v1/admin/restaurants/{restaurantId}/images — multipart/form-data',
      ]);
    });

    test('and everything else in the spec DID generate', () {
      // Guards the guard. If the generator started skipping silently — say a
      // future refactor stopped appending to the list — the assertion above
      // would pass on an empty list while methods went missing.
      final api = File('lib/src/generated/api.g.dart').readAsStringSync();
      final spec = jsonDecode(File('../../apps/api/openapi.json').readAsStringSync())
          as Map<String, dynamic>;

      final operations = <String>[];
      (spec['paths'] as Map<String, dynamic>).forEach((path, item) {
        (item as Map<String, dynamic>).forEach((method, _) {
          operations.add('${method.toUpperCase()} $path');
        });
      });

      // COUNTED BY THE TRANSPORT CALL, not by a return-type regex. The first
      // version matched `Future<[^>]+>` and undercounted by six, because a
      // nested generic — `Future<List<MyReservationResponse>>` — stops the
      // character class at the inner `>`. Every generated method makes
      // exactly one transport call, so counting those cannot be fooled by a
      // type signature.
      final generatedMethods = RegExp(r'await _transport\.send\(').allMatches(api).length;
      expect(
        generatedMethods,
        operations.length - kUngeneratedEndpoints.length,
        reason: 'The client has $generatedMethods methods for '
            '${operations.length} spec operations minus '
            '${kUngeneratedEndpoints.length} declared skips. Something was '
            'dropped without being recorded.',
      );
    });
  });

  group('method names do not depend on registration order', () {
    // ── THE HAZARD THIS EXISTS FOR ────────────────────────────────────────
    //
    // Method names come from Nest's `Controller_method` operationId, reduced
    // to the method part. Two controllers with a `list` handler collide, and
    // the generator de-duplicates by appending a digit — in ARRIVAL ORDER.
    //
    // Adding `AdminImagesController.list` renamed the reservations one from
    // `list2` to `list3`, in a completely unrelated endpoint, in a generated
    // file. The Dart compiler caught it because the return types differed. Had
    // they matched, the app would have compiled and called the WRONG ENDPOINT.
    //
    // So a numeric suffix is banned outright. Fixing a collision means naming
    // the controller method properly, which is a better name anyway.
    test('no generated method name ends in a digit', () {
      final api = File('lib/src/generated/api.g.dart').readAsStringSync();
      final names = RegExp(r'Future<[^;{]+> (\w+)\(')
          .allMatches(api)
          .map((m) => m.group(1)!)
          .where((n) => RegExp(r'\d$').hasMatch(n))
          .toList();

      expect(
        names,
        isEmpty,
        reason: 'These names were de-duplicated by the generator, so they '
            'depend on the order controllers are registered in — an unrelated '
            'new endpoint can silently rename them: ${names.join(", ")}. '
            'Rename the CONTROLLER METHOD instead.',
      );
    });
  });
}
