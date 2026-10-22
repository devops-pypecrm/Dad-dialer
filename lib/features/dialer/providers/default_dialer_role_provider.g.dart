// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_dialer_role_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$defaultDialerRoleHash() => r'5096286a8e3ed1ca632c9e0cf102dcb0d567a836';

/// Whether this app currently holds `RoleManager.ROLE_DIALER` — checked
/// fresh (not cached across app restarts) since the user can change the
/// default Phone app from system Settings at any time.
///
/// Copied from [DefaultDialerRole].
@ProviderFor(DefaultDialerRole)
final defaultDialerRoleProvider =
    AutoDisposeAsyncNotifierProvider<DefaultDialerRole, bool>.internal(
      DefaultDialerRole.new,
      name: r'defaultDialerRoleProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$defaultDialerRoleHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DefaultDialerRole = AutoDisposeAsyncNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
