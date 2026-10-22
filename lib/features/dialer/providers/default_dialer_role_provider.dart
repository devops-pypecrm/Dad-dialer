import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/telecom_bridge.dart';

part 'default_dialer_role_provider.g.dart';

/// Whether this app currently holds `RoleManager.ROLE_DIALER` — checked
/// fresh (not cached across app restarts) since the user can change the
/// default Phone app from system Settings at any time.
@riverpod
class DefaultDialerRole extends _$DefaultDialerRole {
  @override
  Future<bool> build() => ref.watch(telecomBridgeProvider).isDefaultDialer();

  /// Drives the whole become-default-dialer flow. Returns the outcome so
  /// the UI can show the right message (permanently denied -> "open
  /// Settings", unsupported SDK, etc.) — see `DialerRoleOutcome`.
  Future<DialerRoleOutcome> requestRole() async {
    final bridge = ref.read(telecomBridgeProvider);
    final outcome = await bridge.requestDialerRole();
    // Always re-check the real state afterward rather than trusting the
    // outcome enum alone — GRANTED/DENIED both warrant a refresh, and so
    // does ALREADY_DEFAULT (first load after the role was set some other
    // way, e.g. directly from system Settings).
    state = AsyncValue.data(await bridge.isDefaultDialer());
    return outcome;
  }

  Future<void> refresh() async {
    state = AsyncValue.data(await ref.read(telecomBridgeProvider).isDefaultDialer());
  }
}
