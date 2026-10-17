import 'package:flutter/foundation.dart';

/// Formats d'échange avec le serveur (RPC sync_*, voir docs/api/rpc.md).

@immutable
final class FavoriteChange {
  const FavoriteChange({
    required this.hymnId,
    required this.deleted,
    this.revision = 0,
  });

  factory FavoriteChange.fromJson(Map<String, Object?> json) => FavoriteChange(
    hymnId: json['hymnId']! as String,
    deleted: json['deleted'] == true,
    revision: (json['revision'] as int?) ?? 0,
  );

  final String hymnId;
  final bool deleted;
  final int revision;

  Map<String, Object?> toJson() => {'hymnId': hymnId, 'deleted': deleted};
}

@immutable
final class PlaylistDto {
  const PlaylistDto({
    required this.id,
    required this.name,
    required this.description,
    required this.deleted,
    required this.hymnIds,
    this.revision = 0,
  });

  factory PlaylistDto.fromJson(Map<String, Object?> json) {
    final items =
        (json['items'] as List<Object?>? ?? const [])
            .cast<Map<String, Object?>>()
            .toList()
          ..sort((a, b) => (a['order']! as int).compareTo(b['order']! as int));
    return PlaylistDto(
      id: json['id']! as String,
      name: json['name']! as String,
      description: json['description'] as String?,
      deleted: json['deleted'] == true,
      hymnIds: List.unmodifiable(items.map((i) => i['hymnId']! as String)),
      revision: (json['revision'] as int?) ?? 0,
    );
  }

  final String id;
  final String name;
  final String? description;
  final bool deleted;

  /// Cantiques dans l'ordre de la liste.
  final List<String> hymnIds;
  final int revision;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'deleted': deleted,
    'items': [
      for (var i = 0; i < hymnIds.length; i++)
        {'hymnId': hymnIds[i], 'order': i},
    ],
  };
}

@immutable
final class WorshipItemDto {
  const WorshipItemDto({
    required this.id,
    required this.hymnId,
    required this.label,
    required this.notes,
  });

  final String id;

  /// Cantique, ou null pour une section libre (accueil, prière…).
  final String? hymnId;
  final String? label;
  final String? notes;
}

@immutable
final class WorshipServiceDto {
  const WorshipServiceDto({
    required this.id,
    required this.title,
    required this.serviceDate,
    required this.status,
    required this.deleted,
    required this.items,
    this.revision = 0,
  });

  factory WorshipServiceDto.fromJson(Map<String, Object?> json) {
    final items =
        (json['items'] as List<Object?>? ?? const [])
            .cast<Map<String, Object?>>()
            .toList()
          ..sort((a, b) => (a['order']! as int).compareTo(b['order']! as int));
    return WorshipServiceDto(
      id: json['id']! as String,
      title: json['title']! as String,
      serviceDate: json['serviceDate'] as String?,
      status: json['status']! as String,
      deleted: json['deleted'] == true,
      items: List.unmodifiable(
        items.map(
          (i) => WorshipItemDto(
            id: i['id']! as String,
            hymnId: i['hymnId'] as String?,
            label: i['label'] as String?,
            notes: i['notes'] as String?,
          ),
        ),
      ),
      revision: (json['revision'] as int?) ?? 0,
    );
  }

  final String id;
  final String title;

  /// AAAA-MM-JJ ou null.
  final String? serviceDate;

  /// draft | published | archived
  final String status;
  final bool deleted;
  final List<WorshipItemDto> items;
  final int revision;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'serviceDate': serviceDate,
    'status': status,
    'deleted': deleted,
    'items': [
      for (var i = 0; i < items.length; i++)
        {
          'id': items[i].id,
          'hymnId': items[i].hymnId,
          'label': items[i].label,
          'notes': items[i].notes,
          'order': i,
        },
    ],
  };
}

/// Changements reçus du serveur depuis une révision donnée.
@immutable
final class UserChanges {
  const UserChanges({
    required this.revision,
    required this.favorites,
    required this.playlists,
    required this.worshipServices,
  });

  factory UserChanges.fromJson(Map<String, Object?> json) => UserChanges(
    revision: json['revision']! as int,
    favorites: [
      for (final f in (json['favorites'] as List<Object?>? ?? const []))
        FavoriteChange.fromJson(f! as Map<String, Object?>),
    ],
    playlists: [
      for (final p in (json['playlists'] as List<Object?>? ?? const []))
        PlaylistDto.fromJson(p! as Map<String, Object?>),
    ],
    worshipServices: [
      for (final w in (json['worshipServices'] as List<Object?>? ?? const []))
        WorshipServiceDto.fromJson(w! as Map<String, Object?>),
    ],
  );

  final int revision;
  final List<FavoriteChange> favorites;
  final List<PlaylistDto> playlists;
  final List<WorshipServiceDto> worshipServices;
}
