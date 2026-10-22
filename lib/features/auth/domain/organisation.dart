import 'package:freezed_annotation/freezed_annotation.dart';

part 'organisation.freezed.dart';
part 'organisation.g.dart';

/// Only the subset of Prisma's `Organisation` model this app actually needs
/// — this dialer app has no lead-pipeline/opportunity-stage UI (that's
/// Dad-mobile's job), unlike Dad-mobile's own richer `Organisation` model.
@freezed
class Organisation with _$Organisation {
  const factory Organisation({
    required String id,
    required String name,
  }) = _Organisation;

  factory Organisation.fromJson(Map<String, dynamic> json) => _$OrganisationFromJson(json);
}
