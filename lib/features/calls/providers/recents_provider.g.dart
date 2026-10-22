// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recents_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recordedCallIndexHash() => r'7a5c9810be0cb894a0170a7eea06ff0f76350264';

/// Real Tier 0 recording-found signal (see `RecordingStatusStore.kt`) for
/// the whole Recents list in one fetch — refreshed alongside [Recents]
/// above, never on its own separate schedule, so the two can't drift out
/// of sync with each other on screen.
///
/// Copied from [recordedCallIndex].
@ProviderFor(recordedCallIndex)
final recordedCallIndexProvider =
    AutoDisposeFutureProvider<RecordedCallIndex>.internal(
      recordedCallIndex,
      name: r'recordedCallIndexProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recordedCallIndexHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecordedCallIndexRef = AutoDisposeFutureProviderRef<RecordedCallIndex>;
String _$recentsHash() => r'179078144bc199b56c76e31ea322dfd66f5a0692';

/// See also [Recents].
@ProviderFor(Recents)
final recentsProvider =
    AutoDisposeAsyncNotifierProvider<Recents, List<CallLogEntry>>.internal(
      Recents.new,
      name: r'recentsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Recents = AutoDisposeAsyncNotifier<List<CallLogEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
