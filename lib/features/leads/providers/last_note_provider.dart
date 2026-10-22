import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/leads_repository.dart';

part 'last_note_provider.g.dart';

/// Fetches a single lead's most recent note on demand -- `autoDispose`
/// since this is only relevant for as long as a specific incoming-call
/// screen showing that lead is on screen, not something to keep cached
/// indefinitely per lead the way [cachedLeadsProvider] does for the whole
/// lead list.
@riverpod
Future<String?> lastNote(AutoDisposeFutureProviderRef<String?> ref, String leadId) {
  return ref.watch(leadsRepositoryProvider).fetchLastNote(leadId);
}
