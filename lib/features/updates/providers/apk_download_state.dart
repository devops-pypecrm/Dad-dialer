import 'package:freezed_annotation/freezed_annotation.dart';

part 'apk_download_state.freezed.dart';

/// Drives the in-app download+install flow's UI (see `ApkDownloadController`
/// and the Updates screen). `installLaunched` means Android's own
/// install/update confirmation dialog has been handed off to — this app has
/// no way to know whether the user actually completes that system prompt.
@freezed
class ApkDownloadState with _$ApkDownloadState {
  const factory ApkDownloadState.idle() = ApkDownloadIdle;

  /// [receivedBytes]/[totalBytes] (not just [progress]) so the UI can show
  /// "12.3 MB / 45.0 MB", not only a bare percentage — `totalBytes` is `-1`
  /// until the server's Content-Length is known (first progress callback).
  const factory ApkDownloadState.downloading({
    required double progress,
    required int receivedBytes,
    required int totalBytes,
  }) = ApkDownloadInProgress;

  /// The .apk is on disk but this app currently lacks the "Install unknown
  /// apps" grant — the user has to flip that on in system Settings, then
  /// retry the install (the file itself doesn't need re-downloading).
  const factory ApkDownloadState.permissionNeeded({required String filePath}) = ApkDownloadPermissionNeeded;

  const factory ApkDownloadState.installLaunched({required String filePath}) = ApkDownloadInstallLaunched;

  const factory ApkDownloadState.error({required String message, String? filePath}) = ApkDownloadError;
}
