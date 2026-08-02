import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahra_design_system/sahra_design_system.dart';

import '../../localization/generated/app_localizations.dart';
import '../../routes/routes.dart';
import '../providers/session_providers.dart';

/// The bottom navigation, wrapped around every top-level destination.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY BOTTOM NAVIGATION AND NOT A HEADER ACCOUNT BUTTON
/// ─────────────────────────────────────────────────────────────────────────
///
/// The design package already decided this. `SahraTabBar` is one of the
/// sixteen components, `TabBar.d.ts` describes it as "the bottom navigation",
/// and `docs/design/ui_kits/app/index.html` — the reference shell — renders it
/// under every screen in the app. A header account button would leave a built
/// component unused and would contradict the only navigation the references
/// actually draw.
///
/// WHERE THIS DEPARTS FROM THE REFERENCE, and it does, in two ways:
///
///  1. **The reference's four tabs are Discover / Search / Saved / Account.**
///     Saved has no endpoint (C-2.6 is unbuilt), so that tab would fail on
///     tap — the waitlist-bell rule. And Discover and Search are one screen
///     here: the discovery surface we built IS the search screen, so splitting
///     it would give two tabs onto the same widget.
///  2. **Bookings is promoted to a top-level tab.** In the reference it is a
///     row inside `ProfileScreen.jsx`, two taps deep. It is the screen a diner
///     opens standing at a restaurant door, and the destination they are sent
///     to right after booking. Two taps is the wrong cost for that.
///
/// Reported rather than done quietly.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;

  /// The current route, so the tab bar reflects where the router actually is
  /// rather than a separate index that can disagree with it.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // WATCHED, not read, and not for the value — nothing here draws from it.
    // Watching is what CREATES the provider on the first frame, which is what
    // starts the restore from secure storage. Without this the restore begins
    // only when somebody asks, and the first asker is a diner tapping a tab.
    ref.watch(currentSessionProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: SahraTabBar(
        activeId: _activeTab(location),
        items: <SahraTab>[
          SahraTab(id: 'discover', label: l10n.tabDiscover, icon: 'compass'),
          SahraTab(id: 'bookings', label: l10n.tabBookings, icon: 'calendar'),
          SahraTab(id: 'account', label: l10n.tabAccount, icon: 'user'),
        ],
        onChanged: (id) => _open(context, ref, id),
      ),
    );
  }

  /// DERIVED FROM THE URL, never stored. An index held beside the router is an
  /// index that disagrees with it the first time anything navigates without
  /// going through a tab — a deep link, a back button, the post-booking `go`.
  static String _activeTab(String location) {
    if (location.startsWith(BookingsRoute.path)) return 'bookings';
    if (location.startsWith(AccountRoute.path)) return 'account';
    return 'discover';
  }

  /// Tapping a tab that needs an account.
  ///
  /// THE SAME ROUND TRIP AS THE PENDING SLOT, and deliberately the same shape:
  /// sign-in is PUSHED over what you were looking at, it answers `true` or
  /// `false`, and only `true` completes the thing you asked for.
  ///
  ///   - signed out, taps Bookings → sign-in → success → **Bookings**
  ///   - signed out, taps Bookings → sign-in → cancelled → **stays where it
  ///     was**, because the mirror of "no hold attempted" is "no navigation
  ///     performed". Landing them on a signed-out Bookings screen after they
  ///     just declined to sign in would be asking twice.
  ///
  /// Browsing is NOT gated. Discover is reachable signed out, always, and
  /// nothing about launch touches this — authentication is demanded at the
  /// hold and here, at the two destinations that are meaningless without an
  /// account.
  Future<void> _open(BuildContext context, WidgetRef ref, String id) async {
    if (id == 'discover') {
      const SearchRoute().go(context);
      return;
    }

    final destination = id == 'bookings' ? BookingsRoute.path : AccountRoute.path;

    // Wait for storage before deciding. A returning diner must not be asked to
    // sign in because a keystore read had not come back yet.
    await ref.read(currentSessionProvider.notifier).ready;
    if (!context.mounted) return;

    if (ref.read(currentSessionProvider) != null) {
      context.go(destination);
      return;
    }

    final signedIn = await const SignInRoute().push(context);
    if (!context.mounted || signedIn != true) return;
    context.go(destination);
  }
}
