// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'apk_download_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ApkDownloadState {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
      double progress,
      int receivedBytes,
      int totalBytes,
    )
    downloading,
    required TResult Function(String filePath) permissionNeeded,
    required TResult Function(String filePath) installLaunched,
    required TResult Function(String message, String? filePath) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult? Function(String filePath)? permissionNeeded,
    TResult? Function(String filePath)? installLaunched,
    TResult? Function(String message, String? filePath)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult Function(String filePath)? permissionNeeded,
    TResult Function(String filePath)? installLaunched,
    TResult Function(String message, String? filePath)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ApkDownloadIdle value) idle,
    required TResult Function(ApkDownloadInProgress value) downloading,
    required TResult Function(ApkDownloadPermissionNeeded value)
    permissionNeeded,
    required TResult Function(ApkDownloadInstallLaunched value) installLaunched,
    required TResult Function(ApkDownloadError value) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ApkDownloadIdle value)? idle,
    TResult? Function(ApkDownloadInProgress value)? downloading,
    TResult? Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult? Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult? Function(ApkDownloadError value)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ApkDownloadIdle value)? idle,
    TResult Function(ApkDownloadInProgress value)? downloading,
    TResult Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult Function(ApkDownloadError value)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ApkDownloadStateCopyWith<$Res> {
  factory $ApkDownloadStateCopyWith(
    ApkDownloadState value,
    $Res Function(ApkDownloadState) then,
  ) = _$ApkDownloadStateCopyWithImpl<$Res, ApkDownloadState>;
}

/// @nodoc
class _$ApkDownloadStateCopyWithImpl<$Res, $Val extends ApkDownloadState>
    implements $ApkDownloadStateCopyWith<$Res> {
  _$ApkDownloadStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$ApkDownloadIdleImplCopyWith<$Res> {
  factory _$$ApkDownloadIdleImplCopyWith(
    _$ApkDownloadIdleImpl value,
    $Res Function(_$ApkDownloadIdleImpl) then,
  ) = __$$ApkDownloadIdleImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ApkDownloadIdleImplCopyWithImpl<$Res>
    extends _$ApkDownloadStateCopyWithImpl<$Res, _$ApkDownloadIdleImpl>
    implements _$$ApkDownloadIdleImplCopyWith<$Res> {
  __$$ApkDownloadIdleImplCopyWithImpl(
    _$ApkDownloadIdleImpl _value,
    $Res Function(_$ApkDownloadIdleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ApkDownloadIdleImpl implements ApkDownloadIdle {
  const _$ApkDownloadIdleImpl();

  @override
  String toString() {
    return 'ApkDownloadState.idle()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$ApkDownloadIdleImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
      double progress,
      int receivedBytes,
      int totalBytes,
    )
    downloading,
    required TResult Function(String filePath) permissionNeeded,
    required TResult Function(String filePath) installLaunched,
    required TResult Function(String message, String? filePath) error,
  }) {
    return idle();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult? Function(String filePath)? permissionNeeded,
    TResult? Function(String filePath)? installLaunched,
    TResult? Function(String message, String? filePath)? error,
  }) {
    return idle?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult Function(String filePath)? permissionNeeded,
    TResult Function(String filePath)? installLaunched,
    TResult Function(String message, String? filePath)? error,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ApkDownloadIdle value) idle,
    required TResult Function(ApkDownloadInProgress value) downloading,
    required TResult Function(ApkDownloadPermissionNeeded value)
    permissionNeeded,
    required TResult Function(ApkDownloadInstallLaunched value) installLaunched,
    required TResult Function(ApkDownloadError value) error,
  }) {
    return idle(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ApkDownloadIdle value)? idle,
    TResult? Function(ApkDownloadInProgress value)? downloading,
    TResult? Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult? Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult? Function(ApkDownloadError value)? error,
  }) {
    return idle?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ApkDownloadIdle value)? idle,
    TResult Function(ApkDownloadInProgress value)? downloading,
    TResult Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult Function(ApkDownloadError value)? error,
    required TResult orElse(),
  }) {
    if (idle != null) {
      return idle(this);
    }
    return orElse();
  }
}

