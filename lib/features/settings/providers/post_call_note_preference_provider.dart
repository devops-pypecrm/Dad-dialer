import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAskNoteAfterCallKey = 'ask_note_after_call';

/// Whether the "Update lead" sheet pops up after a call with a CRM lead.
/// A personal, per-device preference (on by default), stored locally like
/// `PreferCrmNameInCallLogs`.
class AskNoteAfterCallNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAskNoteAfterCallKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAskNoteAfterCallKey, enabled);
    state = AsyncValue.data(enabled);
  }
}

final askNoteAfterCallProvider = AsyncNotifierProvider<AskNoteAfterCallNotifier, bool>(AskNoteAfterCallNotifier.new);
