import 'dart:convert';

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
    this.icon,
    this.color,
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
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      deleted: json['deleted'] == true,
      hymnIds: List.unmodifiable(items.map((i) => i['hymnId']! as String)),
      revision: (json['revision'] as int?) ?? 0,
    );
  }

  final String id;
  final String name;
  final String? description;

  /// Icône et couleur choisies (planche 4), ou null.
  final String? icon;
  final String? color;
  final bool deleted;

  /// Cantiques dans l'ordre de la liste.
  final List<String> hymnIds;
  final int revision;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'color': color,
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
    this.location,
    this.description,
    this.cover,
    this.isTemplate = false,
    this.options = const {},
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
      location: json['location'] as String?,
      description: json['description'] as String?,
      cover: json['cover'] as String?,
      isTemplate: json['isTemplate'] == true,
      options: switch (json['options']) {
        final Map<String, Object?> o => Map.unmodifiable(o),
        _ => const {},
      },
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

  /// Lieu, description, photo de l'app (planche 4), ou null.
  final String? location;
  final String? description;
  final String? cover;

  /// Modèle réutilisable.
  final bool isTemplate;

  /// Options de projection ([ProgramOptions]).
  final Map<String, Object?> options;
  final bool deleted;
  final List<WorshipItemDto> items;
  final int revision;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'serviceDate': serviceDate,
    'status': status,
    'location': location,
    'description': description,
    'cover': cover,
    'isTemplate': isTemplate,
    'options': options,
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

/// Options de projection d'un programme (planche 4, écran 10 ; planche 5) :
/// conservées en JSON sur le programme et synchronisées.
@immutable
final class ProgramOptions {
  const ProgramOptions({
    this.repeatRefrain = true,
    this.showNumbers = true,
    this.transitions = false,
    this.background = 'dark',
    this.endMessage,
  });

  factory ProgramOptions.fromJson(Map<String, Object?> json) => ProgramOptions(
    repeatRefrain: json['repeatRefrain'] != false,
    showNumbers: json['showNumbers'] != false,
    transitions: json['transitions'] == true,
    background: json['background'] is String
        ? json['background']! as String
        : 'dark',
    endMessage: json['endMessage'] as String?,
  );

  factory ProgramOptions.decode(String? text) =>
      ProgramOptions.fromJson(rawJson(text));

  /// Objet JSON stocké (clés inconnues comprises, pour les renvoyer telles
  /// quelles au serveur) ; vide s'il est absent ou illisible.
  static Map<String, Object?> rawJson(String? text) {
    if (text == null || text.isEmpty) return const {};
    try {
      final json = jsonDecode(text);
      return json is Map<String, Object?> ? json : const {};
    } on FormatException {
      return const {};
    }
  }

  /// Refrain répété après chaque couplet (Q-07, désactivable par programme).
  final bool repeatRefrain;

  /// Numéro du cantique sur les diapositives.
  final bool showNumbers;

  /// Diapositive de transition (logo) entre deux cantiques.
  final bool transitions;

  /// Fond de l'écran projeté : `dark`, `light` ou `image:<photo>`.
  final String background;

  /// Message de fin de programme, ou null (pas de diapositive de fin).
  final String? endMessage;

  ProgramOptions copyWith({
    bool? repeatRefrain,
    bool? showNumbers,
    bool? transitions,
    String? background,
    String? Function()? endMessage,
  }) => ProgramOptions(
    repeatRefrain: repeatRefrain ?? this.repeatRefrain,
    showNumbers: showNumbers ?? this.showNumbers,
    transitions: transitions ?? this.transitions,
    background: background ?? this.background,
    endMessage: endMessage == null ? this.endMessage : endMessage(),
  );

  Map<String, Object?> toJson() => {
    'repeatRefrain': repeatRefrain,
    'showNumbers': showNumbers,
    'transitions': transitions,
    'background': background,
    if (endMessage != null) 'endMessage': endMessage,
  };

  String encode() => jsonEncode(toJson());
}
