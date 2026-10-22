// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crm_lead.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CrmLeadImpl _$$CrmLeadImplFromJson(Map<String, dynamic> json) =>
    _$CrmLeadImpl(
      id: json['id'] as String,
      phone: json['phone'] as String,
      secondaryPhone: json['secondaryPhone'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      enquiryAbout: json['enquiryAbout'] as String?,
      status: json['status'] as String?,
      company: json['company'] as String?,
      type: json['type'] as String,
    );

Map<String, dynamic> _$$CrmLeadImplToJson(_$CrmLeadImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phone': instance.phone,
      'secondaryPhone': instance.secondaryPhone,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'email': instance.email,
      'enquiryAbout': instance.enquiryAbout,
      'status': instance.status,
      'company': instance.company,
      'type': instance.type,
    };
