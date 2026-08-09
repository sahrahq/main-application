import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../../localization/generated/app_localizations.dart';
import '../../../routes/routes.dart';
import 'onboarding_seen.dart';

/// `docs/design/ui_kits/app/Onboarding.jsx` — three slides, once.
///
/// ── WHAT THIS IS FOR, AND WHAT IT IS NOT ─────────────────────────────────
///
/// It is not a tutorial. Nobody reads a tutorial for a restaurant app. It is
/// thirty seconds of saying what SAHRA is, to somebody who has just installed
/// something on a friend's recommendation and does not yet know whether it is
/// a review site, a delivery app, or a booking one — a distinction the home
/// screen alone cannot make in the two seconds it gets.
///
/// ── SEEN ONCE, AND SKIPPABLE FROM THE FIRST SLIDE ────────────────────────
///
/// "Already with us? Sign in" is on every slide, per the reference. A returning
/// diner reinstalling the app must not have to page through three panels about
/// a product they already use.
///
/// The photo well is `SahraPhoto` with no image — the reference's own dark
/// gradient and mashrabiya. There is no onboarding photography and inventing
/// some would mean shipping three stock images of restaurants that are not on
/// the platform.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = Theme.of(context).sahra;
    final text = Theme.of(context).textTheme;

    final slides = <({String kicker, String title, String body})>[
      (kicker: l10n.onboardKicker1, title: l10n.onboardTitle1, body: l10n.onboardBody1),
      (kicker: l10n.onboardKicker2, title: l10n.onboardTitle2, body: l10n.onboardBody2),
      (kicker: l10n.onboardKicker3, title: l10n.onboardTitle3, body: l10n.onboardBody3),
    ];
    final slide = slides[_index];
    final last = _index == slides.length - 1;

    return Scaffold(
      body: SahraPageWidth(
        child: Column(
          children: <Widget>[
            // THE PHOTO YIELDS FIRST. `Flexible` with a small minimum rather
            // than `Expanded`: at 320x568 and 200% text the card alone is
            // taller than the screen, and a photo that insisted on its share
            // pushed it off the bottom — a silent overflow in a release build.
            // The card is the content; the photo is the mood.
            const Flexible(child: SahraPhoto(height: double.infinity)),
            // THE CARD IS FLEXIBLE TOO, and that is what makes the scroll view
            // inside it work. Unbounded, a `SingleChildScrollView` takes the
            // height its child asks for and overflows the Column — 91px at
            // 320x568 and 200% text. Bounded, it scrolls, which is the whole
            // point of putting one there.
            Flexible(
              flex: 3,
              child: _Card(
                // The card overlaps the photo by 28, as the reference draws it.
                slide: slide,
                index: _index,
                count: slides.length,
                onNext: () => last ? _finish(context) : setState(() => _index++),
                onDot: (i) => setState(() => _index = i),
                nextLabel: last ? l10n.onboardStart : l10n.onboardNext,
                signInPrompt: l10n.onboardHaveAccount,
                signInLabel: l10n.onboardSignIn,
                onSignIn: () => _finish(context, toSignIn: true),
                s: s,
                text: text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mark it seen, then leave. **In that order**, and awaited: a diner who
  /// backgrounds the app during the transition must not come back to slide one.
  Future<void> _finish(BuildContext context, {bool toSignIn = false}) async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!context.mounted) return;

    if (toSignIn) {
      await const SignInRoute().push(context);
      if (!context.mounted) return;
    }
    const DiscoverRoute().go(context);
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.slide,
    required this.index,
    required this.count,
    required this.onNext,
    required this.onDot,
    required this.nextLabel,
    required this.signInPrompt,
    required this.signInLabel,
    required this.onSignIn,
    required this.s,
    required this.text,
  });

  final ({String kicker, String title, String body}) slide;
  final int index;
  final int count;
  final VoidCallback onNext;
  final ValueChanged<int> onDot;
  final String nextLabel;
  final String signInPrompt;
  final String signInLabel;
  final VoidCallback onSignIn;
  final SahraSemantics s;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        decoration: BoxDecoration(
          color: s.surfaceCard,
          // The reference's 24 is `radius-xl`; using the token rather than the
          // number is what keeps the corner in step if the scale ever moves.
          borderRadius: SahraRadius.only(
            topStart: SahraRadius.xl,
            topEnd: SahraRadius.xl,
          ),
        ),
        padding: SahraSpace.inset(
          start: SahraSpace.s5,
          end: SahraSpace.s5,
          top: SahraSpace.s6,
          bottom: SahraSpace.s5,
        ),
        child: SafeArea(
          top: false,
          // SCROLLS AT LARGE TEXT. Three lines of body copy at 200% is taller
          // than a 568pt phone with a button under it, and the people running
          // large text are exactly the ones this screen has to explain itself
          // to.
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  slide.kicker,
                  style: text.labelSmall?.copyWith(
                    color: s.accentOnSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SahraSpace.s2),
                Text(slide.title, style: text.displaySmall?.copyWith(color: s.textBody)),
                const SizedBox(height: SahraSpace.s2),
                Text(slide.body, style: text.bodyLarge?.copyWith(color: s.textSoft)),
                const SizedBox(height: SahraSpace.s5),

                // The dots are TAPPABLE, as the reference has them, and each one
                // carries a real 44dp target around a 7pt dot.
                Row(
                  children: <Widget>[
                    for (var i = 0; i < count; i++)
                      Semantics(
                        button: true,
                        selected: i == index,
                        // "Slide 2 of 3", not "2". A screen reader announcing a
                        // bare number tells somebody nothing about what they are
                        // on or how much is left.
                        label: l10n.onboardSlideOf(i + 1, count),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onDot(i),
                          // FULL 44 IN BOTH AXES. Halving the width to keep the
                          // dots visually close failed the tap-target guideline
                          // at 24x48 — and a pagination dot is exactly the
                          // control somebody with an unsteady hand misses. Three
                          // at 44 is 132pt, which fits the narrowest phone in
                          // the matrix with room to spare.
                          child: SizedBox(
                            height: SahraRules.minTouchTarget,
                            width: SahraRules.minTouchTarget,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: i == index ? 22 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: i == index ? s.accent : s.line,
                                  // A 7pt dot: `pill` is the honest name for
                                  // "fully rounded", and it clamps correctly as
                                  // the dot widens to 22 for the active one.
                                  borderRadius: BorderRadius.circular(SahraRadius.pill),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SahraSpace.s3),
                SizedBox(
                  width: double.infinity,
                  child: SahraButton(label: nextLabel, onPressed: onNext),
                ),
                const SizedBox(height: SahraSpace.s4),
                Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        signInPrompt,
                        style: text.bodyMedium?.copyWith(color: s.textSoft),
                      ),
                      const SizedBox(width: SahraSpace.s1),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onSignIn,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: SahraRules.minTouchTarget,
                          ),
                          child: Align(
                            child: Text(
                              signInLabel,
                              style: text.bodyMedium?.copyWith(
                                color: s.accentOnSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
