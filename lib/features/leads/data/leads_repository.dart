import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/crm_lead.dart';

part 'leads_repository.g.dart';

@Riverpod(keepAlive: true)
LeadsRepository leadsRepository(ProviderRef<LeadsRepository> ref) => LeadsRepository(ref.watch(dioProvider));

/// `GET /api/android/leads` — already live on Dad-backend (Tier 0/4 of the
/// existing Helper app uses the same endpoint for the same purpose: a
/// compact, delta-syncable, org-scoped list good enough to build a local
/// phone-number match index from). No backend change needed for this.
class LeadsRepository {
  LeadsRepository(this._dio);

  final Dio _dio;

  /// [lastSyncMillis] is epoch millis of the last successful fetch — the
  /// endpoint supports a delta-only response via `?lastSync=`; pass null for
  /// the first-ever fetch on a device.
  Future<List<CrmLead>> fetchAll({int? lastSyncMillis}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/android/leads',
        queryParameters: lastSyncMillis == null ? null : {'lastSync': lastSyncMillis},
      );
      final data = response.data!;
      final leads = (data['leads'] as List<dynamic>? ?? [])
          .map((e) => CrmLead.fromJson(e as Map<String, dynamic>));
      final contacts = (data['contacts'] as List<dynamic>? ?? [])
          .map((e) => CrmLead.fromJson(e as Map<String, dynamic>));
      return [...leads, ...contacts];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `GET /api/android/leads/:leadId/last-note` — on-demand, single-lead
  /// lookup (not part of the bulk [fetchAll] sync, see that endpoint's own
  /// doc comment on why). Returns null if the lead has no notes yet.
  Future<String?> fetchLastNote(String leadId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/android/leads/$leadId/last-note');
      return response.data?['note'] as String?;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