abstract class ApkDownloadIdle implements ApkDownloadState {
  const factory ApkDownloadIdle() = _$ApkDownloadIdleImpl;
}

/// @nodoc
abstract class _$$ApkDownloadInProgressImplCopyWith<$Res> {
  factory _$$ApkDownloadInProgressImplCopyWith(
    _$ApkDownloadInProgressImpl value,
    $Res Function(_$ApkDownloadInProgressImpl) then,
  ) = __$$ApkDownloadInProgressImplCopyWithImpl<$Res>;
  @useResult
  $Res call({double progress, int receivedBytes, int totalBytes});
}

/// @nodoc
class __$$ApkDownloadInProgressImplCopyWithImpl<$Res>
    extends _$ApkDownloadStateCopyWithImpl<$Res, _$ApkDownloadInProgressImpl>
    implements _$$ApkDownloadInProgressImplCopyWith<$Res> {
  __$$ApkDownloadInProgressImplCopyWithImpl(
    _$ApkDownloadInProgressImpl _value,
    $Res Function(_$ApkDownloadInProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
    Object? receivedBytes = null,
    Object? totalBytes = null,
  }) {
    return _then(
      _$ApkDownloadInProgressImpl(
        progress: null == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as double,
        receivedBytes: null == receivedBytes
            ? _value.receivedBytes
            : receivedBytes // ignore: cast_nullable_to_non_nullable
                  as int,
        totalBytes: null == totalBytes
            ? _value.totalBytes
            : totalBytes // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$ApkDownloadInProgressImpl implements ApkDownloadInProgress {
  const _$ApkDownloadInProgressImpl({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
  });

  @override
  final double progress;
  @override
  final int receivedBytes;
  @override
  final int totalBytes;

  @override
  String toString() {
    return 'ApkDownloadState.downloading(progress: $progress, receivedBytes: $receivedBytes, totalBytes: $totalBytes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApkDownloadInProgressImpl &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.receivedBytes, receivedBytes) ||
                other.receivedBytes == receivedBytes) &&
            (identical(other.totalBytes, totalBytes) ||
                other.totalBytes == totalBytes));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, progress, receivedBytes, totalBytes);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApkDownloadInProgressImplCopyWith<_$ApkDownloadInProgressImpl>
  get copyWith =>
      __$$ApkDownloadInProgressImplCopyWithImpl<_$ApkDownloadInProgressImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
      double progress,
      int receivedBytes,
      int totalBytes,
    )
    downloading,
    required TResult Function(String filePath) permissionNeeded,
    required TResult Function(String filePath) installLaunched,
    required TResult Function(String message, String? filePath) error,
  }) {
    return downloading(progress, receivedBytes, totalBytes);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult? Function(String filePath)? permissionNeeded,
    TResult? Function(String filePath)? installLaunched,
    TResult? Function(String message, String? filePath)? error,
  }) {
    return downloading?.call(progress, receivedBytes, totalBytes);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult Function(String filePath)? permissionNeeded,
    TResult Function(String filePath)? installLaunched,
    TResult Function(String message, String? filePath)? error,
    required TResult orElse(),
  }) {
    if (downloading != null) {
      return downloading(progress, receivedBytes, totalBytes);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ApkDownloadIdle value) idle,
    required TResult Function(ApkDownloadInProgress value) downloading,
    required TResult Function(ApkDownloadPermissionNeeded value)
    permissionNeeded,
    required TResult Function(ApkDownloadInstallLaunched value) installLaunched,
    required TResult Function(ApkDownloadError value) error,
  }) {
    return downloading(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ApkDownloadIdle value)? idle,
    TResult? Function(ApkDownloadInProgress value)? downloading,
    TResult? Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult? Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult? Function(ApkDownloadError value)? error,
  }) {
    return downloading?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ApkDownloadIdle value)? idle,
    TResult Function(ApkDownloadInProgress value)? downloading,
    TResult Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult Function(ApkDownloadError value)? error,
    required TResult orElse(),
  }) {
    if (downloading != null) {
      return downloading(this);
    }
    return orElse();
  }
}

