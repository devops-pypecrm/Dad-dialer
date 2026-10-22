import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/user_session.dart';

part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(ProviderRef<AuthRepository> ref) => AuthRepository(ref.watch(dioProvider));

/// Talks to Dad-backend's `/api/auth` routes — same contract Dad-mobile
/// uses. No business logic lives here.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<UserSession> login({required String email, required String password}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return UserSession.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Restores the session on app launch using the stored token.
  Future<UserSession> fetchCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return UserSession.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
