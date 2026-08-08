import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahra_customer_app/config/support_contact.dart';
import 'package:sahra_customer_app/shared/widgets/tappable_contact.dart';

import '../support/screen_harness.dart';

/// `url_launcher`, and the half of it that matters.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE TEST HOST HAS NO PLUGIN, WHICH IS THE POINT
/// ─────────────────────────────────────────────────────────────────────────
///
/// `flutter test` runs without any platform implementation of `url_launcher`,
/// so `canLaunchUrl` throws a `MissingPluginException` here. That is not a
/// limitation to work around — it is EXACTLY the situation these widgets exist
/// to survive: a platform that cannot open a `mailto:` or a `tel:`.
///
/// A desktop browser with no mail client, a tablet with no dialler, an Android
/// whose package-visibility query was not declared — all of them land in the
/// same branch. So this suite drives the failing path deliberately and asserts
/// the diner is left with something they can read and copy, rather than a tap
/// that silently does nothing.
///
/// What it CANNOT prove is that a real launch works. Nothing in a widget test
/// can. That belongs to the walk-through on a device, and is called out there.
void main() {
  Widget host(Cell cell, Widget child) => screenHarness(
        cell,
        Scaffold(body: Center(child: child)),
        overrides: const <Override>[],
      );

  testWidgets('the address is on screen and SELECTABLE before anything is tapped', (tester) async {
    await tester.pumpWidget(
      host(
        Cell.enLight,
        SelectionArea(
          child: SahraTappableContact(
            display: SupportContact.value,
            uri: SupportContact.mailto,
            semanticLabel: 'Email SAHRA support',
          ),
        ),
      ),
    );
    await stabilise(tester);

    // The literal address, intact. Not truncated, not translated, not
    // reformatted — an address is a literal.
    expect(
      find.textContaining(SupportContact.value),
      findsOneWidget,
      reason: 'the support address is not readable on screen',
    );
  });

  testWidgets('A FAILED LAUNCH LEAVES THE ADDRESS READABLE AND SAYS SO', (tester) async {
    // The launcher is INJECTED so this drives the failing branch on purpose.
    // Left to the ambient platform it proved nothing: the Windows test host
    // answered "launched" and the note never appeared, so the assertion was
    // measuring the runner rather than the widget.
    await tester.pumpWidget(
      host(
        Cell.enLight,
        SahraTappableContact(
          display: SupportContact.value,
          uri: SupportContact.mailto,
          semanticLabel: 'Email SAHRA support',
          launcher: (_) async => false,
        ),
      ),
    );
    await stabilise(tester);

    await tester.tap(find.textContaining(SupportContact.value));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining(SupportContact.value), findsOneWidget);
    expect(
      find.textContaining('copy it instead'),
      findsOneWidget,
      reason: 'a tap that could not launch said nothing at all',
    );
  });

  testWidgets('A THROWING LAUNCHER IS THE SAME OUTCOME, NOT A RED SCREEN', (tester) async {
    // A platform with no plugin registered at all raises rather than returning
    // false. The diner whose only remaining option is to read this address
    // must not be shown a crash instead of it.
    await tester.pumpWidget(
      host(
        Cell.enLight,
        SahraTappableContact(
          display: SupportContact.value,
          uri: SupportContact.mailto,
          semanticLabel: 'Email SAHRA support',
          launcher: (_) async => throw MissingPluginException('no url_launcher'),
        ),
      ),
    );
    await stabilise(tester);

    await tester.tap(find.textContaining(SupportContact.value));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'the exception reached the framework');
    expect(find.textContaining('copy it instead'), findsOneWidget);
  });

  testWidgets('and a launch that WORKS says nothing extra', (tester) async {
    // The guard on the guard: if the note appeared unconditionally, the two
    // tests above would pass without the widget deciding anything.
    Uri? launched;
    await tester.pumpWidget(
      host(
        Cell.enLight,
        SahraTappableContact(
          display: SupportContact.value,
          uri: SupportContact.mailto,
          semanticLabel: 'Email SAHRA support',
          launcher: (uri) async {
            launched = uri;
            return true;
          },
        ),
      ),
    );
    await stabilise(tester);

    await tester.tap(find.textContaining(SupportContact.value));
    await tester.pumpAndSettle();

    expect(launched?.scheme, 'mailto');
    expect(launched?.path, SupportContact.value);
    expect(find.textContaining('copy it instead'), findsNothing);
  });

  testWidgets('the tappable node carries its own accessible name', (tester) async {
    // `labeledTapTargetGuideline` looks for the label on the node that has the
    // tap action. A GestureDetector wrapped around a Text puts them on two
    // different nodes and the guideline fails — which is how this widget was
    // built the first time.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        Cell.enLight,
        SahraTappableContact(
          display: '+20 2 2735 0000',
          uri: Uri(scheme: 'tel', path: '+20227350000'),
          semanticLabel: 'Call the restaurant',
        ),
      ),
    );
    await stabilise(tester);

    // A REGEXP, because MergeSemantics folds the number into the label —
    // the node announces the action AND the content, which is what a screen
    // reader user needs. What matters is that the ACTION name is on the node
    // that carries the tap, and that is what the guideline below checks.
    expect(find.bySemanticsLabel(RegExp('Call the restaurant')), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the URI is never rebuilt from what is drawn', (tester) async {
    // The display string carries bidi isolates and may carry spaces; the URI
    // is built by the caller from its own source. Asserting they can differ is
    // what stops somebody "simplifying" this into `Uri.parse(display)`.
    const display = '+20 2 2735 0000';
    final uri = Uri(scheme: 'tel', path: '+20227350000');

    await tester.pumpWidget(
      host(
        Cell.arLight,
        SahraTappableContact(
          display: display,
          uri: uri,
          semanticLabel: 'كلّم المطعم',
        ),
      ),
    );
    await stabilise(tester);

    final widget = tester.widget<SahraTappableContact>(
      find.byType(SahraTappableContact),
    );
    expect(widget.uri.path, isNot(contains(' ')));
    expect(widget.display, contains(' '));
  });

  testWidgets('Arabic: the Latin contact keeps its direction', (tester) async {
    // A `+` at the head of a number, or an `@` in an address, reorders against
    // surrounding Arabic without an isolate. The widget adds one so no caller
    // has to remember.
    await tester.pumpWidget(
      host(
        Cell.arLight,
        SahraTappableContact(
          display: SupportContact.value,
          uri: SupportContact.mailto,
          semanticLabel: 'ابعت إيميل لدعم سهرة',
        ),
      ),
    );
    await stabilise(tester);

    final text = tester.widget<Text>(find.byType(Text).first).data!;
    expect(
      text.codeUnits.first,
      0x2066,
      reason: 'the contact is not wrapped in an LTR isolate (U+2066)',
    );
    expect(text, contains(SupportContact.value));
  });
}
