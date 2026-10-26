import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/call_state.dart';

part 'telecom_bridge.g.dart';

/// Real Tier 0 recording-found entries fetched from `RecordingStatusStore`
/// (native) — see `getRecordedCallIndex`'s doc comment. [hasRecording]
/// mirrors the native side's own fuzzy (last-10-digit + timestamp
/// tolerance) matching exactly, so Dart never re-derives a looser/stricter
/// rule than what actually got written.
class RecordedCallIndex {
  const RecordedCallIndex({required this.entries, required this.toleranceMs});

  final List<({String phone, int timestampMillis})> entries;
  final int toleranceMs;

  bool hasRecording(String? phoneNumber, DateTime date) {
    if (phoneNumber == null) return false;
    final last10Match = RegExp(r'\d').allMatches(phoneNumber).map((m) => m.group(0)).join();
    final last10 = last10Match.length >= 10 ? last10Match.substring(last10Match.length - 10) : last10Match;
    if (last10.length < 10) return false;
    final timestampMillis = date.millisecondsSinceEpoch;
    return entries.any(
      (e) => e.phone == last10 && (e.timestampMillis - timestampMillis).abs() <= toleranceMs,
    );
  }
}

/// Outcome of a `requestDialerRole()` call — mirrors the exact string set
/// `MainActivity.handleRequestDialerRole` returns (`ALREADY_DEFAULT`,
/// `ALREADY_IN_FLIGHT`, `UNSUPPORTED_SDK`, `PERMANENTLY_DENIED`,
/// `PERMISSIONS_DENIED`, `PERMISSIONS_GRANTED`, `GRANTED`, `DENIED`).
enum DialerRoleOutcome {
  alreadyDefault,
  alreadyInFlight,
  unsupportedSdk,
  permanentlyDenied,
  permissionsDenied,
  granted,
  denied,
  unknown;

  static DialerRoleOutcome fromWire(String? raw) => switch (raw) {
        'ALREADY_DEFAULT' => alreadyDefault,
        'ALREADY_IN_FLIGHT' => alreadyInFlight,
        'UNSUPPORTED_SDK' => unsupportedSdk,
        'PERMANENTLY_DENIED' => permanentlyDenied,
        'PERMISSIONS_DENIED' => permissionsDenied,
        'GRANTED' => granted,
        'DENIED' => denied,
        // PERMISSIONS_GRANTED is an intermediate step (permissions granted,
        // role intent about to launch) — treat like "still in progress"
        // rather than a terminal outcome the UI needs to react to.
        _ => unknown,
      };
}

/// Wraps the single native `MethodChannel`/`EventChannel` pair
/// (`com.pypecrm.dialer/telecom`, `com.pypecrm.dialer/call_events`) —
/// plain method-channel bridge, not a federated plugin (see
/// `MainActivity.kt`'s doc comment on why: this is a single standalone app
/// with no other host to share the code with).
class TelecomBridge {
  TelecomBridge({MethodChannel? channel, EventChannel? eventChannel})
      : _channel = channel ?? const MethodChannel('com.pypecrm.dialer/telecom'),
        _eventChannel = eventChannel ?? const EventChannel('com.pypecrm.dialer/call_events');

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  Future<bool> isDefaultDialer() async =>
      (await _channel.invokeMethod<bool>('isDefaultDialer')) ?? false;

  /// Whether this app is the "Caller ID & spam app" (call-screening role).
  Future<bool> isCallScreeningRoleHeld() async =>
      (await _channel.invokeMethod<bool>('isCallScreeningRoleHeld')) ?? false;

