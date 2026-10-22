import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../dialer/data/telecom_bridge.dart';
import '../data/call_log_repository.dart';
import '../domain/call_log_entry.dart';

part 'recents_provider.g.dart';

@riverpod
class Recents extends _$Recents {
  @override
  Future<List<CallLogEntry>> build() => ref.watch(callLogRepositoryProvider).fetchRecent();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await ref.read(callLogRepositoryProvider).fetchRecent());
    ref.invalidate(recordedCallIndexProvider);
  }
}

/// Real Tier 0 recording-found signal (see `RecordingStatusStore.kt`) for
/// the whole Recents list in one fetch — refreshed alongside [Recents]
/// above, never on its own separate schedule, so the two can't drift out
/// of sync with each other on screen.
@riverpod
Future<RecordedCallIndex> recordedCallIndex(RecordedCallIndexRef ref) =>
    ref.watch(telecomBridgeProvider).getRecordedCallIndex();
