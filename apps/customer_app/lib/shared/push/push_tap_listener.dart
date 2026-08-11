import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'push_registration.dart';
import 'push_taps.dart';

/// Routes a tapped notification to the thing it is about.
///
/// Sits inside `MaterialApp.router`'s `builder:`, which is the only place that
/// is BOTH under the router — so `context.go` resolves — and above every
/// screen, so the destination does not depend on where the diner happened to
/// be.
///
/// ── BOTH CHANNELS, AND THE COLD ONE FIRST ────────────────────────────────
///
/// `getInitialMessage()` is checked in `initState` because by then the tap has
/// already happened: the process was launched BY it. `onMessageOpenedApp` is a
/// stream and only ever fires while the app is alive. Wiring the stream alone
/// gives an app that routes perfectly in every warm test and does nothing for
/// the diner whose phone killed it overnight — who is exactly the diner a
/// 24-hour reminder exists for.
///
/// ── AND IT NEVER STEALS A FRAME IT WAS NOT GIVEN ─────────────────────────
///
/// The initial tap is consumed ONCE. A second read returns null from both the
/// real implementation and the fake, so a rebuild cannot re-navigate a diner
/// who has since walked somewhere else.
class PushTapListener extends ConsumerStatefulWidget {
  const PushTapListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushTapListener> createState() => _PushTapListenerState();
}

class _PushTapListenerState extends ConsumerState<PushTapListener> {
  StreamSubscription<Map<String, String>>? _sub;

  @override
  void initState() {
    super.initState();
    final PushTaps taps = ref.read(pushTapsProvider);
    _sub = taps.taps().listen(_handle);
    // After the first frame: `context.go` needs a router in the tree, and
    // initState runs before this widget is mounted into one.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final Map<String, String>? launch = await taps.initialTap();
      if (launch != null) _handle(launch);

      // ── ONCE PER LAUNCH: RE-REGISTER A TOKEN WE MAY NOT HAVE ──────────────
      //
      // `syncExistingToken` is a no-op for a signed-out diner and for one
      // whose token is already registered, so this is cheap. It exists here
      // because THIS IS THE ONLY WIDGET THAT RUNS EXACTLY ONCE PER LAUNCH
      // above every screen — and because its own docblock claimed a launch
      // caller that did not exist, which is what made a transient FCM failure
      // permanent for an install.
      //
      // Unawaited on purpose: it retries with backoff for up to two minutes
      // and must never hold up the first frame.
      unawaited(ref.read(pushRegistrarProvider.notifier).syncExistingToken());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handle(Map<String, String> data) {
    if (!mounted) return;
    // A payload naming no destination still goes somewhere USEFUL: the centre
    // lists every notification, so it is always a better answer than leaving
    // the diner wherever the app happened to be. Never a dead end.
    GoRouter.of(context).push(routeForPush(data) ?? '/notifications');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
