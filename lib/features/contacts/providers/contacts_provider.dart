import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/contacts_repository.dart';
import '../domain/device_contact.dart';

part 'contacts_provider.g.dart';

@riverpod
Future<List<DeviceContact>> contactsList(AutoDisposeFutureProviderRef<List<DeviceContact>> ref) =>
    ref.watch(contactsRepositoryProvider).fetchAll();
