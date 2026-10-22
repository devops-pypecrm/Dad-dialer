import 'package:freezed_annotation/freezed_annotation.dart';

part 'call_log_entry.freezed.dart';

enum CallLogType { incoming, outgoing, missed, rejected, blocked, unknown }

/// One row from Android's real `CallLog.Calls` provider — see
/// `CallLogReader.kt`. This app reads the system CallLog directly as its
/// single source of truth for Recents; no separate local shadow store (a
/// bug the `dialer-version` reference branch had — see the approved plan).
@freezed
class CallLogEntry with _$CallLogEntry {
  const factory CallLogEntry({
    required String id,
    String? number,
    String? cachedName,
    required CallLogType type,
    required DateTime date,
    required int durationSeconds,
    // Real Telecom-framework data (see CallLogReader.kt) — null on a
    // single-SIM device, or for any call this couldn't resolve to a known
    // phone account. Never a fabricated default.
    int? simSlot,
    String? simLabel,
  }) = _CallLogEntry;

  factory CallLogEntry.fromNative(Map<String, Object?> map) {
    return CallLogEntry(
      id: map['id'] as String? ?? '',
      number: map['number'] as String?,
      cachedName: map['cachedName'] as String?,
      type: _typeFromWire(map['type'] as String?),
      date: DateTime.fromMillisecondsSinceEpoch((map['dateMillis'] as num?)?.toInt() ?? 0),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      simSlot: (map['simSlot'] as num?)?.toInt(),
      simLabel: map['simLabel'] as String?,
    );
  }

  static CallLogType _typeFromWire(String? raw) => switch (raw) {
        'INCOMING' => CallLogType.incoming,
        'OUTGOING' => CallLogType.outgoing,
        'MISSED' => CallLogType.missed,
        'REJECTED' => CallLogType.rejected,
        'BLOCKED' => CallLogType.blocked,
        _ => CallLogType.unknown,
      };
}
