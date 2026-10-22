import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'call_log_name_preference_provider.g.dart';

const _kPreferCrmNameKey = 'call_logs_prefer_crm_name';

/// Whether Call Logs (Recents) shows the CRM lead's name for a matched
/// number instead of the device contact's name. A personal, per-device
/// display preference — not an org policy — so this is stored locally via
/// `shared_preferences` rather than synced through the backend
/// `CallSettings` model.
///
/// - ON (default): CRM lead name if the number matches a CRM lead,
///   otherwise just the raw number — matches this app's original hardcoded
///   Recents behavior, so nothing changes for existing users until they
///   explicitly turn it off. A number that's saved in BOTH the CRM and
///   device contacts (under different names) shows the CRM name.
/// - OFF: the device contact name (`CallLogEntry.cachedName`, sourced from
///   Android's own `CallLog.Calls.CACHED_NAME` — the OS already resolves
///   this against the phone's Contacts, no separate lookup needed here),
///   falling back to the raw number if there's no contact match either.
///   A number saved in both shows the contact name.
@Riverpod(keepAlive: true)
class PreferCrmNameInCallLogs extends _$PreferCrmNameInCallLogs {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPreferCrmNameKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPreferCrmNameKey, enabled);
    state = AsyncValue.data(enabled);
  }
}
