import 'package:flutter/foundation.dart';

import 'published_hymn.dart';

/// Cantique validé par le contrat, accompagné de son JSON d'origine
/// (stocké tel quel dans la base locale).
@immutable
final class ValidatedHymn {
  const ValidatedHymn(this.hymn, this.json);

  /// Lève [FormatException] si le JSON ne respecte pas le contrat.
  factory ValidatedHymn.parse(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('Cantique : objet attendu');
    }
    return ValidatedHymn(PublishedHymn.fromJson(json), json);
  }

  final PublishedHymn hymn;
  final Map<String, Object?> json;
}

/// Description de la dernière release disponible côté serveur.
@immutable
final class CatalogManifest {
  const CatalogManifest({
    required this.releaseId,
    required this.hymnCount,
    required this.contentHash,
  });

  factory CatalogManifest.fromJson(Map<String, Object?> json) =>
      CatalogManifest(
        releaseId: _int(json, 'releaseId'),
        hymnCount: _int(json, 'hymnCount'),
        contentHash: _string(json, 'contentHash'),
      );

  final int releaseId;
  final int hymnCount;
  final String contentHash;
}

/// Contenu complet d'une release.
@immutable
final class CatalogSnapshot {
  const CatalogSnapshot({
    required this.releaseId,
    required this.contentHash,
    required this.hymns,
  });

  factory CatalogSnapshot.fromJson(Map<String, Object?> json) {
    final hymns = json['hymns'];
    if (hymns is! List<Object?>) {
      throw const FormatException('Instantané : liste « hymns » attendue');
    }
    return CatalogSnapshot(
      releaseId: _int(json, 'releaseId'),
      contentHash: _string(json, 'contentHash'),
      hymns: List.unmodifiable(hymns.map(ValidatedHymn.parse)),
    );
  }

  final int releaseId;
  final String contentHash;
  final List<ValidatedHymn> hymns;
}

/// Changements entre la release du client et la dernière release.
@immutable
final class CatalogDelta {
  const CatalogDelta({
    required this.fromRelease,
    required this.toRelease,
    required this.fullSnapshotRequired,
    required this.upserts,
    required this.removedIds,
  });

  factory CatalogDelta.fromJson(Map<String, Object?> json) {
    final full = json['fullSnapshotRequired'] == true;
    final upserts = json['upserts'];
    final removed = json['removedIds'];
    return CatalogDelta(
      fromRelease: _int(json, 'fromRelease'),
      toRelease: _int(json, 'toRelease'),
      fullSnapshotRequired: full,
      upserts: full || upserts is! List<Object?>
          ? const []
          : List.unmodifiable(upserts.map(ValidatedHymn.parse)),
      removedIds: full || removed is! List<Object?>
          ? const []
          : List.unmodifiable(removed.cast<String>()),
    );
  }

  final int fromRelease;
  final int toRelease;
  final bool fullSnapshotRequired;
  final List<ValidatedHymn> upserts;
  final List<String> removedIds;
}

/// Ligne de liste (recueil, résultats) : sans le contenu complet.
@immutable
final class HymnSummary {
  const HymnSummary({
    required this.id,
    required this.numberLabel,
    required this.numberNumeric,
    required this.title,
    required this.openingLine,
  });

  final String id;
  final String numberLabel;
  final int numberNumeric;
  final String title;
  final String? openingLine;

  @override
  bool operator ==(Object other) =>
      other is HymnSummary &&
      other.id == id &&
      other.numberLabel == numberLabel;

  @override
  int get hashCode => Object.hash(id, numberLabel);

  @override
  String toString() => 'HymnSummary($numberLabel, $title)';
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key : entier attendu');
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$key : texte attendu');
}
