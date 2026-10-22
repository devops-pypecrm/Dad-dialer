import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/secure_storage_provider.dart';
import '../../dialer/data/telecom_bridge.dart';
import '../../leads/providers/cached_leads_provider.dart';
import '../data/auth_repository.dart';
import '../domain/user_session.dart';

part 'session_provider.g.dart';

/// Single source of truth for "who is logged in" — same role as Dad-mobile's
/// `SessionController`, trimmed of multi-account support (a field rep's own
/// phone only ever has one signed-in account).
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  Future<UserSession?> build() => _restoreSession();

  Future<UserSession?> _restoreSession() async {
    final storage = ref.read(secureStorageServiceProvider);
    final token = await storage.readToken();
    if (token == null) return null;

    try {
      final repository = ref.read(authRepositoryProvider);
      final me = await repository.fetchCurrentUser();
      final session = me.copyWith(token: token);
      await storage.saveUserInfo(jsonEncode(session.toJson()));
      // Re-assert native auth on every cold start, not just at login — if
      // app data was partially cleared (native SharedPreferences wiped but
      // flutter_secure_storage survived) DialerSyncWorker would otherwise
      // silently stop syncing without any visible sign in this Dart-side
      // session state.
      await ref.read(telecomBridgeProvider).saveAuthForNative(
            token: token,
            apiBaseUrl: AppConfig.instance.apiBaseUrl,
          );
      return session;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // The Dio interceptor already cleared storage and will call
        // forceLogout(); returning null here keeps this build in sync.
        return null;
      }
      // Offline or backend unreachable: fall back to the last known
      // session so the app stays usable without a network hop.
      final cached = await storage.readUserInfo();
      if (cached == null) return null;
      return UserSession.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final session = await repository.login(email: email, password: password);

      final storage = ref.read(secureStorageServiceProvider);
      await storage.saveToken(session.token!);
      await storage.saveUserInfo(jsonEncode(session.toJson()));
      // Duplicated into native SharedPreferences so DialerSyncWorker (a
      // background WorkManager job) can authenticate with the Flutter
      // engine fully suspended — same pattern as Dad-call-recorder's
      // CallRecordingEngine.saveAuthForNative.
      await ref.read(telecomBridgeProvider).saveAuthForNative(
            token: session.token!,
            apiBaseUrl: AppConfig.instance.apiBaseUrl,
          );

      return session;
    });
  }

  Future<void> logout() async {
    await ref.read(secureStorageServiceProvider).clear();
    await ref.read(telecomBridgeProvider).clearAuthForNative();
    state = const AsyncValue.data(null);
    _invalidateAccountScopedCaches();
  }

  /// Invoked by the Dio interceptor on a 401 — must never throw.
  Future<void> forceLogout() async {
    await ref.read(secureStorageServiceProvider).clear();
    await ref.read(telecomBridgeProvider).clearAuthForNative();
    state = const AsyncValue.data(null);
    _invalidateAccountScopedCaches();
  }

  /// Add any new `@Riverpod(keepAlive: true)` provider here that caches
  /// data fetched *for the logged-in user* — same discipline as Dad-mobile's
  /// `SessionController._invalidateAccountScopedCaches`.
  void _invalidateAccountScopedCaches() {
    ref.invalidate(cachedLeadsProvider);
  }
}
