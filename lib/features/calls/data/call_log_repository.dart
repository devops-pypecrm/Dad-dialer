import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../dialer/data/telecom_bridge.dart';
import '../domain/call_log_entry.dart';

part 'call_log_repository.g.dart';

@Riverpod(keepAlive: true)
CallLogRepository callLogRepository(ProviderRef<CallLogRepository> ref) =>
    CallLogRepository(ref.watch(telecomBridgeProvider));

/// Bridges to `CallLogReader.kt` — reads Android's real `CallLog.Calls`
/// provider, no local persistence of its own.
class CallLogRepository {
  CallLogRepository(this._bridge);

  final TelecomBridge _bridge;

  Future<List<CallLogEntry>> fetchRecent({int limit = 200}) async {
    final raw = await _bridge.getCallLog(limit: limit);
    return raw.map(CallLogEntry.fromNative).toList();
  }
}
