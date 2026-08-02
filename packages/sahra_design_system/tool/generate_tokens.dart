// Generates lib/src/generated/tokens.g.dart from docs/design/tokens.json.
//
//   dart run tool/generate_tokens.dart          # write
//   dart run tool/generate_tokens.dart --check  # verify it is current (CI)
//
// tokens.json is the SINGLE SOURCE. Nothing here is hand-copied, so a value
// cannot drift: change the JSON, re-run, and the theme follows. The
// accompanying test regenerates in memory and fails if the checked-in file
// disagrees, which is what makes "drift is impossible" true rather than
// aspirational.
//
// Tokens are classified by the SHAPE of their value, never by a hardcoded list
// of names. A token added to the JSON tomorrow is picked up automatically; one
// whose shape we cannot classify is a hard error, not a silent skip.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = _repoRoot();
  final jsonFile = File('${root.path}/docs/design/tokens.json');
  if (!jsonFile.existsSync()) {
    stderr.writeln('tokens.json not found at ${jsonFile.path}');
    exit(1);
  }

  final source = generate(jsonFile.readAsStringSync());
  final target = File('${root.path}/packages/sahra_design_system/lib/src/generated/tokens.g.dart');

  if (args.contains('--check')) {
    final current = target.existsSync() ? target.readAsStringSync() : '';
    if (_normalise(current) != _normalise(source)) {
      stderr.writeln(
        'tokens.g.dart is STALE. tokens.json changed without regenerating.\n'
        'Run: dart run tool/generate_tokens.dart',
      );
      exit(1);
    }
    stdout.writeln('tokens.g.dart is current.');
    return;
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(source);
  stdout.writeln('Wrote ${target.path}');
}

Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (File('${dir.path}/docs/design/tokens.json').existsSync()) return dir;
    dir = dir.parent;
  }
  return Directory.current;
}

String _normalise(String s) => s.replaceAll('\r\n', '\n').trimRight();

// ─────────────────────────────────────────────────────────── classification ──

enum TokenKind { color, dimension, scalar, fontStack, shadow }

final _hex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
final _varRef = RegExp(r'^var\(--([a-z0-9-]+)\)$');
final _px = RegExp(r'^-?[\d.]+px$');
final _em = RegExp(r'^-?\.?[\d.]+em$');
final _num = RegExp(r'^-?[\d.]+$');

/// Follow `var(--x)` chains to the value that actually decides the type.
String _resolve(String value, Map<String, String> all, [int depth = 0]) {
  if (depth > 16) throw StateError('Cyclic token alias: $value');
  final m = _varRef.firstMatch(value);
  if (m == null) return value;
  final target = all[m.group(1)];
  if (target == null) throw StateError('Token alias points at missing token: $value');
  return _resolve(target, all, depth + 1);
}

TokenKind _classify(String name, String raw, Map<String, String> all) {
  final v = _resolve(raw, all);
  if (_hex.hasMatch(v)) return TokenKind.color;
  if (v.contains('rgba(')) return TokenKind.shadow;
  if (_px.hasMatch(v)) return TokenKind.dimension;
  if (_em.hasMatch(v) || _num.hasMatch(v)) return TokenKind.scalar;
  if (v.contains(',') || v.contains("'")) return TokenKind.fontStack;
  throw StateError(
    'Token "$name" has an unrecognised value shape: "$v".\n'
    'Add a rule to _classify rather than letting it be dropped silently.',
  );
}

// ───────────────────────────────────────────────────────────────── emitters ──

String _colorLiteral(String hex) {
  var h = hex.substring(1).toUpperCase();
  if (h.length == 6) h = 'FF$h';
  return 'Color(0x$h)';
}

String _doubleLiteral(String v) {
  final n = double.parse(v.replaceAll(RegExp(r'(px|em)$'), ''));
  return n == n.roundToDouble() ? '${n.toInt()}.0' : '$n';
}

/// A CSS font stack becomes (primary family, fallbacks) for Flutter's
/// fontFamily / fontFamilyFallback pair.
List<String> _families(String stack) => stack
    .split(',')
    .map((s) => s.trim().replaceAll("'", '').replaceAll('"', ''))
    .where((s) => s.isNotEmpty)
    .toList();

