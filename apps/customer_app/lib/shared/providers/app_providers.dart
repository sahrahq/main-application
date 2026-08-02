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

import '../../config/env/env.dart';
import '../../core/network/dio_transport.dart';
import '../../features/reservations/data/reservation_repository_impl.dart';
import '../../features/reservations/domain/reservation_repository.dart';
import '../../features/restaurants/data/restaurant_repository_impl.dart';
import '../../features/restaurants/domain/restaurant_repository.dart';

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
    );

@Riverpod(keepAlive: true)
SahraApi api(Ref ref) => SahraApi(ref.watch(transportProvider));

@Riverpod(keepAlive: true)
RestaurantRepository restaurantRepository(Ref ref) => RestaurantRepositoryImpl(
      ref.watch(apiProvider),
      () => ref.read(localeCodeProvider),
    );

@Riverpod(keepAlive: true)
ReservationRepository reservationRepository(Ref ref) =>
    ReservationRepositoryImpl(ref.watch(apiProvider));

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
