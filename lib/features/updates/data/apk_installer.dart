import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apk_installer.g.dart';

@Riverpod(keepAlive: true)
ApkInstaller apkInstaller(ApkInstallerRef ref) => const ApkInstaller();

/// Dart-side handle to `MainActivity.kt`'s install MethodChannel — same
/// pattern as Dad-mobile/Dad-call-recorder's `apk_installer.dart`.
///
/// Note (see `Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md` for the
/// analogous precedent): `Dad-dialer`'s manifest is otherwise written with
/// eventual Play Store submission in mind, and Play forbids an app it
/// distributes from self-updating via a sideloaded APK. This feature is
/// built anyway because, in practice, this app is sideloaded-only today —
/// same as `Dad-mobile`/`Dad-call-recorder` already are per
/// `pypecrm/APP_UPDATE_SYSTEM.md` §1. Revisit (drop this feature, or at
/// minimum gate it off) before ever actually submitting to Play.
class ApkInstaller {
  const ApkInstaller();

  static const _channel = MethodChannel('com.pypecrm.dialer/installer');

  Future<bool> canRequestInstalls() async =>
      (await _channel.invokeMethod<bool>('canRequestInstalls')) ?? false;

  Future<void> openInstallPermissionSettings() => _channel.invokeMethod('openInstallPermissionSettings');

  Future<void> installApk(String filePath) => _channel.invokeMethod('installApk', {'filePath': filePath});
}
