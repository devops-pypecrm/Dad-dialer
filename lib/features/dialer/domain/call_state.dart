import 'package:freezed_annotation/freezed_annotation.dart';

part 'call_state.freezed.dart';

enum TelecomCallState {
  none,
  /// Outgoing call on a dual-SIM phone set to "ask every time" — waiting
  /// for us to pick the SIM before it can dial.
  selectSim,
  dialing,
  ringingIncoming,
  active,
  holding,
  disconnected,
}

/// Mirrors `CallEventBridge`'s native `STATE_CHANGED`/`CALL_REMOVED` events
/// (`android/app/src/main/kotlin/com/pypecrm/dialer/telecom/CallEventBridge.kt`)
/// — the Dart-side view of whatever call Telecom currently has active.
@freezed
class ActiveCall with _$ActiveCall {
  const factory ActiveCall({
    required TelecomCallState state,
    String? number,
    @Default(false) bool isIncoming,
  }) = _ActiveCall;

  const ActiveCall._();

  static const none = ActiveCall(state: TelecomCallState.none);

  bool get isRinging => state == TelecomCallState.ringingIncoming;
  bool get isActiveOrHolding => state == TelecomCallState.active || state == TelecomCallState.holding;
  bool get isOngoing => state != TelecomCallState.none && state != TelecomCallState.disconnected;
}
