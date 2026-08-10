import 'package:flutter/material.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../config/env/env.dart';

/// A phone-sized frame, centred on the page, for `flutter run -d chrome`.
///
/// WHY THIS EXISTS. The browser is a preview harness for a phone-first app.
/// Reviewing a 375-point screen stretched across a 1440-point window tells you
/// almost nothing true: text sets differently, the sticky footer sits a foot
/// from the content it confirms, and a layout that is fine on a phone looks
/// broken while a layout that is broken looks fine.
///
/// The frame is COSMETIC. It makes what you see match what ships; it does not
/// make the app correct at any size. That guarantee comes from
/// `test/layout/viewport_matrix_test.dart`, which renders every screen at six
/// real device sizes including 320×568 at 200% text, and from
/// [SahraPageWidth], which caps content at 560 whether or not this frame is
/// on. **A green frame is not evidence. The overflow guard is.**
///
/// The dimensions are not invented: `docs/design/ui_kits/app/index.html`
/// renders every reference screen at exactly `width: 375, height: 812,
/// borderRadius: 40` on a `#171009` page, with a hairline border and a deep
/// shadow. Those values are reproduced rather than approximated, so a Flutter
/// screenshot and a reference screenshot can be put side by side.
///
/// OFF for a real build, and off for deliberate wide-layout testing:
///
///     flutter run -d chrome --dart-define-from-file=env/web.json
///     flutter run -d chrome --dart-define-from-file=env/web.json --dart-define=DEVICE_FRAME=false
class SahraDeviceFrame extends StatelessWidget {
  const SahraDeviceFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Env.deviceFrame) return child;

    final media = MediaQuery.of(context);
    // Never frame a window that is already phone-sized: on a narrow browser,
    // or a real device that somehow reached this code, the frame would just
    // steal space from the thing being previewed.
    if (media.size.width < SahraLayout.designCanvas.width + _margin * 2 ||
        media.size.height < SahraLayout.designCanvas.height + _margin * 2) {
      return child;
    }

    final dark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      // The reference's own page colour, so the surround does not read as part
      // of the app.
      color: _pageBackdrop,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_cornerRadius),
          child: SizedBox(
            width: SahraLayout.designCanvas.width,
            height: SahraLayout.designCanvas.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_cornerRadius),
                border: Border.all(
                  color: dark ? _borderNight : Theme.of(context).sahra.line,
                ),
              ),
              // The MediaQuery INSIDE the frame reports the frame's size, not
              // the window's. Without this a screen asking how much room it
              // has would be told 1440 while being painted into 375 — which is
              // precisely the misleading preview this widget exists to end.
              child: MediaQuery(
                data: media.copyWith(size: SahraLayout.designCanvas),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `docs/design/ui_kits/app/index.html`: `borderRadius: 40`.
const double _cornerRadius = 40;

/// Breathing room before the frame is considered worth drawing.
const double _margin = 24;

// design-exempt: the REFERENCE PREVIEW SHELL's own values, not product design
// tokens. `#171009` is the page the design package renders its phone frame on
// and `#413024` its dark border; both live in index.html, neither is in
// tokens.json, and neither is ever seen by a user — this widget is off in
// every real build.
const Color _pageBackdrop = Color(0xFF171009);
// design-exempt: as above.
const Color _borderNight = Color(0xFF413024);
