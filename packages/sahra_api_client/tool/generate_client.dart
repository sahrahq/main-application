/// Generates the SAHRA API client from apps/api/openapi.json.
///
///   dart run tool/generate_client.dart          # write
///   dart run tool/generate_client.dart --check  # fail if stale (CI)
///
/// Same contract as `generate_tokens.dart`: the spec is the single source, the
/// output is committed, and a drift check makes "hand-edited" a build failure
/// rather than a discovery.
///
/// THE ONE RULE THIS ENFORCES ABOVE ALL: an operation whose success response
/// has a body but no schema is a HARD ERROR. Emitting `dynamic` there would
/// move every renamed field and every changed type from a compile error at the
/// call site to a runtime surprise in a screen — which is the entire reason
/// this package exists. There is no flag to turn it off.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = _repoRoot();
  final specFile = File('${root.path}/apps/api/openapi.json');
  if (!specFile.existsSync()) {
    stderr.writeln('openapi.json not found. Run: pnpm openapi:export (in apps/api)');
    exit(1);
  }

  final generated = generate(specFile.readAsStringSync());
  final dir = Directory('${root.path}/packages/sahra_api_client/lib/src/generated');

  if (args.contains('--check')) {
    var stale = false;
    generated.forEach((name, source) {
      final f = File('${dir.path}/$name');
      final current = f.existsSync() ? f.readAsStringSync() : '';
      if (_normalise(current) != _normalise(source)) {
        stderr.writeln('$name is STALE.');
        stale = true;
      }
    });
    if (stale) {
      stderr.writeln(
        '\nThe generated client no longer matches apps/api/openapi.json.\n'
        'Run: dart run tool/generate_client.dart',
      );
      exit(1);
    }
    stdout.writeln('Generated client is current.');
    return;
  }

  dir.createSync(recursive: true);
  generated.forEach((name, source) {
    File('${dir.path}/$name').writeAsStringSync(source);
    stdout.writeln('Wrote ${dir.path}/$name');
  });
}

Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (File('${dir.path}/apps/api/openapi.json').existsSync()) return dir;
    dir = dir.parent;
  }
  return Directory.current;
}

String _normalise(String s) => s.replaceAll('\r\n', '\n').trimRight();

// ─────────────────────────────────────────────────────────────────── types ──

class _Type {
  const _Type(this.dart, {this.fromJson, this.toJson});

  final String dart;

  /// Expression templates; `%s` is the value.
  final String? fromJson;
  final String? toJson;

  String decode(String expr) => fromJson == null ? expr : fromJson!.replaceAll('%s', expr);
  String encode(String expr) => toJson == null ? expr : toJson!.replaceAll('%s', expr);
}

String _className(String ref) => ref.split('/').last;

