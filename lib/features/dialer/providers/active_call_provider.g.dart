// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_call_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeCallHash() => r'3ff82b05ef3360baa687199207ab619b568be167';

/// Live stream of whatever call Telecom currently has — the in-call/
/// incoming-call screen watches this to render RINGING vs ACTIVE vs nothing.
///
/// Copied from [activeCall].
@ProviderFor(activeCall)
final activeCallProvider = AutoDisposeStreamProvider<ActiveCall>.internal(
  activeCall,
  name: r'activeCallProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeCallHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveCallRef = AutoDisposeStreamProviderRef<ActiveCall>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
