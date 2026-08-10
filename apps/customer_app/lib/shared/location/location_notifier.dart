import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'location_source.dart';

part 'location_notifier.g.dart';

/// The plugin, behind its port. Overridden in every test.
@Riverpod(keepAlive: true)
LocationSource locationSource(Ref ref) => const GeolocatorLocationSource();

/// The diner's position for this session, or the reason there isn't one.
///
/// ─────────────────────────────────────────────────────────────────────────
/// NULL UNTIL ASKED, AND ASKED ONLY BY A TAP
/// ─────────────────────────────────────────────────────────────────────────
///
/// The initial state is "we have not asked", not "we are asking". Building
/// this provider must never raise a permission dialog — a provider is
/// constructed by whatever reads it first, which is not a decision a diner
/// made.
///
/// So the dialog is raised by exactly one call, [request], wired to exactly
/// one control: the "near me" toggle in the filter sheet. That is the
/// agreement — *"I don't want a permission prompt in the app before there's a
/// reason for one"* — expressed as code rather than as a convention somebody
/// has to remember.
///
/// ── AND IT IS NOT PERSISTED ──────────────────────────────────────────────
///
/// `keepAlive` so it survives the sheet closing, and nothing more. A position
/// written to storage would be a stale answer to "where are you" on the next
/// launch, in a city where a diner's evening plans move them ten kilometres.
@Riverpod(keepAlive: true)
class DinerLocation extends _$DinerLocation {
  /// Null means NOT ASKED. It is a third state and it matters: the control
  /// reads "Near me" before, and either a distance or a refusal after.
  @override
  LocationResult? build() => null;

  /// Ask. Returns what happened so the caller can react in the same gesture.
  ///
  /// Idempotent in the way that matters: a second call after a success does
  /// not re-prompt, because the position is already here. A second call after
  /// a refusal DOES re-prompt, which is correct — a diner who declined and
  /// then tapped the control again has changed their mind, and the OS decides
  /// whether to show the dialog.
  Future<LocationResult> request() async {
    final LocationResult? existing = state;
    if (existing != null && existing.hasPosition) return existing;

    final LocationResult result = await ref.read(locationSourceProvider).current();
    state = result;
    return result;
  }

  /// Forget it, without asking anything.
  ///
  /// For the diner turning the distance filter back off. The position goes,
  /// so the next tap asks again rather than silently reusing a fix from an
  /// hour and one taxi ride ago.
  void clear() => state = null;
}
