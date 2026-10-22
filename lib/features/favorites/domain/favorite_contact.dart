import 'package:freezed_annotation/freezed_annotation.dart';

part 'favorite_contact.freezed.dart';
part 'favorite_contact.g.dart';

/// A quick-dial favorite — a personal, per-device shortlist, not synced to
/// the backend (there's no org-level reason for one rep's favorites to be
/// visible to anyone else). [id] is the source device contact's id when
/// [sourceContactId] came from Contacts, otherwise the normalized number
/// itself (e.g. favoriting a Recents/Dialer number with no saved contact).
@freezed
class FavoriteContact with _$FavoriteContact {
  const factory FavoriteContact({
    required String id,
    required String displayName,
    required String number,
    String? sourceContactId,
  }) = _FavoriteContact;

  factory FavoriteContact.fromJson(Map<String, dynamic> json) => _$FavoriteContactFromJson(json);
}
