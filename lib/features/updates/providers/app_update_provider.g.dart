// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$latestDialerReleaseHash() =>
    r'3ea6701d52ce0302aea996fd0f0de2b30fa8a669';

/// Swallows every failure to `null` — a broken update check must never
/// block or error out anything else in this app.
///
/// Copied from [latestDialerRelease].
@ProviderFor(latestDialerRelease)
final latestDialerReleaseProvider =
    AutoDisposeFutureProvider<AppRelease?>.internal(
      latestDialerRelease,
      name: r'latestDialerReleaseProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$latestDialerReleaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LatestDialerReleaseRef = AutoDisposeFutureProviderRef<AppRelease?>;
String _$currentPackageInfoHash() =>
    r'ea507b2c91f658fb5b956e9f71d4020caf5bf4a0';

/// See also [currentPackageInfo].
@ProviderFor(currentPackageInfo)
final currentPackageInfoProvider =
    AutoDisposeFutureProvider<PackageInfo>.internal(
      currentPackageInfo,
      name: r'currentPackageInfoProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentPackageInfoHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentPackageInfoRef = AutoDisposeFutureProviderRef<PackageInfo>;
String _$availableUpdateHash() => r'9703f65982349ff26c9128fa5ca93f53adc745b0';

/// Non-null only when the server's `versionCode` is strictly newer than
/// this running build's own build number.
///
/// Copied from [availableUpdate].
@ProviderFor(availableUpdate)
final availableUpdateProvider = AutoDisposeFutureProvider<AppRelease?>.internal(
  availableUpdate,
  name: r'availableUpdateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$availableUpdateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableUpdateRef = AutoDisposeFutureProviderRef<AppRelease?>;
String _$pendingUpdatePromptHash() =>
    r'9d27752abd5ef6fcbe9e3258f4b50cfa615b9a39';

/// The single thing the app-wide popup actually watches: an update exists
/// AND it isn't the one the user already dismissed with "Later" this
/// build. Mirrors Dad-mobile/Dad-call-recorder's identical availableUpdate +
/// dismissed-memory combination — kept as its own tiny derived step instead
/// of folded into [availableUpdate] directly (keeping "is there an update"
/// and "should I nag about it" as two separate questions is what makes the
/// dismiss behavior easy to get right).
///
/// Copied from [pendingUpdatePrompt].
@ProviderFor(pendingUpdatePrompt)
final pendingUpdatePromptProvider =
    AutoDisposeFutureProvider<AppRelease?>.internal(
      pendingUpdatePrompt,
      name: r'pendingUpdatePromptProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingUpdatePromptHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingUpdatePromptRef = AutoDisposeFutureProviderRef<AppRelease?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
