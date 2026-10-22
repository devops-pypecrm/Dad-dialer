import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/phone_normalizer.dart';
import '../data/leads_repository.dart';
import '../domain/crm_lead.dart';

part 'cached_leads_provider.g.dart';

/// Holds the full CRM lead/contact list fetched from `GET /api/android/leads`
/// and an in-memory `normalizedPhone -> CrmLead` index for O(1) match
/// lookups — the correct replacement for the `dialer-version` branch's
/// `endsWith` suffix-match placeholder (see `phone_normalizer.dart`'s doc
/// comment). `keepAlive: true` because this is genuinely session-scoped
/// data, invalidated on logout by `SessionController`.
@Riverpod(keepAlive: true)
class CachedLeads extends _$CachedLeads {
  int? _lastSyncMillis;
  Map<String, CrmLead> _byNormalizedPhone = const {};

  @override
  Future<List<CrmLead>> build() async {
    final repository = ref.watch(leadsRepositoryProvider);
    final leads = await repository.fetchAll();
    _lastSyncMillis = DateTime.now().millisecondsSinceEpoch;
    _rebuildIndex(leads);
    return leads;
  }

  /// Called on app foreground / periodically — delta-fetches and merges
  /// rather than refetching everything.
  Future<void> refresh() async {
    final repository = ref.read(leadsRepositoryProvider);
    final delta = await repository.fetchAll(lastSyncMillis: _lastSyncMillis);
    _lastSyncMillis = DateTime.now().millisecondsSinceEpoch;
    if (delta.isEmpty) return;

    final current = state.valueOrNull ?? const [];
    final byId = {for (final lead in current) lead.id: lead};
    for (final lead in delta) {
      byId[lead.id] = lead;
    }
    final merged = byId.values.toList();
    _rebuildIndex(merged);
    state = AsyncValue.data(merged);
  }

  void _rebuildIndex(List<CrmLead> leads) {
    final index = <String, CrmLead>{};
    for (final lead in leads) {
      final primary = normalizePhoneNumber(lead.phone);
      if (primary.length >= kMinNormalizedPhoneLength) index[primary] = lead;
      final secondary = lead.secondaryPhone;
      if (secondary != null && secondary.isNotEmpty) {
        final normalized = normalizePhoneNumber(secondary);
        if (normalized.length >= kMinNormalizedPhoneLength) index[normalized] = lead;
      }
    }
    _byNormalizedPhone = index;
  }

  /// Matches a raw (unformatted) phone number against the cached index —
  /// full normalized equality only, never a suffix match. Returns null if
  /// nothing matches or the list hasn't loaded yet.
  CrmLead? matchLead(String rawNumber) {
    final normalized = normalizePhoneNumber(rawNumber);
    if (normalized.length < kMinNormalizedPhoneLength) return null;
    return _byNormalizedPhone[normalized];
  }
}
