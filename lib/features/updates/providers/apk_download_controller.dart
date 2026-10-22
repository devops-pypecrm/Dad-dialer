import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/apk_installer.dart';
import '../data/app_release_repository.dart';
import 'apk_download_state.dart';

part 'apk_download_controller.g.dart';

/// Downloads the current .apk into this app's own cache dir and hands it to
/// the system installer. Mirrors Dad-mobile/Dad-call-recorder's
/// `ApkDownloadController` — same flow, same reasoning (see that file's
/// doc comment and pypecrm/APP_UPDATE_SYSTEM.md) — plus byte-size reporting
/// through [ApkDownloadState.downloading] so the UI can show actual
/// downloaded/total size, not just a percentage.
@riverpod
class ApkDownloadController extends _$ApkDownloadController {
  @override
  ApkDownloadState build() => const ApkDownloadState.idle();

  Future<void> downloadAndInstall() async {
    state = const ApkDownloadState.downloading(progress: 0, receivedBytes: 0, totalBytes: -1);
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/pypecrm-dialer-update.apk';

      await ref.read(appReleaseRepositoryProvider).downloadApk(
            savePath: savePath,
            onProgress: (received, total) {
              state = ApkDownloadState.downloading(
                progress: total > 0 ? received / total : 0,
                receivedBytes: received,
                totalBytes: total,
              );
            },
          );

      await _attemptInstall(savePath);
    } catch (e) {
      state = ApkDownloadState.error(message: '$e');
    }
  }

  /// Re-attempts the install for an already-downloaded file — used after
  /// the user returns from granting the "Install unknown apps" permission,
  /// after accidentally dismissing the system installer, or retrying a
  /// failed install step — so they never have to re-download the whole
  /// .apk just to retry.
  Future<void> retryInstall(String filePath) => _attemptInstall(filePath);

  Future<void> _attemptInstall(String filePath) async {
    final installer = ref.read(apkInstallerProvider);
    final canInstall = await installer.canRequestInstalls();
    if (!canInstall) {
      state = ApkDownloadState.permissionNeeded(filePath: filePath);
      return;
    }
    try {
      await installer.installApk(filePath);
      state = ApkDownloadState.installLaunched(filePath: filePath);
    } catch (e) {
      state = ApkDownloadState.error(message: '$e', filePath: filePath);
    }
  }

  Future<void> openPermissionSettings() => ref.read(apkInstallerProvider).openInstallPermissionSettings();

  void reset() => state = const ApkDownloadState.idle();
}