/// `0 1px 2px rgba(120,72,40,.07),0 1px 1px rgba(120,72,40,.05)`
/// → a list of BoxShadow. Splitting on the comma between layers means not
/// splitting on the commas inside rgba(), hence the depth counter.
String _shadowLiteral(String css) {
  final layers = <String>[];
  var depth = 0;
  var buf = StringBuffer();
  for (final ch in css.split('')) {
    if (ch == '(') depth++;
    if (ch == ')') depth--;
    if (ch == ',' && depth == 0) {
      layers.add(buf.toString());
      buf = StringBuffer();
    } else {
      buf.write(ch);
    }
  }
  if (buf.isNotEmpty) layers.add(buf.toString());

  final out = layers.map((layer) {
    final rgba = RegExp(r'rgba\(([^)]*)\)').firstMatch(layer);
    if (rgba == null) throw StateError('Shadow layer without rgba(): $layer');
    final parts = rgba.group(1)!.split(',').map((s) => s.trim()).toList();
    final r = int.parse(parts[0]);
    final g = int.parse(parts[1]);
    final b = int.parse(parts[2]);
    final a = double.parse(
        parts.length > 3 ? (parts[3].startsWith('.') ? '0${parts[3]}' : parts[3]) : '1');

    final lengths = layer
        .replaceRange(rgba.start, rgba.end, '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => double.parse(s.replaceAll('px', '')))
        .toList();
    final dx = lengths.isNotEmpty ? lengths[0] : 0.0;
    final dy = lengths.length > 1 ? lengths[1] : 0.0;
    final blur = lengths.length > 2 ? lengths[2] : 0.0;
    final spread = lengths.length > 3 ? lengths[3] : 0.0;

    final argb = ((a * 255).round() << 24) | (r << 16) | (g << 8) | b;
    final hex = argb.toRadixString(16).toUpperCase().padLeft(8, '0');
    return 'BoxShadow(color: Color(0x$hex), offset: Offset($dx, $dy), '
        'blurRadius: $blur, spreadRadius: $spread)';
  });

  return '<BoxShadow>[\n      ${out.join(',\n      ')},\n    ]';
}

String _camel(String kebab) {
  final parts = kebab.split('-');
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
}

String _dartType(TokenKind k) => switch (k) {
      TokenKind.color => 'Color',
      TokenKind.dimension => 'double',
      TokenKind.scalar => 'double',
      TokenKind.fontStack => 'SahraFontStack',
      TokenKind.shadow => 'List<BoxShadow>',
    };

// ──────────────────────────────────────────────────────────────── generation ──

String generate(String jsonSource) {
  final data = jsonDecode(jsonSource) as Map<String, dynamic>;
  final root = (data['root'] as Map<String, dynamic>).cast<String, String>();
  final night = (data['themeNight'] as Map<String, dynamic>).cast<String, String>();

  final b = StringBuffer();
  b.writeln('// GENERATED — DO NOT EDIT BY HAND.');
  b.writeln('//');
  b.writeln('// Source: docs/design/tokens.json (${root.length} light + ${night.length} night)');
  b.writeln('// Regenerate: dart run tool/generate_tokens.dart');
  b.writeln('//');
  b.writeln('// Editing this file instead of the JSON is the one way to make the design');
  b.writeln('// tokens and the app disagree. tokens_test.dart fails if you do.');
  // NOTE: this file is deliberately EXCLUDED from `dart format` (see CI and
  // the package README). Formatting it would rewrite the layout the generator
  // produced, and the drift test would then correctly report tampering.
  b.writeln("import 'package:flutter/painting.dart';");
  b.writeln();
  b.writeln('/// A CSS font stack, split for Flutter.');
  b.writeln('class SahraFontStack {');
  b.writeln('  const SahraFontStack(this.family, this.fallback);');
  b.writeln('  final String family;');
  b.writeln('  final List<String> fallback;');
  b.writeln('}');
  b.writeln();

  // Light — every token in `root`.
  b.writeln('/// Every token under `root` in tokens.json.');
  b.writeln('class SahraTokens {');
  b.writeln('  const SahraTokens._();');
  b.writeln();
  for (final entry in root.entries) {
    final kind = _classify(entry.key, entry.value, root);
    final resolved = _resolve(entry.value, root);
    final alias = _varRef.firstMatch(entry.value);
    final name = _camel(entry.key);
    final type = _dartType(kind);

    if (alias != null) {
      // Keep aliases as aliases: `accent` IS `terracotta`, and the generated
      // code should say so rather than duplicating the literal.
      b.writeln('  /// `${entry.key}` → `${entry.value}`');
      b.writeln('  static const $type $name = ${_camel(alias.group(1)!)};');
    } else {
      b.writeln('  /// `${entry.key}`: `${entry.value}`');
      b.writeln('  static const $type $name = ${_literal(kind, resolved)};');
    }
  }
  b.writeln();
  b.writeln('  /// Keyed by the token name exactly as it appears in tokens.json.');
  b.writeln('  /// The coverage test walks this, so a token cannot go unimplemented.');
  b.writeln('  static const Map<String, Object> byToken = <String, Object>{');
  for (final key in root.keys) {
    b.writeln("    '$key': ${_camel(key)},");
  }
  b.writeln('  };');
  b.writeln('}');
  b.writeln();

  // Night — the 7 overrides.
  b.writeln('/// The `themeNight` overrides. Dark mode changes ONLY these ${night.length}');
  b.writeln('/// tokens; everything else — terracotta above all — is shared, which is');
  b.writeln('/// why the brand does not shift between themes (DESIGN-RULES.md).');
  b.writeln('class SahraNightTokens {');
  b.writeln('  const SahraNightTokens._();');
  b.writeln();
  for (final entry in night.entries) {
    final alias = _varRef.firstMatch(entry.value);
    final kind = _classify(entry.key, entry.value, root);
    b.writeln('  /// `${entry.key}` → `${entry.value}`');
    if (alias != null) {
      b.writeln(
          '  static const ${_dartType(kind)} ${_camel(entry.key)} = SahraTokens.${_camel(alias.group(1)!)};');
    } else {
      b.writeln(
          '  static const ${_dartType(kind)} ${_camel(entry.key)} = ${_literal(kind, entry.value)};');
    }
  }
  b.writeln();
  b.writeln('  static const Map<String, Object> byToken = <String, Object>{');
  for (final key in night.keys) {
    b.writeln("    '$key': ${_camel(key)},");
  }
  b.writeln('  };');
  b.writeln('}');

  return b.toString();
}

String _literal(TokenKind kind, String resolved) => switch (kind) {
      TokenKind.color => _colorLiteral(resolved),
      TokenKind.dimension || TokenKind.scalar => _doubleLiteral(resolved),
      TokenKind.shadow => _shadowLiteral(resolved),
      TokenKind.fontStack => () {
          final f = _families(resolved);
          final fallback = f.skip(1).map((s) => "'$s'").join(', ');
          return "SahraFontStack('${f.first}', <String>[$fallback])";
        }(),
    };
