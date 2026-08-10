/// The composition root (doc 07 §2 `shared/providers/`).
///
/// THIS is where `data/` is allowed to meet `presentation/`, and the only
/// place. `layers_test.dart` fails the build when anything under
/// `presentation/` imports `data/`, so a screen watching
/// [restaurantRepository] sees the ABSTRACT type and could not name the
/// implementation if it wanted to. Overriding one line in a test swaps the
/// whole stack for a fake with no socket.
///
/// Riverpod 2 WITH CODEGEN throughout (doc 07 §3), including the DI providers
/// — two ways of declaring a provider in one codebase is the "second pattern
/// creeping in" that the architecture decision exists to prevent.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sahra_api_client/sahra_api_client.dart';

import '../widgets/tappable_contact.dart';

import '../../config/env/env.dart';
import '../../core/network/dio_transport.dart';
import '../../features/reservations/data/reservation_repository_impl.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../features/restaurants/data/restaurant_repository_impl.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/restaurants/domain/restaurant_repository.dart';
import '../../features/saved/data/saved_repository_impl.dart';
import '../../features/saved/domain/saved_repository.dart';
import '../../features/notifications/data/notifications_repository_impl.dart';
import '../../features/notifications/domain/notifications_repository.dart';
import 'session_providers.dart';

part 'app_providers.g.dart';

/// The active locale, as a language code.
///
/// A provider rather than a `BuildContext` read, because the transport and the
/// repositories both need it and neither has a context. Kept in step with the
/// widget tree by [LocaleSync], so there is exactly one answer in the app at
/// any moment — an app whose UI renders Arabic while asking the API for
/// English is a bug nobody notices until a venue name comes back wrong.
@Riverpod(keepAlive: true)
class LocaleCode extends _$LocaleCode {
  @override
  String build() => 'ar';

  void set(String code) => state = code;
}

@Riverpod(keepAlive: true)
SahraTransport transport(Ref ref) => DioTransport(
      baseUrl: Env.apiBaseUrl,
      localeCode: () => ref.read(localeCodeProvider),
      // `read`, not `watch`: watching would rebuild the transport — and every
      // repository above it — on sign-in, discarding in-flight requests. The
      // closure sees the current value either way.
      accessToken: () => ref.read(currentSessionProvider)?.accessToken,
    );

@Riverpod(keepAlive: true)
SahraApi api(Ref ref) => SahraApi(ref.watch(transportProvider));

/// How the app hands a URI to the platform.
///
/// A PROVIDER RATHER THAN A CONSTRUCTOR PARAMETER, unlike
/// `SahraTappableContact.launcher`, and the difference is about reachability.
/// That widget is public, so a test can build it and pass a fake. The menu PDF
/// button is private to its sheet — a test that could only reach it by making
/// it public would be a test proving a widget works while saying nothing about
/// whether anything opens it.
///
/// Overriding this instead lets the test tap "Full menu" on the real venue
/// screen, land in the real sheet, press the real button, and still control
/// what the platform answers. The failing path is the one that matters here,
/// and on a Windows test runner the real launcher answers "succeeded".
@Riverpod(keepAlive: true)
ContactLauncher contactLauncher(Ref ref) => kDefaultLauncher;

@Riverpod(keepAlive: true)
RestaurantRepository restaurantRepository(Ref ref) => RestaurantRepositoryImpl(
      ref.watch(apiProvider),
      () => ref.read(localeCodeProvider),
    );

@Riverpod(keepAlive: true)
ReservationRepository reservationRepository(Ref ref) =>
    ReservationRepositoryImpl(ref.watch(apiProvider));

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepositoryImpl(
      ref.watch(apiProvider),
      () => ref.read(localeCodeProvider),
    );

@Riverpod(keepAlive: true)
SavedRepository savedRepository(Ref ref) =>
    SavedRepositoryImpl(ref.watch(apiProvider), () => ref.read(localeCodeProvider));

/// C-4.7. No locale reader, unlike its neighbours: a notification's copy is
/// assembled in the WIDGET from `type` + `data`, so the data layer has no name
/// pair to resolve and nothing to localise.
@Riverpod(keepAlive: true)
NotificationsRepository notificationsRepository(Ref ref) =>
    NotificationsRepositoryImpl(ref.watch(apiProvider));

/// Today, as the app should treat it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// A PROVIDER RATHER THAN A CLOCK READ INSIDE A WIDGET
/// ─────────────────────────────────────────────────────────────────────────
///
/// Two screens build a seven-day strip starting from today. Read straight from
/// the system clock, that makes their pictures change every night — a golden
/// holding "8 9 10 11 12" is wrong by morning, and the failure it produces
/// says nothing at all about the code that changed.
///
/// The move sheet caught it, on its first golden. The BOOKING screen has had
/// the same widget since wave 3 and its golden never noticed, because at
/// 390x844 the date strip sits below the fold — the picture happened not to
/// contain the thing that varies. That is luck, not determinism, and luck is
/// what this replaces.
///
/// Overridden to a fixed day in `screen_registry.dart`. In the app it is the
/// real clock.
@riverpod
DateTime today(Ref ref) => DateTime.now();

/// Keeps [LocaleCode] in step with the widget tree's `Localizations`.
class LocaleSync extends ConsumerWidget {
  const LocaleSync({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = Localizations.localeOf(context).languageCode;
    if (ref.read(localeCodeProvider) != code) {
      // After the frame: writing a provider during build is the Riverpod
      // error that turns into a silent rebuild loop.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(localeCodeProvider.notifier).set(code);
      });
    }
    return child;
  }
}
