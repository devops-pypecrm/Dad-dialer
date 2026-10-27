import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_provider.dart';

/// One option from the org's own lead pipeline (`Organisation.leadStatuses`).
typedef LeadStatusOption = ({String id, String label});

final leadUpdateRepositoryProvider = Provider<LeadUpdateRepository>(
  (ref) => LeadUpdateRepository(ref.watch(dioProvider)),
);

/// The org's lead statuses — fetched once per app session and reused by
/// every post-call sheet.
final leadStatusOptionsProvider = FutureProvider<List<LeadStatusOption>>(
  (ref) => ref.watch(leadUpdateRepositoryProvider).fetchLeadStatuses(),
);

/// The two writes the post-call sheet needs, against the same endpoints
/// Dad-mobile already uses for them (`LeadsRepository.addLeadNote` /
/// `updateLead` there).
class LeadUpdateRepository {
  LeadUpdateRepository(this._dio);

  final Dio _dio;

  /// Same fallback Dad-mobile's `LeadStatusField` uses when an org never
  /// customised its pipeline.
  static const _fallback = ['new', 'contacted', 'qualified', 'converted', 'lost'];

  /// `GET /api/auth/me` already returns the full organisation row, which
  /// carries `leadStatuses` — no separate endpoint needed.
  Future<List<LeadStatusOption>> fetchLeadStatuses() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final raw = (response.data?['organisation'] as Map<String, dynamic>?)?['leadStatuses'];
      if (raw is List && raw.isNotEmpty) {
        return [
          for (final s in raw.whereType<Map<String, dynamic>>())
            if (s['id'] is String) (id: s['id'] as String, label: (s['label'] as String?) ?? s['id'] as String),
        ];
      }
      return [for (final id in _fallback) (id: id, label: id[0].toUpperCase() + id.substring(1))];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `POST /api/interactions/leads/:leadId/interactions` as a `note`.
  Future<void> addNote(String leadId, String text) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/interactions/leads/$leadId/interactions',
        data: {
          'type': 'note',
          'subject': 'Call note',
          'description': text,
          'date': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// `PUT /api/leads/:id` with only `status`.
  Future<void> updateStatus(String leadId, String status) async {
    try {
      await _dio.put<Map<String, dynamic>>('/leads/$leadId', data: {'status': status});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