abstract class ApkDownloadInProgress implements ApkDownloadState {
  const factory ApkDownloadInProgress({
    required final double progress,
    required final int receivedBytes,
    required final int totalBytes,
  }) = _$ApkDownloadInProgressImpl;

  double get progress;
  int get receivedBytes;
  int get totalBytes;

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApkDownloadInProgressImplCopyWith<_$ApkDownloadInProgressImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ApkDownloadPermissionNeededImplCopyWith<$Res> {
  factory _$$ApkDownloadPermissionNeededImplCopyWith(
    _$ApkDownloadPermissionNeededImpl value,
    $Res Function(_$ApkDownloadPermissionNeededImpl) then,
  ) = __$$ApkDownloadPermissionNeededImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String filePath});
}

/// @nodoc
class __$$ApkDownloadPermissionNeededImplCopyWithImpl<$Res>
    extends
        _$ApkDownloadStateCopyWithImpl<$Res, _$ApkDownloadPermissionNeededImpl>
    implements _$$ApkDownloadPermissionNeededImplCopyWith<$Res> {
  __$$ApkDownloadPermissionNeededImplCopyWithImpl(
    _$ApkDownloadPermissionNeededImpl _value,
    $Res Function(_$ApkDownloadPermissionNeededImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? filePath = null}) {
    return _then(
      _$ApkDownloadPermissionNeededImpl(
        filePath: null == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ApkDownloadPermissionNeededImpl implements ApkDownloadPermissionNeeded {
  const _$ApkDownloadPermissionNeededImpl({required this.filePath});

  @override
  final String filePath;

  @override
  String toString() {
    return 'ApkDownloadState.permissionNeeded(filePath: $filePath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApkDownloadPermissionNeededImpl &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath));
  }

  @override
  int get hashCode => Object.hash(runtimeType, filePath);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApkDownloadPermissionNeededImplCopyWith<_$ApkDownloadPermissionNeededImpl>
  get copyWith =>
      __$$ApkDownloadPermissionNeededImplCopyWithImpl<
        _$ApkDownloadPermissionNeededImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
      double progress,
      int receivedBytes,
      int totalBytes,
    )
    downloading,
    required TResult Function(String filePath) permissionNeeded,
    required TResult Function(String filePath) installLaunched,
    required TResult Function(String message, String? filePath) error,
  }) {
    return permissionNeeded(filePath);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult? Function(String filePath)? permissionNeeded,
    TResult? Function(String filePath)? installLaunched,
    TResult? Function(String message, String? filePath)? error,
  }) {
    return permissionNeeded?.call(filePath);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult Function(String filePath)? permissionNeeded,
    TResult Function(String filePath)? installLaunched,
    TResult Function(String message, String? filePath)? error,
    required TResult orElse(),
  }) {
    if (permissionNeeded != null) {
      return permissionNeeded(filePath);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ApkDownloadIdle value) idle,
    required TResult Function(ApkDownloadInProgress value) downloading,
    required TResult Function(ApkDownloadPermissionNeeded value)
    permissionNeeded,
    required TResult Function(ApkDownloadInstallLaunched value) installLaunched,
    required TResult Function(ApkDownloadError value) error,
  }) {
    return permissionNeeded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ApkDownloadIdle value)? idle,
    TResult? Function(ApkDownloadInProgress value)? downloading,
    TResult? Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult? Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult? Function(ApkDownloadError value)? error,
  }) {
    return permissionNeeded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ApkDownloadIdle value)? idle,
    TResult Function(ApkDownloadInProgress value)? downloading,
    TResult Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult Function(ApkDownloadError value)? error,
    required TResult orElse(),
  }) {
    if (permissionNeeded != null) {
      return permissionNeeded(this);
    }
    return orElse();
  }
}

