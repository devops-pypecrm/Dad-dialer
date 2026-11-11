import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/presentation/widgets/contact_action_card.dart';
import '../../../dialer/data/telecom_bridge.dart';
import '../../../dialer/providers/call_guard.dart';
import '../../../leads/providers/cached_leads_provider.dart';
import '../../domain/favorite_contact.dart';
import '../../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return favoritesAsync.when(
      data: (favorites) => favorites.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No favorites yet. Tap the star on a contact to add it here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: favorites.length,
              itemBuilder: (context, index) => _FavoriteTile(favorite: favorites[index]),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load favorites: $error')),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.favorite});

  final FavoriteContact favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchedLead = ref.read(cachedLeadsProvider.notifier).matchLead(favorite.number);

    return ContactActionCard(
      displayName: favorite.displayName,
      number: favorite.number,
      // Every row here already IS a favorite — the star badge is always
      // filled, and tapping it removes rather than toggles.
      isFavorite: true,
      matchedLead: matchedLead,
      onToggleFavorite: () => ref.read(favoritesProvider.notifier).remove(favorite.id),
      onCall: () async {
        if (!await ensureCanPlaceCall(ref, context)) return;
        await ref.read(telecomBridgeProvider).placeCall(favorite.number);
      },
    );
  }
}
