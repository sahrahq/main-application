// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue_image_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$networkImageFactoryHash() => r'8a1022ecdf819cb76052618c5ae0ce141f567552';

/// URL → something Flutter can draw. THE ONLY LINE THAT TOUCHES THE NETWORK.
///
/// A seam, for the same reason the contact launcher has one: `flutter_test`
/// answers every HTTP request with a 400 and never opens a socket, so a golden
/// built on the real provider draws NOTHING — which looks exactly like the
/// designed empty state. A golden named "venue with a photo" would picture a
/// venue without one and pass forever.
///
/// That is the stale-fixture failure in a new place: a picture that quietly
/// stops meaning what its name says. Overridden in `screen_registry.dart` with
/// a real decodable image so the wiring is actually pictured.
///
/// Copied from [networkImageFactory].
@ProviderFor(networkImageFactory)
final networkImageFactoryProvider = Provider<ImageProvider Function(String url)>.internal(
  networkImageFactory,
  name: r'networkImageFactoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$networkImageFactoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NetworkImageFactoryRef = ProviderRef<ImageProvider Function(String url)>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
