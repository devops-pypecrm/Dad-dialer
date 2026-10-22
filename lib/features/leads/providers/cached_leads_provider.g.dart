// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_leads_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cachedLeadsHash() => r'3714f3a9c9a9a57f6efd4c85cf4169a1af14243d';

/// Holds the full CRM lead/contact list fetched from `GET /api/android/leads`
/// and an in-memory `normalizedPhone -> CrmLead` index for O(1) match
/// lookups — the correct replacement for the `dialer-version` branch's
/// `endsWith` suffix-match placeholder (see `phone_normalizer.dart`'s doc
/// comment). `keepAlive: true` because this is genuinely session-scoped
/// data, invalidated on logout by `SessionController`.
///
/// Copied from [CachedLeads].
@ProviderFor(CachedLeads)
final cachedLeadsProvider =
    AsyncNotifierProvider<CachedLeads, List<CrmLead>>.internal(
      CachedLeads.new,
      name: r'cachedLeadsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$cachedLeadsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CachedLeads = AsyncNotifier<List<CrmLead>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
