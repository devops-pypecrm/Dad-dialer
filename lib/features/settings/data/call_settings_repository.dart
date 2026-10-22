import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/call_settings.dart';

part 'call_settings_repository.g.dart';

@Riverpod(keepAlive: true)
CallSettingsRepository callSettingsRepository(ProviderRef<CallSettingsRepository> ref) =>
    CallSettingsRepository(ref.watch(dioProvider));

/// `GET /api/call-settings` — already live, org-scoped, auto-creates a
/// default row if none exists server-side. Phase 1 only reads
/// `popupOnIncoming`; no write/settings-UI yet.
class CallSettingsRepository {
  CallSettingsRepository(this._dio);

  final Dio _dio;

  Future<CallSettings> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/call-settings');
      return CallSettings.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
