// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'favorite_contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FavoriteContact _$FavoriteContactFromJson(Map<String, dynamic> json) {
  return _FavoriteContact.fromJson(json);
}

/// @nodoc
mixin _$FavoriteContact {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String get number => throw _privateConstructorUsedError;
  String? get sourceContactId => throw _privateConstructorUsedError;

  /// Serializes this FavoriteContact to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FavoriteContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FavoriteContactCopyWith<FavoriteContact> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FavoriteContactCopyWith<$Res> {
  factory $FavoriteContactCopyWith(
    FavoriteContact value,
    $Res Function(FavoriteContact) then,
  ) = _$FavoriteContactCopyWithImpl<$Res, FavoriteContact>;
  @useResult
  $Res call({
    String id,
    String displayName,
    String number,
    String? sourceContactId,
  });
}

/// @nodoc
class _$FavoriteContactCopyWithImpl<$Res, $Val extends FavoriteContact>
    implements $FavoriteContactCopyWith<$Res> {
  _$FavoriteContactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FavoriteContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? number = null,
    Object? sourceContactId = freezed,
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
            number: null == number
                ? _value.number
                : number // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceContactId: freezed == sourceContactId
                ? _value.sourceContactId
                : sourceContactId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FavoriteContactImplCopyWith<$Res>
    implements $FavoriteContactCopyWith<$Res> {
  factory _$$FavoriteContactImplCopyWith(
    _$FavoriteContactImpl value,
    $Res Function(_$FavoriteContactImpl) then,
  ) = __$$FavoriteContactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String number,
    String? sourceContactId,
  });
}

/// @nodoc
class __$$FavoriteContactImplCopyWithImpl<$Res>
    extends _$FavoriteContactCopyWithImpl<$Res, _$FavoriteContactImpl>
    implements _$$FavoriteContactImplCopyWith<$Res> {
  __$$FavoriteContactImplCopyWithImpl(
    _$FavoriteContactImpl _value,
    $Res Function(_$FavoriteContactImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FavoriteContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? number = null,
    Object? sourceContactId = freezed,
  }) {
    return _then(
      _$FavoriteContactImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        number: null == number
            ? _value.number
            : number // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceContactId: freezed == sourceContactId
            ? _value.sourceContactId
            : sourceContactId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FavoriteContactImpl implements _FavoriteContact {
  const _$FavoriteContactImpl({
    required this.id,
    required this.displayName,
    required this.number,
    this.sourceContactId,
  });

  factory _$FavoriteContactImpl.fromJson(Map<String, dynamic> json) =>
      _$$FavoriteContactImplFromJson(json);

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String number;
  @override
  final String? sourceContactId;

  @override
  String toString() {
    return 'FavoriteContact(id: $id, displayName: $displayName, number: $number, sourceContactId: $sourceContactId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FavoriteContactImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.number, number) || other.number == number) &&
            (identical(other.sourceContactId, sourceContactId) ||
                other.sourceContactId == sourceContactId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, displayName, number, sourceContactId);

  /// Create a copy of FavoriteContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FavoriteContactImplCopyWith<_$FavoriteContactImpl> get copyWith =>
      __$$FavoriteContactImplCopyWithImpl<_$FavoriteContactImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FavoriteContactImplToJson(this);
  }
}

abstract class _FavoriteContact implements FavoriteContact {
  const factory _FavoriteContact({
    required final String id,
    required final String displayName,
    required final String number,
    final String? sourceContactId,
  }) = _$FavoriteContactImpl;

  factory _FavoriteContact.fromJson(Map<String, dynamic> json) =
      _$FavoriteContactImpl.fromJson;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String get number;
  @override
  String? get sourceContactId;

  /// Create a copy of FavoriteContact
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FavoriteContactImplCopyWith<_$FavoriteContactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
