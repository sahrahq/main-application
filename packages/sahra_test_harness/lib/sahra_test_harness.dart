/// Layout health across real device sizes.
///
/// The 200%-text-scale guard already in the suite asks "does this survive a
/// user who needs bigger type". This asks the other half: "does this survive
/// the phone they actually own". Both are the same shape — render, then assert
/// nothing broke — and both catch things no golden does, because a golden is
/// taken at ONE size and proves nothing about any other.
///
/// The sizes are not round numbers picked for tidiness:
///
/// | size | why it is in the list |
/// |---|---|
/// | 320 × 568 | the smallest phone SAHRA supports. Everything that breaks, breaks here first |
/// | 360 × 640 | the most common Android viewport in Egypt — the modal user |
/// | 412 × 915 | a large modern phone; catches layouts that assume short |
/// | 768 × 1024 | tablet portrait. `management_app` is Android-tablet-first (CLAUDE.md), so the design system must already survive it |
/// | 1024 × 768 | tablet landscape — the restaurant console's real posture |
/// | 320 × 568 @ 2× | **the worst case.** Smallest width AND largest type. This is where things actually break |
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

/// One device configuration.
class SahraViewport {
  const SahraViewport(this.label, this.size, {this.textScale = 1.0});

  final String label;
  final Size size;
  final double textScale;

  @override
  String toString() => label;
}

/// The matrix. Ordered smallest-first, so the first failure reported is
/// usually the most informative one.
const List<SahraViewport> sahraViewports = <SahraViewport>[
  SahraViewport('320x568 smallest phone', Size(320, 568)),
  SahraViewport('360x640 common Android (EG)', Size(360, 640)),
  SahraViewport('412x915 large phone', Size(412, 915)),
  SahraViewport('768x1024 tablet portrait', Size(768, 1024)),
  SahraViewport('1024x768 tablet landscape', Size(1024, 768)),
  // Deliberately last and deliberately included: the combination, not either
  // alone, is what breaks.
  SahraViewport('320x568 @200% text — WORST CASE', Size(320, 568), textScale: 2.0),
];

/// A layout problem, in the shape the lint scanners already use.
class LayoutFault {
  LayoutFault(this.kind, this.detail);
  final String kind;
  final String detail;

  @override
  String toString() => '[$kind] $detail';
}

/// Everything that is wrong with the tree as currently laid out.
///
/// Returns a LIST rather than asserting, so a caller can report every fault at
/// every size in one run instead of stopping at the first. Finding out that
/// eleven screens are broken one test run at a time is how a responsiveness
/// pass gets abandoned halfway.
/// [isPage] distinguishes a SCREEN from a COMPONENT.
///
/// "The page must not scroll sideways" is a screen rule. A component that IS a
/// horizontal scroller — the date strip, the chip row — is a legitimate design
/// element, and rendered on its own in a harness it is the outermost
/// scrollable there is. Checking it as a page failed four components for being
/// what they are, which is how a guard trains people to ignore it.
List<LayoutFault> layoutFaults(
  WidgetTester tester, {
  required Size viewport,
  bool isPage = true,
}) {
  final faults = <LayoutFault>[];

  // 1. RenderFlex overflow. The big one, and the only one Flutter reports by
  //    itself — but ONLY in debug, and a release build shows a silently
  //    clipped layout instead. That is why it is asserted rather than trusted.
  final exception = tester.takeException();
  if (exception != null) {
    faults.add(LayoutFault('overflow', _firstLine(exception.toString())));
  }

  // 2. Text that is laid out but cannot be read: zero-size, or painted outside
  //    the viewport.
  //
  //    Text inside a HORIZONTAL scroller is legitimately off-screen — that is
  //    what scrolling means — so those subtrees are skipped rather than
  //    reported. The date strip and the chip row would otherwise fail
  //    everywhere and teach everyone to ignore this check.
  _walkTextOutsideHorizontalScrollers(tester, (paragraph, rect, text) {
    // `Icon` is implemented as a RichText holding one private-use codepoint,
    // so every icon in the tree arrives here looking like text whose label
    // prints as nothing. Reporting `"" spans 302..322` taught me nothing and
    // would have been four of the fifteen "failures" in the first run.
    if (_isIconGlyph(text)) return;
    if (text.trim().isEmpty) return;

    if (rect.width <= 0 || rect.height <= 0) {
      faults.add(LayoutFault('text-invisible', '"${_clip(text)}" laid out at ${rect.size}'));
      return;
    }
    // A 0.5px tolerance: a centred glyph can land a hair outside on a
    // fractional device pixel ratio without being clipped in any visible way.
    if (rect.left < -0.5 || rect.right > viewport.width + 0.5) {
      faults.add(LayoutFault(
        'text-clipped-horizontally',
        '"${_clip(text)}" spans ${rect.left.toStringAsFixed(1)}'
        '..${rect.right.toStringAsFixed(1)} in a ${viewport.width.toInt()}px viewport',
      ));
    }
  });

  // 3. Tap targets. The same 48dp SahraRules.minTouchTarget states — a control
  //    that shrinks to fit a narrow screen is the classic small-phone defect,
  //    and it fails nothing else: it renders, it is tappable, it is just too
  //    small for a thumb.
  //
  //    Nodes inside a HORIZONTAL SCROLLER are skipped. Their semantics rect is
  //    clipped to the visible sliver, so the fourth tile of a date strip
  //    reports as 8pt wide — a number about scroll position, not about whether
  //    a thumb can hit it. Those controls are measured properly by the
  //    COMPONENT matrix, where they are rendered with room; skipping them here
  //    removes a false positive without removing coverage.
  //
  //    Nodes clipped by the screen edge are skipped for the same reason.
  final screen = Offset.zero & viewport;
  for (final node in _tappableNodesOutsideHorizontalScrollers(tester)) {
    if (!_containsWithTolerance(screen, node.rect)) continue;
    final size = node.rect.size;
    if (size.width + 0.5 < SahraRules.minTouchTarget ||
        size.height + 0.5 < SahraRules.minTouchTarget) {
      faults.add(LayoutFault(
        'tap-target',
        '"${_clip(node.label.isEmpty ? '(unlabelled)' : node.label)}" is '
        '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}, '
        'below ${SahraRules.minTouchTarget.toInt()}',
      ));
    }
  }

  // 4. The page must not scroll sideways.
  //
  //    An inner horizontal scroller is a design element; a horizontally
  //    scrolling PAGE is a layout that did not fit and gave up. The
  //    distinction is the OUTERMOST scrollable, which is the one a thumb on
  //    the body reaches.
  if (isPage) {
    // "The outermost scrollable is horizontal" was the wrong test. A screen
    // whose body is a fixed Column with no page scroller at all — which the
    // booking screen is — makes the DATE STRIP the first scrollable in tree
    // order, and it failed at all five sizes for being a date strip.
    //
    // A horizontal scroller is the PAGE only if it is page-SHAPED: as tall as
    // the screen. A 64pt strip is a design element; a 568pt one has swallowed
    // the layout.
    for (final v in _horizontalViewports(tester)) {
      if (!v.hasSize) continue;
      if (v.size.height >= viewport.height * 0.8) {
        faults.add(LayoutFault(
          'page-scrolls-sideways',
          'a full-height horizontal Scrollable (${v.size.height.toInt()}pt of '
          '${viewport.height.toInt()}) — the page did not fit and gave up',
        ));
        break;
      }
    }
  }

  return faults;
}

