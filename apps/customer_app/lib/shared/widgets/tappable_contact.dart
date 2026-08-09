import 'package:flutter/material.dart';
import 'package:sahra_design_system/sahra_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../localization/generated/app_localizations.dart';

/// A phone number or an email address that opens the right app when tapped —
/// and stays readable and copyable when nothing can open it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE FALLBACK IS THE FEATURE, NOT THE CONSOLATION
/// ─────────────────────────────────────────────────────────────────────────
///
/// These two strings are load-bearing in a way most UI text is not. The
/// support address is the only exit from the 15-minute verify lock and from an
/// OTP that never arrives (see `support_contact.dart`); the venue's number is
/// the answer to everything the modify and cancel buttons do not cover. If
/// either of them is a tap that silently does nothing — a desktop browser with
/// no mail client, a tablet with no dialler, an Android without a default
/// handler — the diner is at the same dead end with one more reason to think
/// the app is broken.
///
/// So the text is SELECTABLE first and tappable second, and both are always
/// true. That ordering is deliberate: `SelectionArea` on the enclosing screen
/// makes the string copyable whether or not the launch works, and the tap is
/// added on top. Nothing here can produce a state where the address is
/// unreadable.
///
/// ── AND WHY IT IS ONE WIDGET FOR BOTH SCHEMES ────────────────────────────
///
/// `mailto:` and `tel:` are the same capability wearing two schemes, approved
/// as one decision (doc 08 §5). One widget means the fallback behaviour, the
/// bidi isolation and the failure handling are written once — rather than the
/// phone number getting a slightly different, slightly worse version of them
/// six weeks later.
/// Opens [uri], answering whether it worked.
///
/// A SEAM, and it earns its keep. `launchUrl` is a top-level function, so a
/// widget that calls it directly cannot be told to fail — and the failing path
/// is the one that matters here. Without this the fallback could only be
/// tested by whatever the host machine happened to do, which on a Windows test
/// runner turned out to be "succeed", quietly proving nothing.
typedef ContactLauncher = Future<bool> Function(Uri uri);

/// The default, exported so a caller that is not a `SahraTappableContact` can
/// still go through the same door.
///
/// The menu PDF is such a caller: it is a BUTTON, not a line of readable text,
/// so the widget above is the wrong shape for it — but the launch itself must
/// behave identically, including `canLaunchUrl` first and a false rather than
/// a thrown exception. It shipped calling `launchUrl` directly, which is how a
/// second, slightly worse launch path starts.
const ContactLauncher kDefaultLauncher = _defaultLauncher;

Future<bool> _defaultLauncher(Uri uri) async {
  // `canLaunchUrl` first, and the result is acted on rather than logged. On
  // Android 11+ this needs the `<queries>` entries in the manifest or it
  // returns false even where a handler exists; both are declared there.
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri);
}

class SahraTappableContact extends StatefulWidget {
  const SahraTappableContact({
    required this.display,
    required this.uri,
    required this.semanticLabel,
    this.style,
    this.textAlign,
    this.launcher = _defaultLauncher,
    super.key,
  });

  /// What the diner reads. Latin text, usually inside Arabic copy, so it is
  /// bidi-isolated here rather than at every call site — without the isolate
  /// the `+` on a phone number lands on the wrong end and `@` reorders an
  /// address.
  final String display;

  /// `mailto:` or `tel:`. Built by the caller from its own single source of
  /// truth, never assembled from [display].
  final Uri uri;

  /// What a screen reader announces — "email SAHRA support", not the raw
  /// address read character by character.
  final String semanticLabel;

  final TextStyle? style;
  final TextAlign? textAlign;

  /// Overridden only in tests. See [ContactLauncher].
  final ContactLauncher launcher;

  @override
  State<SahraTappableContact> createState() => _SahraTappableContactState();
}

class _SahraTappableContactState extends State<SahraTappableContact> {
  /// Set when a launch was attempted and the platform could not do it.
  ///
  /// SHOWN, not swallowed. A tap that does nothing and says nothing teaches
  /// the diner the app is broken; a tap that says "copy this instead" tells
  /// them what to do with the thing already on their screen.
  bool _cannotLaunch = false;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).sahra;
    final style = widget.style ?? Theme.of(context).textTheme.bodySmall;

    return Column(
      crossAxisAlignment: widget.textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        // MergeSemantics + an explicit label, so the tappable node carries a
        // name. `labeledTapTargetGuideline` looks for the label on the node
        // that has the tap action, and a bare GestureDetector around a Text
        // puts them on two different nodes.
        MergeSemantics(
          child: Semantics(
            link: true,
            label: widget.semanticLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _launch,
              child: ConstrainedBox(
                // 44dp, like every other interactive element. The text itself
                // is one line of bodySmall and would otherwise publish a
                // ~16pt-tall target.
                constraints: const BoxConstraints(minHeight: SahraRules.minTouchTarget),
                child: Align(
                  alignment: widget.textAlign == TextAlign.center
                      ? Alignment.center
                      : AlignmentDirectional.centerStart,
                  child: Text(
                    ltrRun(widget.display),
                    textAlign: widget.textAlign,
                    style: style?.copyWith(
                      color: s.accentOnSurface,
                      decoration: TextDecoration.underline,
                      decorationColor: s.accentOnSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_cannotLaunch)
          Padding(
            padding: SahraSpace.inset(top: SahraSpace.s1),
            child: Text(
              AppLocalizations.of(context).contactCannotOpen,
              textAlign: widget.textAlign,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.textFaint),
            ),
          ),
      ],
    );
  }

  Future<void> _launch() async {
    var ok = false;
    try {
      ok = await widget.launcher(widget.uri);
    } catch (_) {
      // A platform with no url_launcher implementation at all — a web build
      // without the plugin registered, a desktop host. Same outcome as "no
      // handler", which the note below already covers. Swallowed rather than
      // rethrown because a red screen is a worse answer than a copyable
      // address, and this address is somebody's only way out.
      ok = false;
    }

    if (!mounted) return;
    setState(() => _cannotLaunch = !ok);
  }
}