  Future<DialerRoleOutcome> requestCallScreeningRole() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('requestCallScreeningRole');
    return DialerRoleOutcome.fromWire(raw?['outcome'] as String?);
  }

  Future<DialerRoleOutcome> requestDialerRole() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('requestDialerRole');
    return DialerRoleOutcome.fromWire(raw?['outcome'] as String?);
  }

  Future<void> openAppSettings() => _channel.invokeMethod('openAppSettings');

  Future<Map<String, bool>> checkDialerPermissions() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('checkDialerPermissions');
    return (raw ?? const {}).map((key, value) => MapEntry(key, value as bool? ?? false));
  }

  /// [simIndex] pins the call to one SIM from [getSimAccounts]; null uses
  /// the system default SIM.
  Future<void> placeCall(String number, {int? simIndex}) =>
      _channel.invokeMethod('placeCall', {'number': number, 'simIndex': ?simIndex});

  /// Call-capable SIMs in slot order — empty if READ_PHONE_STATE isn't
  /// granted yet.
  Future<List<({int index, String label})>> getSimAccounts() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('getSimAccounts') ?? const [];
    return [for (final sim in raw) (index: sim['index']! as int, label: sim['label']! as String)];
  }

  Future<bool> openNewContact(String number) async =>
      (await _channel.invokeMethod<bool>('openNewContact', {'number': number})) ?? false;

  Future<bool> openAddToContact(String number) async =>
      (await _channel.invokeMethod<bool>('openAddToContact', {'number': number})) ?? false;

  Future<bool> answerCall() async => (await _channel.invokeMethod<bool>('answerCall')) ?? false;
  Future<bool> rejectCall() async => (await _channel.invokeMethod<bool>('rejectCall')) ?? false;
  Future<bool> endCall() async => (await _channel.invokeMethod<bool>('endCall')) ?? false;
  Future<bool> holdCall() async => (await _channel.invokeMethod<bool>('holdCall')) ?? false;
  Future<bool> resumeCall() async => (await _channel.invokeMethod<bool>('resumeCall')) ?? false;

  Future<bool> sendDtmf(String digit) async =>
      (await _channel.invokeMethod<bool>('sendDtmf', {'digit': digit})) ?? false;

  Future<void> setSpeaker(bool on) => _channel.invokeMethod('setSpeaker', {'on': on});
  Future<void> setMuted(bool muted) => _channel.invokeMethod('setMuted', {'muted': muted});
  Future<bool> isSpeakerOn() async => (await _channel.invokeMethod<bool>('isSpeakerOn')) ?? false;
  Future<bool> isMuted() async => (await _channel.invokeMethod<bool>('isMuted')) ?? false;
  Future<bool> hasActiveCall() async => (await _channel.invokeMethod<bool>('hasActiveCall')) ?? false;

  Future<List<Map<String, Object?>>> getCallLog({int limit = 200}) async {
    final raw = await _channel.invokeListMethod<Object?>('getCallLog', {'limit': limit});
    return (raw ?? const []).cast<Map<Object?, Object?>>().map((e) => e.cast<String, Object?>()).toList();
  }

  /// Real Tier 0 (native OEM recorder) success signal — see
  /// `RecordingStatusStore.kt`'s doc comment. One bulk fetch, matched
  /// client-side against a whole Recents list, rather than one round trip
  /// per row.
  Future<RecordedCallIndex> getRecordedCallIndex() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('getRecordedCallEntries');
    final rawEntries = (raw?['entries'] as List?) ?? const [];
    final toleranceMs = (raw?['toleranceMs'] as num?)?.toInt() ?? 0;
    final entries = rawEntries
        .cast<Map<Object?, Object?>>()
        .map((e) => (
              phone: e['phone'] as String? ?? '',
              timestampMillis: (e['timestampMillis'] as num?)?.toInt() ?? 0,
            ))
        .toList();
    return RecordedCallIndex(entries: entries, toleranceMs: toleranceMs);
  }

  /// Whether this device has EVER had a confirmed Tier 0 match — used only
  /// to show the in-call "Recording" indicator as active before the
  /// current call's own post-call Tier 0 poll has had a chance to run.
  Future<bool> isNativeRecordingConfirmed() async =>
      (await _channel.invokeMethod<bool>('isNativeRecordingConfirmed')) ?? false;

  /// The org's actual `autoRecordInbound`/`autoRecordOutbound` setting
  /// (admin-controlled in the web CRM's Call Settings page) — read from the
  /// same native cache Tier 0 gating already uses, so the in-call
  /// "Recording" indicator reflects real org policy instead of guessing.
  /// `hasFetched: false` means this device has never successfully fetched
  /// settings yet — show "checking…", not an on/off guess.
  Future<({bool hasFetched, bool autoRecordInbound, bool autoRecordOutbound})> getCallRecordingOrgSettings() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('getCallRecordingOrgSettings');
    return (
      hasFetched: raw?['hasFetched'] as bool? ?? false,
      autoRecordInbound: raw?['autoRecordInbound'] as bool? ?? false,
      autoRecordOutbound: raw?['autoRecordOutbound'] as bool? ?? false,
    );
  }

  /// Opens the general system Settings app — no universal deep link exists
  /// into a specific OEM's own call-recording toggle (every OEM puts it
  /// somewhere different, often inside their own Phone app's settings,
  /// which may not even be reachable once this app holds the dialer role),
  /// so this is deliberately generic rather than a fragile per-OEM guess.
  Future<void> openSystemSettings() => _channel.invokeMethod('openSystemSettings');

  /// Opens the phone's own native dialer app (captured by
  /// `DefaultDialerRoleManager` the moment before Dad-dialer became the
  /// default dialer) — that's where the REAL call-recording toggle lives,
  /// not anything Dad-dialer can switch on itself. Returns `false` (and
  /// falls back to generic system Settings natively) if no such package
  /// was ever captured, or it's no longer installed.
  Future<bool> openOriginalDialerApp() async =>
      (await _channel.invokeMethod<bool>('openOriginalDialerApp')) ?? false;

  /// Duplicates the JWT + API base URL into native storage so
  /// `DialerSyncWorker` can authenticate with the Flutter engine fully
  /// suspended. Call right after a successful login.
  Future<void> saveAuthForNative({required String token, required String apiBaseUrl}) =>
      _channel.invokeMethod('saveAuthForNative', {'token': token, 'apiBaseUrl': apiBaseUrl});

  Future<void> clearAuthForNative() => _channel.invokeMethod('clearAuthForNative');

  /// Phase 1 carrier-merge feasibility spike only — see
  /// `Dad-dialer/CALL_RECORDING_SERVER_METHOD_PLAN.md`. Requires exactly one
  /// already-`ACTIVE` call; places a silent second call to [bridgeNumber]
  /// and attempts a native conference merge once it answers. Returns false
  /// (or throws a `PlatformException` with code `no_active_call`) if there
  /// isn't one — see `getEngineDebugLog` for the actual result, this only
  /// confirms the spike started.
  Future<bool> runMergeSpike(String bridgeNumber) async =>
      (await _channel.invokeMethod<bool>('runMergeSpike', {'bridgeNumber': bridgeNumber})) ?? false;

  /// Newest-first diagnostic entries from `EngineDebugLog` — Tier 0 recovery
  /// events plus (while a spike is running) `MERGE_SPIKE_*` events.
  Future<List<Map<String, Object?>>> getEngineDebugLog() async {
    final raw = await _channel.invokeListMethod<Object?>('getEngineDebugLog');
    return (raw ?? const []).cast<Map<Object?, Object?>>().map((e) => e.cast<String, Object?>()).toList();
  }

  Future<void> clearEngineDebugLog() => _channel.invokeMethod('clearEngineDebugLog');

  /// Streams the currently-tracked call's state — see
  /// `CallEventBridge.kt`'s `emitCallState`/`CALL_REMOVED` events.
  Stream<ActiveCall> callEvents() {
    return _eventChannel.receiveBroadcastStream().map((raw) {
      final map = (raw as Map).cast<String, Object?>();
      if (map['event'] == 'CALL_REMOVED') return ActiveCall.none;
      return ActiveCall(
        state: _stateFromWire(map['state'] as String?),
        number: map['number'] as String?,
        isIncoming: map['isIncoming'] as bool? ?? false,
      );
    });
  }

  TelecomCallState _stateFromWire(String? raw) => switch (raw) {
        'DIALING' || 'CONNECTING' => TelecomCallState.dialing,
        'RINGING' => TelecomCallState.ringingIncoming,
        'ACTIVE' => TelecomCallState.active,
        'HOLDING' => TelecomCallState.holding,
        'DISCONNECTED' || 'DISCONNECTING' => TelecomCallState.disconnected,
        _ => TelecomCallState.none,
      };
}

@Riverpod(keepAlive: true)
TelecomBridge telecomBridge(ProviderRef<TelecomBridge> ref) => TelecomBridge();