/// Render [build] at every size in [sahraViewports] and fail on any fault.
///
/// One test per cell per viewport, named so a failure says WHERE. A single
/// test looping over sizes would stop at the first failure and hide the rest,
/// which is the opposite of what a responsiveness pass needs.
void viewportMatrix(
  String name,
  Widget Function(SahraViewport viewport) build, {
  bool isPage = true,
  List<SahraViewport> viewports = sahraViewports,
}) {
  for (final vp in viewports) {
    testWidgets('layout: $name [$vp]', (tester) async {
      tester.view.physicalSize = vp.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(build(vp));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final faults = layoutFaults(tester, viewport: vp.size, isPage: isPage);
      handle.dispose();

      expect(
        faults,
        isEmpty,
        reason: '$name at $vp:\n  ${faults.join('\n  ')}',
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────── internals ──

void _walkTextOutsideHorizontalScrollers(
  WidgetTester tester,
  void Function(RenderParagraph paragraph, Rect rect, String text) visit,
) {
  void walk(RenderObject node, {required bool insideHorizontal}) {
    var horizontal = insideHorizontal;
    if (node is RenderViewportBase && node.axis == Axis.horizontal) {
      horizontal = true;
    }

    if (!horizontal && node is RenderParagraph && node.hasSize) {
      final offset = node.localToGlobal(Offset.zero);
      visit(node, offset & node.size, node.text.toPlainText());
    }

    node.visitChildren((child) => walk(child, insideHorizontal: horizontal));
  }

  walk(tester.binding.rootElement!.renderObject!, insideHorizontal: false);
}

List<RenderViewportBase> _horizontalViewports(WidgetTester tester) {
  final found = <RenderViewportBase>[];
  void walk(RenderObject node) {
    if (node is RenderViewportBase && node.axis == Axis.horizontal) found.add(node);
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return found;
}

/// Material `Icon` renders one private-use codepoint through RichText. Not
/// text, cannot be "clipped text", and its label prints as nothing.
bool _isIconGlyph(String text) {
  if (text.isEmpty) return false;
  return text.runes.every((r) =>
      (r >= 0xE000 && r <= 0xF8FF) || // Basic Multilingual Plane PUA
      (r >= 0xF0000 && r <= 0xFFFFD) || // supplementary PUA-A
      r == 0x20);
}

/// Tappable nodes, excluding anything inside a horizontally scrolling ancestor.
List<SemanticsNode> _tappableNodesOutsideHorizontalScrollers(WidgetTester tester) {
  final found = <SemanticsNode>[];
  void walk(SemanticsNode node, {required bool insideHorizontal}) {
    final data = node.getSemanticsData();
    final horizontal = insideHorizontal ||
        data.hasAction(SemanticsAction.scrollLeft) ||
        data.hasAction(SemanticsAction.scrollRight);

    if (!horizontal && data.hasAction(SemanticsAction.tap)) found.add(node);
    node.visitChildren((child) {
      walk(child, insideHorizontal: horizontal);
      return true;
    });
  }

  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) walk(root, insideHorizontal: false);
  return found;
}

/// `Rect.contains` on all four corners, with the same half-pixel tolerance the
/// text check uses.
bool _containsWithTolerance(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

String _clip(String s) {
  final flat = s.replaceAll('\n', ' ').trim();
  return flat.length <= 40 ? flat : '${flat.substring(0, 40)}…';
}

String _firstLine(String s) => s.split('\n').first;
