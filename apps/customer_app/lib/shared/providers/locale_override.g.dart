// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_override.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localePreferenceStoreHash() => r'f41c3dd61d740fb4281674e1f7e1d6c71b6618af';

/// See also [localePreferenceStore].
@ProviderFor(localePreferenceStore)
final localePreferenceStoreProvider = Provider<LocalePreferenceStore>.internal(
  localePreferenceStore,
  name: r'localePreferenceStoreProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$localePreferenceStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalePreferenceStoreRef = ProviderRef<LocalePreferenceStore>;
String _$localeOverrideHash() => r'9dfb19c75034917bf0165ba41da362c252b10ac6';

/// The language the diner CHOSE, or null to follow the device.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS EXISTS AT ALL — AMENDED 2026-08-09
/// ─────────────────────────────────────────────────────────────────────────
///
/// The app followed the device and nothing else, on the argument that an
/// in-app switch would be "a second source of truth for something the phone
/// already knows". That was overruled, and correctly: a large share of people
/// in Egypt run their phone in English and want to read Arabic, or the
/// reverse. The handset language is a fact about the handset.
///
/// **NULL IS THE ORDINARY STATE.** Nothing is written until a diner opens the
/// language sheet and picks something, so first launch — and every launch for
/// anybody who never visits that screen — behaves exactly as it did before.
/// This is an override, not a setting with a default.
///
/// ── NOT `users.locale`, AND NOT IN THE SESSION ───────────────────────────
///
/// `PATCH /auth/me` can set a locale, but that is the language SAHRA writes TO
/// you in: push, WhatsApp, the eventual confirmation email. This is the
/// language you READ THE APP in, on this handset. They are different
/// questions, and keeping this one local means it also works signed out —
/// which is exactly when a diner discovers the app is in the wrong language
/// for them.
///
/// Copied from [LocaleOverride].
@ProviderFor(LocaleOverride)
final localeOverrideProvider = NotifierProvider<LocaleOverride, String?>.internal(
  LocaleOverride.new,
  name: r'localeOverrideProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$localeOverrideHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LocaleOverride = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
