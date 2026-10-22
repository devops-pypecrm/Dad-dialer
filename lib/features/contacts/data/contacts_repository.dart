import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/device_contact.dart';

part 'contacts_repository.g.dart';

@Riverpod(keepAlive: true)
ContactsRepository contactsRepository(ProviderRef<ContactsRepository> ref) => ContactsRepository();

/// Reads the device's own contacts via `flutter_contacts`
/// (`ContactsContract` under the hood) — search/view/call only, no bulk
/// upload of the address book to the CRM (prompt.md §27).
class ContactsRepository {
  Future<List<DeviceContact>> fetchAll() async {
    final granted = await fc.FlutterContacts.requestPermission(readonly: true);
    if (!granted) return const [];
    final contacts = await fc.FlutterContacts.getContacts(withProperties: true);
    return contacts
        .map(
          (c) => DeviceContact(
            id: c.id,
            displayName: c.displayName,
            phones: c.phones.map((p) => p.number).toList(),
          ),
        )
        .where((c) => c.phones.isNotEmpty)
        .toList();
  }

  /// Saves a dialed number as a new device contact — the "Add Number"
  /// action on the dial pad, only offered for a number that doesn't already
  /// match a device contact or CRM lead. Needs write access, unlike
  /// [fetchAll]'s `readonly: true` request.
  Future<DeviceContact?> addContact({required String name, required String number}) async {
    final granted = await fc.FlutterContacts.requestPermission(readonly: false);
    if (!granted) return null;
    final contact = fc.Contact()
      ..name.first = name
      ..phones = [fc.Phone(number)];
    final inserted = await contact.insert();
    // Use the name we set, not inserted.displayName -- flutter_contacts
    // doesn't guarantee that's populated from the properties we just wrote
    // without a separate re-fetch.
    return DeviceContact(id: inserted.id, displayName: name, phones: [number]);
  }
}
