// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_log_name_preference_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$preferCrmNameInCallLogsHash() =>
    r'9f0b34e1e9cdc6d9f661f92d037cf41ae658f6a7';

/// Whether Call Logs (Recents) shows the CRM lead's name for a matched
/// number instead of the device contact's name. A personal, per-device
/// display preference — not an org policy — so this is stored locally via
/// `shared_preferences` rather than synced through the backend
/// `CallSettings` model.
///
/// - ON (default): CRM lead name if the number matches a CRM lead,
///   otherwise just the raw number — matches this app's original hardcoded
///   Recents behavior, so nothing changes for existing users until they
///   explicitly turn it off. A number that's saved in BOTH the CRM and
///   device contacts (under different names) shows the CRM name.
/// - OFF: the device contact name (`CallLogEntry.cachedName`, sourced from
///   Android's own `CallLog.Calls.CACHED_NAME` — the OS already resolves
///   this against the phone's Contacts, no separate lookup needed here),
///   falling back to the raw number if there's no contact match either.
///   A number saved in both shows the contact name.
///
/// Copied from [PreferCrmNameInCallLogs].
@ProviderFor(PreferCrmNameInCallLogs)
final preferCrmNameInCallLogsProvider =
    AsyncNotifierProvider<PreferCrmNameInCallLogs, bool>.internal(
      PreferCrmNameInCallLogs.new,
      name: r'preferCrmNameInCallLogsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$preferCrmNameInCallLogsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PreferCrmNameInCallLogs = AsyncNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