String _camel(String s) {
  final parts = s.split(RegExp(r'[_\-\s]')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return s;
  // lowerCamelCase, including the FIRST segment: `Idempotency-Key` must become
  // `idempotencyKey`, not `IdempotencyKey` — which compiled as a type name and
  // produced a parameter nobody could pass. Caught by the call-site canary.
  final head = parts.first;
  return (head[0].toLowerCase() + head.substring(1)) +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// Map a schema node to a Dart type.
///
/// Throws on anything it cannot type. A generator that silently degrades to
/// `dynamic` is worse than no generator: it looks like type safety and is not.
_Type _typeOf(Map<String, dynamic> schema, String where) {
  if (schema.containsKey(r'$ref')) {
    final name = _className(schema[r'$ref'] as String);
    return _Type(name,
        fromJson: '$name.fromJson(%s as Map<String, dynamic>)', toJson: '%s.toJson()');
  }

  final type = schema['type'];
  switch (type) {
    case 'string':
      return const _Type('String', fromJson: '%s as String');
    case 'integer':
      return const _Type('int', fromJson: '(%s as num).toInt()');
    case 'number':
      return const _Type('double', fromJson: '(%s as num).toDouble()');
    case 'boolean':
      return const _Type('bool', fromJson: '%s as bool');
    case 'array':
      final items = schema['items'];
      if (items == null) {
        throw StateError('Array without items at $where — cannot type it.');
      }
      final inner = _typeOf((items as Map).cast<String, dynamic>(), '$where[]');
      return _Type(
        'List<${inner.dart}>',
        fromJson: '(%s as List<dynamic>).map((e) => ${inner.decode('e')}).toList()',
        toJson: '%s.map((e) => ${inner.encode('e')}).toList()',
      );
    case 'object':
      // A DECLARED free-form object — `defaultTurnMinutes` is genuinely a map
      // of party-band to minutes. This is NOT the `dynamic` escape hatch: the
      // spec says object, so a map is the honest type. An operation with no
      // response schema at all still throws below.
      return const _Type('Map<String, dynamic>', fromJson: '%s as Map<String, dynamic>');
  }

  throw StateError(
    'Cannot type schema at $where: ${jsonEncode(schema)}\n'
    'Add a rule to _typeOf rather than letting it become dynamic.',
  );
}

// ───────────────────────────────────────────────────────────── generation ──

Map<String, String> generate(String specJson) {
  final spec = jsonDecode(specJson) as Map<String, dynamic>;
  final schemas =
      ((spec['components'] as Map?)?['schemas'] as Map?)?.cast<String, dynamic>() ?? {};
  final paths = (spec['paths'] as Map).cast<String, dynamic>();

  return <String, String>{
    'models.g.dart': _models(schemas),
    'api.g.dart': _api(paths),
  };
}

String _header(String what) => '''
// GENERATED — DO NOT EDIT BY HAND.
//
// Source: apps/api/openapi.json, exported from the running NestJS app.
// Regenerate: dart run tool/generate_client.dart
//
// $what
//
// Editing this file is how the client and the backend start to disagree
// without anyone noticing. client_drift_test.dart fails if you do.

''';

String _models(Map<String, dynamic> schemas) {
  final b = StringBuffer(_header('Request and response models.'));

  for (final name in schemas.keys.toList()..sort()) {
    final schema = (schemas[name] as Map).cast<String, dynamic>();
    final props = (schema['properties'] as Map?)?.cast<String, dynamic>() ?? {};
    final required = ((schema['required'] as List?) ?? const <dynamic>[]).cast<String>().toSet();

    final fields = <_Field>[];
    for (final propName in props.keys.toList()..sort()) {
      final prop = (props[propName] as Map).cast<String, dynamic>();
      final type = _typeOf(prop, '$name.$propName');
      final nullable = !required.contains(propName) || prop['nullable'] == true;
      fields.add(_Field(propName, type, nullable, prop['description'] as String?));
    }

    b.writeln('class $name {');
    b.writeln('  const $name({');
    for (final f in fields) {
      b.writeln('    ${f.nullable ? '' : 'required '}this.${f.dartName},');
    }
    b.writeln('  });');
    b.writeln();
    b.writeln('  factory $name.fromJson(Map<String, dynamic> json) => $name(');
    for (final f in fields) {
      final raw = "json['${f.wireName}']";
      b.writeln(f.nullable
          ? '        ${f.dartName}: $raw == null ? null : ${f.type.decode(raw)},'
          : '        ${f.dartName}: ${f.type.decode(raw)},');
    }
    b.writeln('      );');
    b.writeln();
    for (final f in fields) {
      if (f.doc != null) b.writeln('  /// ${f.doc!.replaceAll('\n', ' ')}');
      b.writeln('  final ${f.type.dart}${f.nullable ? '?' : ''} ${f.dartName};');
    }
    b.writeln();
    b.writeln('  Map<String, dynamic> toJson() => <String, dynamic>{');
    for (final f in fields) {
      final v = f.dartName;
      // `!` rather than a cast: `x as List<T>.map(...)` parses as a cast to
      // `List<T>.map`, which is not a type. Caught by dart analyze on the
      // generated output — which is why the generated file is analysed.
      b.writeln(f.nullable
          ? "        if ($v != null) '${f.wireName}': ${f.type.encode('$v!')},"
          : "        '${f.wireName}': ${f.type.encode(v)},");
    }
    b.writeln('      };');
    b.writeln('}');
    b.writeln();
  }
  return b.toString();
}

class _Field {
  _Field(this.wireName, this.type, this.nullable, this.doc);

  final String wireName;
  final _Type type;
  final bool nullable;
  final String? doc;

  String get dartName {
    final c = _camel(wireName);
    const reserved = <String>{'is', 'in', 'default', 'class', 'new', 'if', 'for'};
    return reserved.contains(c) ? '${c}_' : c;
  }
}

String _api(Map<String, dynamic> paths) {
  final b = StringBuffer(_header('Typed endpoint methods.'));
  b.writeln("import 'models.g.dart';");
  b.writeln("import '../transport.dart';");
  b.writeln();
  b.writeln('/// Every endpoint in the committed spec, typed both ways.');
  b.writeln('class SahraApi {');
  b.writeln('  const SahraApi(this._transport);');
  b.writeln();
  b.writeln('  final SahraTransport _transport;');

  final seen = <String>{};

  for (final path in paths.keys.toList()..sort()) {
    final ops = (paths[path] as Map).cast<String, dynamic>();
    for (final method in ops.keys.toList()..sort()) {
      final op = (ops[method] as Map).cast<String, dynamic>();
      final name = _operationName(op, method, path, seen);

      final responses = (op['responses'] as Map).cast<String, dynamic>();
      final okCode = responses.keys.firstWhere(
        (c) => c.startsWith('2'),
        orElse: () => throw StateError('$method $path has no 2xx response'),
      );
      final ok = (responses[okCode] as Map).cast<String, dynamic>();
      final content = (ok['content'] as Map?)?.cast<String, dynamic>();

      _Type? returns;
      if (content != null) {
        final json = (content['application/json'] as Map?)?.cast<String, dynamic>();
        final schema = (json?['schema'] as Map?)?.cast<String, dynamic>();
        if (schema == null) {
          throw StateError(
            '$method $path returns a body with no schema.\n'
            'Add @ApiOkResponse({ type: ... }) to the controller. This generator '
            'will not emit `dynamic` — see the note at the top of this file.',
          );
        }
        returns = _typeOf(schema, '$method $path');
      }

      // Parameters.
      final params = ((op['parameters'] as List?) ?? const <dynamic>[])
          .map((p) => (p as Map).cast<String, dynamic>())
          .toList();

      // A parameter declared twice in the same location is an INVALID spec,
      // and it produced a Dart method with two identically-named arguments.
      // Nest emitted `Idempotency-Key` from @ApiHeader and `idempotency-key`
      // from @Headers; both camelised to the same name. Reject rather than
      // silently pick one — the fix belongs in the controller.
      final seenParams = <String>{};
      for (final p in params) {
        final location = p['in'];
        final pname = p['name'] as String;
        final key = '$location:${_camel(pname).toLowerCase()}';
        if (!seenParams.add(key)) {
          throw StateError(
            '$method $path declares "$pname" twice in $location.\n'
            'Align @ApiHeader/@ApiQuery with the name the controller reads.',
          );
        }
      }
      final pathParams = params.where((p) => p['in'] == 'path').toList();
      final queryParams = params.where((p) => p['in'] == 'query').toList();
      final headerParams = params.where((p) => p['in'] == 'header').toList();

      final body = (op['requestBody'] as Map?)?.cast<String, dynamic>();
      _Type? bodyType;
      if (body != null) {
        final schema = (((body['content'] as Map)['application/json'] as Map)['schema'] as Map)
            .cast<String, dynamic>();
        bodyType = _typeOf(schema, '$method $path body');
      }

      final args = <String>[
        for (final p in pathParams) 'required String ${_camel(p['name'] as String)}',
        if (bodyType != null) 'required ${bodyType.dart} body',
        for (final p in headerParams)
          '${p['required'] == true ? 'required ' : ''}String${p['required'] == true ? '' : '?'} ${_camel(p['name'] as String)}',
        for (final p in queryParams) 'String? ${_camel(p['name'] as String)}',
      ];

      final returnType = returns == null ? 'void' : returns.dart;
      b.writeln();
      b.writeln('  /// `${method.toUpperCase()} $path`');
      if (op['summary'] != null) b.writeln('  ///\n  /// ${op['summary']}');
      b.writeln('  Future<$returnType> $name(${args.isEmpty ? '' : '{\n    ${args.join(',\n    ')},\n  }'}) async {');

      var uri = path;
      for (final p in pathParams) {
        uri = uri.replaceAll('{${p['name']}}', '\$${_camel(p['name'] as String)}');
      }
      b.writeln(returns == null
          ? '    await _transport.send('
          : '    final response = await _transport.send(');
      b.writeln("      method: '${method.toUpperCase()}',");
      b.writeln("      path: '$uri',");
      if (queryParams.isNotEmpty) {
        b.writeln('      query: <String, String>{');
        for (final p in queryParams) {
          final n = _camel(p['name'] as String);
          b.writeln("        if ($n != null) '${p['name']}': $n,");
        }
        b.writeln('      },');
      }
      if (headerParams.isNotEmpty) {
        b.writeln('      headers: <String, String>{');
        for (final p in headerParams) {
          final n = _camel(p['name'] as String);
          b.writeln(p['required'] == true
              ? "        '${p['name']}': $n,"
              : "        if ($n != null) '${p['name']}': $n,");
        }
        b.writeln('      },');
      }
      if (bodyType != null) b.writeln('      body: ${bodyType.encode('body')},');
      b.writeln('    );');

      if (returns == null) {
        b.writeln('    return;');
      } else {
        b.writeln('    return ${returns.decode('response')};');
      }
      b.writeln('  }');
    }
  }

  b.writeln('}');
  return b.toString();
}

/// A stable, readable method name. `operationId` when Nest provides one,
/// otherwise derived from the path so it does not change run to run.
String _operationName(
  Map<String, dynamic> op,
  String method,
  String path,
  Set<String> seen,
) {
  var name = op['operationId'] as String?;
  if (name != null && name.contains('_')) name = name.split('_').last;
  name ??= _camel(
    '$method ${path.replaceAll(RegExp(r'[{}]'), '').replaceAll('/', ' ').trim()}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' ', '_'),
  );
  var unique = name;
  var n = 2;
  while (!seen.add(unique)) {
    unique = '$name$n';
    n++;
  }
  return unique;
}
