import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/call_settings_repository.dart';
import '../domain/call_settings.dart';

part 'call_settings_provider.g.dart';

@riverpod
Future<CallSettings> callSettings(AutoDisposeFutureProviderRef<CallSettings> ref) =>
    ref.watch(callSettingsRepositoryProvider).fetch();
