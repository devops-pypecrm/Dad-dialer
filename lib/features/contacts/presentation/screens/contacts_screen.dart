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
import '../widgets/contact_action_card.dart';

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
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search contacts',
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
        ),
        if (favorites.isNotEmpty && _query.isEmpty) _FavoritesQuickRow(favorites: favorites),
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
                padding: const EdgeInsets.only(top: 8, bottom: 12),
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

/// Horizontal scroller of favorite avatars above the contact list — the
/// reference app's "favorites quick row" on its Contacts screen. Tapping
/// an avatar calls that favorite directly (the fastest path, matching the
/// reference's own single-tap-to-call behavior on this row).
class _FavoritesQuickRow extends ConsumerWidget {
  const _FavoritesQuickRow({required this.favorites});

  final List<FavoriteContact> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final favorite = favorites[index];
          final initial = favorite.displayName.trim().isNotEmpty ? favorite.displayName.trim()[0].toUpperCase() : '#';
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () async {
                if (!await ensureCanPlaceCall(ref, context)) return;
                await ref.read(telecomBridgeProvider).placeCall(favorite.number);
              },
              child: SizedBox(
                width: 56,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kBrandColor, width: 2)),
                      padding: const EdgeInsets.all(3),
                      child: CircleAvatar(
                        backgroundColor: scheme.surfaceContainerHigh,
                        child: Text(initial, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      favorite.displayName,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
    // this tile's star badge.
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const [];
    final isFavorite = favorites.any((f) => f.id == contact.id);

    return ContactActionCard(
      displayName: contact.displayName,
      number: number,
      isFavorite: isFavorite,
      matchedLead: matchedLead,
      onToggleFavorite: () => ref.read(favoritesProvider.notifier).toggle(
            FavoriteContact(
              id: contact.id,
              displayName: contact.displayName,
              number: number,
              sourceContactId: contact.id,
            ),
          ),
      onCall: () async {
        if (!await ensureCanPlaceCall(ref, context)) return;
        await ref.read(telecomBridgeProvider).placeCall(number);
      },
    );
  }
}
