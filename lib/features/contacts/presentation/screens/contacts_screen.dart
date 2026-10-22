import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../dialer/data/telecom_bridge.dart';
import '../../../dialer/providers/call_guard.dart';
import '../../../favorites/domain/favorite_contact.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../leads/providers/cached_leads_provider.dart';
import '../../domain/device_contact.dart';
import '../../providers/contacts_provider.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search contacts',
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
        ),
        Expanded(
          child: contactsAsync.when(
            data: (contacts) {
              final filtered = _query.isEmpty
                  ? contacts
                  : contacts
                      .where(
                        (c) => c.displayName.toLowerCase().contains(_query) ||
                            c.phones.any((p) => p.contains(_query)),
                      )
                      .toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No contacts found.'));
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) => _ContactTile(contact: filtered[index]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Could not load contacts: $error')),
          ),
        ),
      ],
    );
  }
}

class _ContactTile extends ConsumerWidget {
  const _ContactTile({required this.contact});

  final DeviceContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = contact.phones.first;
    final matchedLead = ref.read(cachedLeadsProvider.notifier).matchLead(number);
    // Watch the actual state (not .notifier) so toggling elsewhere rebuilds
    // this tile's star icon.
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const [];
    final isFavorite = favorites.any((f) => f.id == contact.id);

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(contact.displayName),
      subtitle: Text(matchedLead != null ? 'CRM: ${matchedLead.status ?? 'Lead'}' : number),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? kBrandColor : null,
            ),
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () => ref.read(favoritesProvider.notifier).toggle(
                  FavoriteContact(
                    id: contact.id,
                    displayName: contact.displayName,
                    number: number,
                    sourceContactId: contact.id,
                  ),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () async {
              if (!await ensureCanPlaceCall(ref, context)) return;
              await ref.read(telecomBridgeProvider).placeCall(number);
            },
          ),
        ],
      ),
    );
  }
}
