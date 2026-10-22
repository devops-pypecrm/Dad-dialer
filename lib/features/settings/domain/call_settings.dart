import 'package:freezed_annotation/freezed_annotation.dart';

part 'call_settings.freezed.dart';
part 'call_settings.g.dart';

/// Only the field this app actually reads from `GET /api/call-settings`
/// (Dad-backend's `CallSettings` model) — Phase 1 has no settings UI of its
/// own, just this one read.
@freezed
class CallSettings with _$CallSettings {
  const factory CallSettings({
    @Default(true) bool popupOnIncoming,
  }) = _CallSettings;

  factory CallSettings.fromJson(Map<String, dynamic> json) => _$CallSettingsFromJson(json);
}
