// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionControllerHash() => r'36e449fcfaf3794de6abe77a177e21c0ad37d0c7';

/// Single source of truth for "who is logged in" — same role as Dad-mobile's
/// `SessionController`, trimmed of multi-account support (a field rep's own
/// phone only ever has one signed-in account).
///
/// Copied from [SessionController].
@ProviderFor(SessionController)
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, UserSession?>.internal(
      SessionController.new,
      name: r'sessionControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sessionControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SessionController = AsyncNotifier<UserSession?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
