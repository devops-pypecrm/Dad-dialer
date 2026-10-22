// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apk_download_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$apkDownloadControllerHash() =>
    r'bae3523e76d80dcaee5b3e3df88b164bed53cad8';

/// Downloads the current .apk into this app's own cache dir and hands it to
/// the system installer. Mirrors Dad-mobile/Dad-call-recorder's
/// `ApkDownloadController` — same flow, same reasoning (see that file's
/// doc comment and pypecrm/APP_UPDATE_SYSTEM.md) — plus byte-size reporting
/// through [ApkDownloadState.downloading] so the UI can show actual
/// downloaded/total size, not just a percentage.
///
/// Copied from [ApkDownloadController].
@ProviderFor(ApkDownloadController)
final apkDownloadControllerProvider =
    AutoDisposeNotifierProvider<
      ApkDownloadController,
      ApkDownloadState
    >.internal(
      ApkDownloadController.new,
      name: r'apkDownloadControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$apkDownloadControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ApkDownloadController = AutoDisposeNotifier<ApkDownloadState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
