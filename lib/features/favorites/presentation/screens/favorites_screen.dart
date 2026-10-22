import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
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
          : ListView.separated(
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
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

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(favorite.displayName),
      subtitle: Text(matchedLead != null ? 'CRM: ${matchedLead.status ?? 'Lead'}' : favorite.number),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.star, color: kBrandColor),
            tooltip: 'Remove from favorites',
            onPressed: () => ref.read(favoritesProvider.notifier).remove(favorite.id),
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () async {
              if (!await ensureCanPlaceCall(ref, context)) return;
              await ref.read(telecomBridgeProvider).placeCall(favorite.number);
            },
          ),
        ],
      ),
    );
  }
}
