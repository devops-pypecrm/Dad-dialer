import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/telecom_bridge.dart';
import '../domain/call_state.dart';

part 'active_call_provider.g.dart';

/// Live stream of whatever call Telecom currently has — the in-call/
/// incoming-call screen watches this to render RINGING vs ACTIVE vs nothing.
@riverpod
Stream<ActiveCall> activeCall(AutoDisposeStreamProviderRef<ActiveCall> ref) {
  final bridge = ref.watch(telecomBridgeProvider);
  return bridge.callEvents();
}
