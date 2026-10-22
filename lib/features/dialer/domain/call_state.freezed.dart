// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'call_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ActiveCall {
  TelecomCallState get state => throw _privateConstructorUsedError;
  String? get number => throw _privateConstructorUsedError;
  bool get isIncoming => throw _privateConstructorUsedError;

  /// Create a copy of ActiveCall
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ActiveCallCopyWith<ActiveCall> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActiveCallCopyWith<$Res> {
  factory $ActiveCallCopyWith(
    ActiveCall value,
    $Res Function(ActiveCall) then,
  ) = _$ActiveCallCopyWithImpl<$Res, ActiveCall>;
  @useResult
  $Res call({TelecomCallState state, String? number, bool isIncoming});
}

/// @nodoc
class _$ActiveCallCopyWithImpl<$Res, $Val extends ActiveCall>
    implements $ActiveCallCopyWith<$Res> {
  _$ActiveCallCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ActiveCall
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? number = freezed,
    Object? isIncoming = null,
  }) {
    return _then(
      _value.copyWith(
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as TelecomCallState,
            number: freezed == number
                ? _value.number
                : number // ignore: cast_nullable_to_non_nullable
                      as String?,
            isIncoming: null == isIncoming
                ? _value.isIncoming
                : isIncoming // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ActiveCallImplCopyWith<$Res>
    implements $ActiveCallCopyWith<$Res> {
  factory _$$ActiveCallImplCopyWith(
    _$ActiveCallImpl value,
    $Res Function(_$ActiveCallImpl) then,
  ) = __$$ActiveCallImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({TelecomCallState state, String? number, bool isIncoming});
}

/// @nodoc
class __$$ActiveCallImplCopyWithImpl<$Res>
    extends _$ActiveCallCopyWithImpl<$Res, _$ActiveCallImpl>
    implements _$$ActiveCallImplCopyWith<$Res> {
  __$$ActiveCallImplCopyWithImpl(
    _$ActiveCallImpl _value,
    $Res Function(_$ActiveCallImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ActiveCall
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? state = null,
    Object? number = freezed,
    Object? isIncoming = null,
  }) {
    return _then(
      _$ActiveCallImpl(
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as TelecomCallState,
        number: freezed == number
            ? _value.number
            : number // ignore: cast_nullable_to_non_nullable
                  as String?,
        isIncoming: null == isIncoming
            ? _value.isIncoming
            : isIncoming // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ActiveCallImpl extends _ActiveCall {
  const _$ActiveCallImpl({
    required this.state,
    this.number,
    this.isIncoming = false,
  }) : super._();

  @override
  final TelecomCallState state;
  @override
  final String? number;
  @override
  @JsonKey()
  final bool isIncoming;

  @override
  String toString() {
    return 'ActiveCall(state: $state, number: $number, isIncoming: $isIncoming)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActiveCallImpl &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.number, number) || other.number == number) &&
            (identical(other.isIncoming, isIncoming) ||
                other.isIncoming == isIncoming));
  }

  @override
  int get hashCode => Object.hash(runtimeType, state, number, isIncoming);

  /// Create a copy of ActiveCall
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ActiveCallImplCopyWith<_$ActiveCallImpl> get copyWith =>
      __$$ActiveCallImplCopyWithImpl<_$ActiveCallImpl>(this, _$identity);
}

abstract class _ActiveCall extends ActiveCall {
  const factory _ActiveCall({
    required final TelecomCallState state,
    final String? number,
    final bool isIncoming,
  }) = _$ActiveCallImpl;
  const _ActiveCall._() : super._();

  @override
  TelecomCallState get state;
  @override
  String? get number;
  @override
  bool get isIncoming;

  /// Create a copy of ActiveCall
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ActiveCallImplCopyWith<_$ActiveCallImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
