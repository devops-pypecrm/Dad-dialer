import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/favorite_contact.dart';

part 'favorites_repository.g.dart';

const _kFavoritesKey = 'dialer_favorite_contacts';

@Riverpod(keepAlive: true)
FavoritesRepository favoritesRepository(ProviderRef<FavoritesRepository> ref) => FavoritesRepository();

/// Local-only store (see [FavoriteContact]'s doc comment for why this isn't
/// backend-synced) — a single JSON-encoded list under one
/// `shared_preferences` key, same storage choice as
/// `PreferCrmNameInCallLogs`.
class FavoritesRepository {
  Future<List<FavoriteContact>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFavoritesKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => FavoriteContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<FavoriteContact> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_kFavoritesKey, encoded);
  }
}
