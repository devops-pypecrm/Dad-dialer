import 'package:freezed_annotation/freezed_annotation.dart';

import 'organisation.dart';

part 'user_session.freezed.dart';
part 'user_session.g.dart';

/// The exact response shape of `POST /api/auth/login` and `GET /api/auth/me`
/// (Dad-backend/src/controllers/authController.ts) — same contract
/// Dad-mobile's `UserSession` parses, trimmed to what this app needs.
@freezed
class UserSession with _$UserSession {
  const factory UserSession({
    required String id,
    required String firstName,
    required String lastName,
    required String email,
    required String role,
    required Organisation organisation,
    /// Present on the login response; absent on `/auth/me` refreshes, in
    /// which case the previously stored token is kept.
    String? token,
  }) = _UserSession;

  factory UserSession.fromJson(Map<String, dynamic> json) => _$UserSessionFromJson(json);
}