abstract class ApkDownloadPermissionNeeded implements ApkDownloadState {
  const factory ApkDownloadPermissionNeeded({required final String filePath}) =
      _$ApkDownloadPermissionNeededImpl;

  String get filePath;

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApkDownloadPermissionNeededImplCopyWith<_$ApkDownloadPermissionNeededImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ApkDownloadInstallLaunchedImplCopyWith<$Res> {
  factory _$$ApkDownloadInstallLaunchedImplCopyWith(
    _$ApkDownloadInstallLaunchedImpl value,
    $Res Function(_$ApkDownloadInstallLaunchedImpl) then,
  ) = __$$ApkDownloadInstallLaunchedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String filePath});
}

/// @nodoc
class __$$ApkDownloadInstallLaunchedImplCopyWithImpl<$Res>
    extends
        _$ApkDownloadStateCopyWithImpl<$Res, _$ApkDownloadInstallLaunchedImpl>
    implements _$$ApkDownloadInstallLaunchedImplCopyWith<$Res> {
  __$$ApkDownloadInstallLaunchedImplCopyWithImpl(
    _$ApkDownloadInstallLaunchedImpl _value,
    $Res Function(_$ApkDownloadInstallLaunchedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? filePath = null}) {
    return _then(
      _$ApkDownloadInstallLaunchedImpl(
        filePath: null == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ApkDownloadInstallLaunchedImpl implements ApkDownloadInstallLaunched {
  const _$ApkDownloadInstallLaunchedImpl({required this.filePath});

  @override
  final String filePath;

  @override
  String toString() {
    return 'ApkDownloadState.installLaunched(filePath: $filePath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApkDownloadInstallLaunchedImpl &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath));
  }

  @override
  int get hashCode => Object.hash(runtimeType, filePath);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApkDownloadInstallLaunchedImplCopyWith<_$ApkDownloadInstallLaunchedImpl>
  get copyWith =>
      __$$ApkDownloadInstallLaunchedImplCopyWithImpl<
        _$ApkDownloadInstallLaunchedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
      double progress,
      int receivedBytes,
      int totalBytes,
    )
    downloading,
    required TResult Function(String filePath) permissionNeeded,
    required TResult Function(String filePath) installLaunched,
    required TResult Function(String message, String? filePath) error,
  }) {
    return installLaunched(filePath);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult? Function(String filePath)? permissionNeeded,
    TResult? Function(String filePath)? installLaunched,
    TResult? Function(String message, String? filePath)? error,
  }) {
    return installLaunched?.call(filePath);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult Function(String filePath)? permissionNeeded,
    TResult Function(String filePath)? installLaunched,
    TResult Function(String message, String? filePath)? error,
    required TResult orElse(),
  }) {
    if (installLaunched != null) {
      return installLaunched(filePath);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ApkDownloadIdle value) idle,
    required TResult Function(ApkDownloadInProgress value) downloading,
    required TResult Function(ApkDownloadPermissionNeeded value)
    permissionNeeded,
    required TResult Function(ApkDownloadInstallLaunched value) installLaunched,
    required TResult Function(ApkDownloadError value) error,
  }) {
    return installLaunched(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ApkDownloadIdle value)? idle,
    TResult? Function(ApkDownloadInProgress value)? downloading,
    TResult? Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult? Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult? Function(ApkDownloadError value)? error,
  }) {
    return installLaunched?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ApkDownloadIdle value)? idle,
    TResult Function(ApkDownloadInProgress value)? downloading,
    TResult Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult Function(ApkDownloadError value)? error,
    required TResult orElse(),
  }) {
    if (installLaunched != null) {
      return installLaunched(this);
    }
    return orElse();
  }
}

