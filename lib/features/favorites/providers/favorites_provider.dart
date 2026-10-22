import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/favorites_repository.dart';
import '../domain/favorite_contact.dart';

part 'favorites_provider.g.dart';

@Riverpod(keepAlive: true)
class Favorites extends _$Favorites {
  @override
  Future<List<FavoriteContact>> build() => ref.watch(favoritesRepositoryProvider).loadAll();

  bool isFavorite(String id) => (state.valueOrNull ?? const []).any((f) => f.id == id);

  Future<void> toggle(FavoriteContact contact) async {
    final current = state.valueOrNull ?? const [];
    final isCurrentlyFavorite = current.any((f) => f.id == contact.id);
    final updated = isCurrentlyFavorite
        ? current.where((f) => f.id != contact.id).toList()
        : [...current, contact];
    state = AsyncValue.data(updated);
    await ref.read(favoritesRepositoryProvider).saveAll(updated);
  }

  Future<void> remove(String id) async {
    final current = state.valueOrNull ?? const [];
    final updated = current.where((f) => f.id != id).toList();
    state = AsyncValue.data(updated);
    await ref.read(favoritesRepositoryProvider).saveAll(updated);
  }
}
