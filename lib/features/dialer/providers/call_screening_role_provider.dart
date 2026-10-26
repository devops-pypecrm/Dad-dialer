import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/telecom_bridge.dart';

/// Whether this app currently holds the "Caller ID & spam app" role —
/// re-checked on demand since it can be changed from system Settings.
class CallScreeningRoleNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(telecomBridgeProvider).isCallScreeningRoleHeld();

  Future<DialerRoleOutcome> requestRole() async {
    final bridge = ref.read(telecomBridgeProvider);
    final outcome = await bridge.requestCallScreeningRole();
    state = AsyncValue.data(await bridge.isCallScreeningRoleHeld());
    return outcome;
  }

  Future<void> refresh() async {
    state = AsyncValue.data(await ref.read(telecomBridgeProvider).isCallScreeningRoleHeld());
  }
}

final callScreeningRoleProvider =
    AsyncNotifierProvider<CallScreeningRoleNotifier, bool>(CallScreeningRoleNotifier.new);