abstract class ApkDownloadInstallLaunched implements ApkDownloadState {
  const factory ApkDownloadInstallLaunched({required final String filePath}) =
      _$ApkDownloadInstallLaunchedImpl;

  String get filePath;

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApkDownloadInstallLaunchedImplCopyWith<_$ApkDownloadInstallLaunchedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ApkDownloadErrorImplCopyWith<$Res> {
  factory _$$ApkDownloadErrorImplCopyWith(
    _$ApkDownloadErrorImpl value,
    $Res Function(_$ApkDownloadErrorImpl) then,
  ) = __$$ApkDownloadErrorImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String message, String? filePath});
}

/// @nodoc
class __$$ApkDownloadErrorImplCopyWithImpl<$Res>
    extends _$ApkDownloadStateCopyWithImpl<$Res, _$ApkDownloadErrorImpl>
    implements _$$ApkDownloadErrorImplCopyWith<$Res> {
  __$$ApkDownloadErrorImplCopyWithImpl(
    _$ApkDownloadErrorImpl _value,
    $Res Function(_$ApkDownloadErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null, Object? filePath = freezed}) {
    return _then(
      _$ApkDownloadErrorImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        filePath: freezed == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$ApkDownloadErrorImpl implements ApkDownloadError {
  const _$ApkDownloadErrorImpl({required this.message, this.filePath});

  @override
  final String message;
  @override
  final String? filePath;

  @override
  String toString() {
    return 'ApkDownloadState.error(message: $message, filePath: $filePath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ApkDownloadErrorImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message, filePath);

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ApkDownloadErrorImplCopyWith<_$ApkDownloadErrorImpl> get copyWith =>
      __$$ApkDownloadErrorImplCopyWithImpl<_$ApkDownloadErrorImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() idle,
    required TResult Function(
      double progress,
      int receivedBytes,
      int totalBytes,
    )
    downloading,
    required TResult Function(String filePath) permissionNeeded,
    required TResult Function(String filePath) installLaunched,
    required TResult Function(String message, String? filePath) error,
  }) {
    return error(message, filePath);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? idle,
    TResult? Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult? Function(String filePath)? permissionNeeded,
    TResult? Function(String filePath)? installLaunched,
    TResult? Function(String message, String? filePath)? error,
  }) {
    return error?.call(message, filePath);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? idle,
    TResult Function(double progress, int receivedBytes, int totalBytes)?
    downloading,
    TResult Function(String filePath)? permissionNeeded,
    TResult Function(String filePath)? installLaunched,
    TResult Function(String message, String? filePath)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(message, filePath);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ApkDownloadIdle value) idle,
    required TResult Function(ApkDownloadInProgress value) downloading,
    required TResult Function(ApkDownloadPermissionNeeded value)
    permissionNeeded,
    required TResult Function(ApkDownloadInstallLaunched value) installLaunched,
    required TResult Function(ApkDownloadError value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ApkDownloadIdle value)? idle,
    TResult? Function(ApkDownloadInProgress value)? downloading,
    TResult? Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult? Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult? Function(ApkDownloadError value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ApkDownloadIdle value)? idle,
    TResult Function(ApkDownloadInProgress value)? downloading,
    TResult Function(ApkDownloadPermissionNeeded value)? permissionNeeded,
    TResult Function(ApkDownloadInstallLaunched value)? installLaunched,
    TResult Function(ApkDownloadError value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class ApkDownloadError implements ApkDownloadState {
  const factory ApkDownloadError({
    required final String message,
    final String? filePath,
  }) = _$ApkDownloadErrorImpl;

  String get message;
  String? get filePath;

  /// Create a copy of ApkDownloadState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ApkDownloadErrorImplCopyWith<_$ApkDownloadErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
