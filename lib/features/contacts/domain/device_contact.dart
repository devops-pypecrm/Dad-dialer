import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_contact.freezed.dart';

@freezed
class DeviceContact with _$DeviceContact {
  const factory DeviceContact({
    required String id,
    required String displayName,
    required List<String> phones,
  }) = _DeviceContact;
}
