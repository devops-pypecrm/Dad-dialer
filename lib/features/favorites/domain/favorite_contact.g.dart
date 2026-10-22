// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_contact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FavoriteContactImpl _$$FavoriteContactImplFromJson(
  Map<String, dynamic> json,
) => _$FavoriteContactImpl(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  number: json['number'] as String,
  sourceContactId: json['sourceContactId'] as String?,
);

Map<String, dynamic> _$$FavoriteContactImplToJson(
  _$FavoriteContactImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'number': instance.number,
  'sourceContactId': instance.sourceContactId,
};
