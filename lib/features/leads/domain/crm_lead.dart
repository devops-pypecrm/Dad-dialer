import 'package:freezed_annotation/freezed_annotation.dart';

part 'crm_lead.freezed.dart';
part 'crm_lead.g.dart';

/// One entry from `GET /api/android/leads` — matches either a `Lead` or a
/// `Contact` (Dad-backend/src/controllers/androidController.ts
/// `getAndroidLeads`), distinguished by [type]. Field names/shape confirmed
/// by direct inspection of that endpoint (already live, used today by
/// Dad-call-recorder for the same purpose).
@freezed
class CrmLead with _$CrmLead {
  const factory CrmLead({
    required String id,
    required String phone,
    String? secondaryPhone,
    String? firstName,
    String? lastName,
    String? email,
    String? enquiryAbout,
    String? status,
    String? company,
    required String type, // "lead" | "contact"
  }) = _CrmLead;

  factory CrmLead.fromJson(Map<String, dynamic> json) => _$CrmLeadFromJson(json);
}

extension CrmLeadDisplay on CrmLead {
  String get displayName {
    final name = [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
    if (name.isNotEmpty) return name;
    if (company != null && company!.isNotEmpty) return company!;
    return phone;
  }

  bool get isLead => type == 'lead';
}
