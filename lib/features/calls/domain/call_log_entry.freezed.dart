// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'call_log_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CallLogEntry {
  String get id => throw _privateConstructorUsedError;
  String? get number => throw _privateConstructorUsedError;
  String? get cachedName => throw _privateConstructorUsedError;
  CallLogType get type => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  int get durationSeconds =>
      throw _privateConstructorUsedError; // Real Telecom-framework data (see CallLogReader.kt) — null on a
  // single-SIM device, or for any call this couldn't resolve to a known
  // phone account. Never a fabricated default.
  int? get simSlot => throw _privateConstructorUsedError;
  String? get simLabel => throw _privateConstructorUsedError;

  /// Create a copy of CallLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CallLogEntryCopyWith<CallLogEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CallLogEntryCopyWith<$Res> {
  factory $CallLogEntryCopyWith(
    CallLogEntry value,
    $Res Function(CallLogEntry) then,
  ) = _$CallLogEntryCopyWithImpl<$Res, CallLogEntry>;
  @useResult
  $Res call({
    String id,
    String? number,
    String? cachedName,
    CallLogType type,
    DateTime date,
    int durationSeconds,
    int? simSlot,
    String? simLabel,
  });
}

/// @nodoc
class _$CallLogEntryCopyWithImpl<$Res, $Val extends CallLogEntry>
    implements $CallLogEntryCopyWith<$Res> {
  _$CallLogEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CallLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? number = freezed,
    Object? cachedName = freezed,
    Object? type = null,
    Object? date = null,
    Object? durationSeconds = null,
    Object? simSlot = freezed,
    Object? simLabel = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            number: freezed == number
                ? _value.number
                : number // ignore: cast_nullable_to_non_nullable
                      as String?,
            cachedName: freezed == cachedName
                ? _value.cachedName
                : cachedName // ignore: cast_nullable_to_non_nullable
                      as String?,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as CallLogType,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            durationSeconds: null == durationSeconds
                ? _value.durationSeconds
                : durationSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
            simSlot: freezed == simSlot
                ? _value.simSlot
                : simSlot // ignore: cast_nullable_to_non_nullable
                      as int?,
            simLabel: freezed == simLabel
                ? _value.simLabel
                : simLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CallLogEntryImplCopyWith<$Res>
    implements $CallLogEntryCopyWith<$Res> {
  factory _$$CallLogEntryImplCopyWith(
    _$CallLogEntryImpl value,
    $Res Function(_$CallLogEntryImpl) then,
  ) = __$$CallLogEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? number,
    String? cachedName,
    CallLogType type,
    DateTime date,
    int durationSeconds,
    int? simSlot,
    String? simLabel,
  });
}

/// @nodoc
class __$$CallLogEntryImplCopyWithImpl<$Res>
    extends _$CallLogEntryCopyWithImpl<$Res, _$CallLogEntryImpl>
    implements _$$CallLogEntryImplCopyWith<$Res> {
  __$$CallLogEntryImplCopyWithImpl(
    _$CallLogEntryImpl _value,
    $Res Function(_$CallLogEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CallLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? number = freezed,
    Object? cachedName = freezed,
    Object? type = null,
    Object? date = null,
    Object? durationSeconds = null,
    Object? simSlot = freezed,
    Object? simLabel = freezed,
  }) {
    return _then(
      _$CallLogEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        number: freezed == number
            ? _value.number
            : number // ignore: cast_nullable_to_non_nullable
                  as String?,
        cachedName: freezed == cachedName
            ? _value.cachedName
            : cachedName // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as CallLogType,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        durationSeconds: null == durationSeconds
            ? _value.durationSeconds
            : durationSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
        simSlot: freezed == simSlot
            ? _value.simSlot
            : simSlot // ignore: cast_nullable_to_non_nullable
                  as int?,
        simLabel: freezed == simLabel
            ? _value.simLabel
            : simLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$CallLogEntryImpl implements _CallLogEntry {
  const _$CallLogEntryImpl({
    required this.id,
    this.number,
    this.cachedName,
    required this.type,
    required this.date,
    required this.durationSeconds,
    this.simSlot,
    this.simLabel,
  });

  @override
  final String id;
  @override
  final String? number;
  @override
  final String? cachedName;
  @override
  final CallLogType type;
  @override
  final DateTime date;
  @override
  final int durationSeconds;
  // Real Telecom-framework data (see CallLogReader.kt) — null on a
  // single-SIM device, or for any call this couldn't resolve to a known
  // phone account. Never a fabricated default.
  @override
  final int? simSlot;
  @override
  final String? simLabel;

  @override
  String toString() {
    return 'CallLogEntry(id: $id, number: $number, cachedName: $cachedName, type: $type, date: $date, durationSeconds: $durationSeconds, simSlot: $simSlot, simLabel: $simLabel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CallLogEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.number, number) || other.number == number) &&
            (identical(other.cachedName, cachedName) ||
                other.cachedName == cachedName) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.durationSeconds, durationSeconds) ||
                other.durationSeconds == durationSeconds) &&
            (identical(other.simSlot, simSlot) || other.simSlot == simSlot) &&
            (identical(other.simLabel, simLabel) ||
                other.simLabel == simLabel));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    number,
    cachedName,
    type,
    date,
    durationSeconds,
    simSlot,
    simLabel,
  );

  /// Create a copy of CallLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CallLogEntryImplCopyWith<_$CallLogEntryImpl> get copyWith =>
      __$$CallLogEntryImplCopyWithImpl<_$CallLogEntryImpl>(this, _$identity);
}

abstract class _CallLogEntry implements CallLogEntry {
  const factory _CallLogEntry({
    required final String id,
    final String? number,
    final String? cachedName,
    required final CallLogType type,
    required final DateTime date,
    required final int durationSeconds,
    final int? simSlot,
    final String? simLabel,
  }) = _$CallLogEntryImpl;

  @override
  String get id;
  @override
  String? get number;
  @override
  String? get cachedName;
  @override
  CallLogType get type;
  @override
  DateTime get date;
  @override
  int get durationSeconds; // Real Telecom-framework data (see CallLogReader.kt) — null on a
  // single-SIM device, or for any call this couldn't resolve to a known
  // phone account. Never a fabricated default.
  @override
  int? get simSlot;
  @override
  String? get simLabel;

  /// Create a copy of CallLogEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CallLogEntryImplCopyWith<_$CallLogEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
