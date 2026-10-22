// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DeviceContact {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  List<String> get phones => throw _privateConstructorUsedError;

  /// Create a copy of DeviceContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceContactCopyWith<DeviceContact> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceContactCopyWith<$Res> {
  factory $DeviceContactCopyWith(
    DeviceContact value,
    $Res Function(DeviceContact) then,
  ) = _$DeviceContactCopyWithImpl<$Res, DeviceContact>;
  @useResult
  $Res call({String id, String displayName, List<String> phones});
}

/// @nodoc
class _$DeviceContactCopyWithImpl<$Res, $Val extends DeviceContact>
    implements $DeviceContactCopyWith<$Res> {
  _$DeviceContactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? phones = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            phones: null == phones
                ? _value.phones
                : phones // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeviceContactImplCopyWith<$Res>
    implements $DeviceContactCopyWith<$Res> {
  factory _$$DeviceContactImplCopyWith(
    _$DeviceContactImpl value,
    $Res Function(_$DeviceContactImpl) then,
  ) = __$$DeviceContactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String displayName, List<String> phones});
}

/// @nodoc
class __$$DeviceContactImplCopyWithImpl<$Res>
    extends _$DeviceContactCopyWithImpl<$Res, _$DeviceContactImpl>
    implements _$$DeviceContactImplCopyWith<$Res> {
  __$$DeviceContactImplCopyWithImpl(
    _$DeviceContactImpl _value,
    $Res Function(_$DeviceContactImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DeviceContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? phones = null,
  }) {
    return _then(
      _$DeviceContactImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        phones: null == phones
            ? _value._phones
            : phones // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$DeviceContactImpl implements _DeviceContact {
  const _$DeviceContactImpl({
    required this.id,
    required this.displayName,
    required final List<String> phones,
  }) : _phones = phones;

  @override
  final String id;
  @override
  final String displayName;
  final List<String> _phones;
  @override
  List<String> get phones {
    if (_phones is EqualUnmodifiableListView) return _phones;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_phones);
  }

  @override
  String toString() {
    return 'DeviceContact(id: $id, displayName: $displayName, phones: $phones)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceContactImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            const DeepCollectionEquality().equals(other._phones, _phones));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    displayName,
    const DeepCollectionEquality().hash(_phones),
  );

  /// Create a copy of DeviceContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceContactImplCopyWith<_$DeviceContactImpl> get copyWith =>
      __$$DeviceContactImplCopyWithImpl<_$DeviceContactImpl>(this, _$identity);
}

abstract class _DeviceContact implements DeviceContact {
  const factory _DeviceContact({
    required final String id,
    required final String displayName,
    required final List<String> phones,
  }) = _$DeviceContactImpl;

  @override
  String get id;
  @override
  String get displayName;
  @override
  List<String> get phones;

  /// Create a copy of DeviceContact
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceContactImplCopyWith<_$DeviceContactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
