// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'call_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CallSettings _$CallSettingsFromJson(Map<String, dynamic> json) {
  return _CallSettings.fromJson(json);
}

/// @nodoc
mixin _$CallSettings {
  bool get popupOnIncoming => throw _privateConstructorUsedError;

  /// Serializes this CallSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CallSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CallSettingsCopyWith<CallSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CallSettingsCopyWith<$Res> {
  factory $CallSettingsCopyWith(
    CallSettings value,
    $Res Function(CallSettings) then,
  ) = _$CallSettingsCopyWithImpl<$Res, CallSettings>;
  @useResult
  $Res call({bool popupOnIncoming});
}

/// @nodoc
class _$CallSettingsCopyWithImpl<$Res, $Val extends CallSettings>
    implements $CallSettingsCopyWith<$Res> {
  _$CallSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CallSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? popupOnIncoming = null}) {
    return _then(
      _value.copyWith(
            popupOnIncoming: null == popupOnIncoming
                ? _value.popupOnIncoming
                : popupOnIncoming // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CallSettingsImplCopyWith<$Res>
    implements $CallSettingsCopyWith<$Res> {
  factory _$$CallSettingsImplCopyWith(
    _$CallSettingsImpl value,
    $Res Function(_$CallSettingsImpl) then,
  ) = __$$CallSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool popupOnIncoming});
}

/// @nodoc
class __$$CallSettingsImplCopyWithImpl<$Res>
    extends _$CallSettingsCopyWithImpl<$Res, _$CallSettingsImpl>
    implements _$$CallSettingsImplCopyWith<$Res> {
  __$$CallSettingsImplCopyWithImpl(
    _$CallSettingsImpl _value,
    $Res Function(_$CallSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CallSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? popupOnIncoming = null}) {
    return _then(
      _$CallSettingsImpl(
        popupOnIncoming: null == popupOnIncoming
            ? _value.popupOnIncoming
            : popupOnIncoming // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CallSettingsImpl implements _CallSettings {
  const _$CallSettingsImpl({this.popupOnIncoming = true});

  factory _$CallSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$CallSettingsImplFromJson(json);

  @override
  @JsonKey()
  final bool popupOnIncoming;

  @override
  String toString() {
    return 'CallSettings(popupOnIncoming: $popupOnIncoming)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CallSettingsImpl &&
            (identical(other.popupOnIncoming, popupOnIncoming) ||
                other.popupOnIncoming == popupOnIncoming));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, popupOnIncoming);

  /// Create a copy of CallSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CallSettingsImplCopyWith<_$CallSettingsImpl> get copyWith =>
      __$$CallSettingsImplCopyWithImpl<_$CallSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CallSettingsImplToJson(this);
  }
}

abstract class _CallSettings implements CallSettings {
  const factory _CallSettings({final bool popupOnIncoming}) =
      _$CallSettingsImpl;

  factory _CallSettings.fromJson(Map<String, dynamic> json) =
      _$CallSettingsImpl.fromJson;

  @override
  bool get popupOnIncoming;

  /// Create a copy of CallSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CallSettingsImplCopyWith<_$CallSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
