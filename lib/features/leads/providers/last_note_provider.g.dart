// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'last_note_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lastNoteHash() => r'166b386ec2b88bee17ade5fc15336b80c63c9fed';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Fetches a single lead's most recent note on demand -- `autoDispose`
/// since this is only relevant for as long as a specific incoming-call
/// screen showing that lead is on screen, not something to keep cached
/// indefinitely per lead the way [cachedLeadsProvider] does for the whole
/// lead list.
///
/// Copied from [lastNote].
@ProviderFor(lastNote)
const lastNoteProvider = LastNoteFamily();

/// Fetches a single lead's most recent note on demand -- `autoDispose`
/// since this is only relevant for as long as a specific incoming-call
/// screen showing that lead is on screen, not something to keep cached
/// indefinitely per lead the way [cachedLeadsProvider] does for the whole
/// lead list.
///
/// Copied from [lastNote].
class LastNoteFamily extends Family<AsyncValue<String?>> {
  /// Fetches a single lead's most recent note on demand -- `autoDispose`
  /// since this is only relevant for as long as a specific incoming-call
  /// screen showing that lead is on screen, not something to keep cached
  /// indefinitely per lead the way [cachedLeadsProvider] does for the whole
  /// lead list.
  ///
  /// Copied from [lastNote].
  const LastNoteFamily();

  /// Fetches a single lead's most recent note on demand -- `autoDispose`
  /// since this is only relevant for as long as a specific incoming-call
  /// screen showing that lead is on screen, not something to keep cached
  /// indefinitely per lead the way [cachedLeadsProvider] does for the whole
  /// lead list.
  ///
  /// Copied from [lastNote].
  LastNoteProvider call(String leadId) {
    return LastNoteProvider(leadId);
  }

  @override
  LastNoteProvider getProviderOverride(covariant LastNoteProvider provider) {
    return call(provider.leadId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'lastNoteProvider';
}

/// Fetches a single lead's most recent note on demand -- `autoDispose`
/// since this is only relevant for as long as a specific incoming-call
/// screen showing that lead is on screen, not something to keep cached
/// indefinitely per lead the way [cachedLeadsProvider] does for the whole
/// lead list.
///
/// Copied from [lastNote].
class LastNoteProvider extends AutoDisposeFutureProvider<String?> {
  /// Fetches a single lead's most recent note on demand -- `autoDispose`
  /// since this is only relevant for as long as a specific incoming-call
  /// screen showing that lead is on screen, not something to keep cached
  /// indefinitely per lead the way [cachedLeadsProvider] does for the whole
  /// lead list.
  ///
  /// Copied from [lastNote].
  LastNoteProvider(String leadId)
    : this._internal(
        (ref) => lastNote(ref as LastNoteRef, leadId),
        from: lastNoteProvider,
        name: r'lastNoteProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$lastNoteHash,
        dependencies: LastNoteFamily._dependencies,
        allTransitiveDependencies: LastNoteFamily._allTransitiveDependencies,
        leadId: leadId,
      );

  LastNoteProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.leadId,
  }) : super.internal();

  final String leadId;

  @override
  Override overrideWith(
    FutureOr<String?> Function(LastNoteRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LastNoteProvider._internal(
        (ref) => create(ref as LastNoteRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        leadId: leadId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _LastNoteProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LastNoteProvider && other.leadId == leadId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, leadId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LastNoteRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `leadId` of this provider.
  String get leadId;
}

class _LastNoteProviderElement extends AutoDisposeFutureProviderElement<String?>
    with LastNoteRef {
  _LastNoteProviderElement(super.provider);

  @override
  String get leadId => (origin as LastNoteProvider).leadId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
