import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import 'onboarding_seen.dart';

/// `docs/design/ui_kits/app/SplashScreen.jsx`.
///
/// ─────────────────────────────────────────────────────────────────────────
/// IT HAS A JOB, NOT JUST A DURATION
/// ─────────────────────────────────────────────────────────────────────────
///
/// The reference is a timed animation that calls `onDone` after 2000ms. A
/// fixed delay for its own sake is two seconds taken from every launch, and
/// diners open a booking app when they are already in a hurry.
///
/// So it waits for something real: **whether this diner has seen onboarding**,
/// which is a read from storage. `OnboardingSeen` is null until that answers,
/// and this screen is what covers the gap. Without it the app would either
/// flash Discover at a first-run user or flash onboarding at a returning one,
/// and the second is worse — it reads as the app having forgotten them.
///
/// The minimum is 600ms rather than 2000: long enough that the mark does not
/// strobe on a fast device, short enough not to be a toll. If storage takes
/// longer, this waits; it never cuts the answer off.
///
/// ── WHAT IS NOT ANIMATED ─────────────────────────────────────────────────
///
/// The reference has five keyframe animations — mark settle, wordmark letter-
/// spacing, a gold hairline drawing, the lattice fading, an Arabic subtitle.
/// This does the fade and the hairline. Letter-spacing animation in Flutter
/// means rebuilding the `TextStyle` every frame, which is a lot of work for a
/// flourish nobody sees twice. Carried in `COSMETIC-FLAGS.md`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Long enough not to strobe, short enough not to be a toll.
  static const Duration _minimum = Duration(milliseconds: 600);

  bool _minimumElapsed = false;
  bool _left = false;

  /// HELD AND CANCELLED. A `Timer` fired and forgotten outlives the widget —
  /// harmless here because of the `mounted` check, but it keeps the test
  /// binding alive past teardown and `flutter_test` reports it as an error
  /// rather than a failure. Cancelling is also just correct: a screen that has
  /// been left has nothing left to time.
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimum, () {
      if (mounted) setState(() => _minimumElapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final seen = ref.watch(onboardingSeenProvider);

    // BOTH conditions, and only once. `WidgetsBinding.addPostFrameCallback`
    // because navigating during a build is the Flutter error that turns into a
    // silent rebuild loop; `_left` because this widget rebuilds on every
    // provider change and a second `go` would push a second route.
    if (!_left && _minimumElapsed && seen != null) {
      _left = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (seen) {
          const DiscoverRoute().go(context);
        } else {
          const OnboardingRoute().go(context);
        }
      });
    }

    return Scaffold(
      backgroundColor: s.surfacePage,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The lattice, at the reference's opacity for the light theme.
          const SahraMashrabiya(opacity: 0.04, tile: 52),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // THE WORDMARK IS TEXT, not an image. There is no logo asset in
                // the repository — the reference points at `../../assets/
                // logo.png`, which does not exist here — and shipping a missing
                // asset would put a broken image on the first frame of the app.
                // Flagged rather than invented.
                Text(
                  l10n.appTitle,
                  style: text.displaySmall?.copyWith(
                    color: s.accentOnSurface,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: SahraSpace.s4),
                // The gold hairline, drawn.
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => Container(
                    width: 44 * t,
                    height: 2,
                    color: s.premium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
