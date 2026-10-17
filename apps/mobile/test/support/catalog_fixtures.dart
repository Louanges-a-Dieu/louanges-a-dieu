import 'package:drift/native.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_models.dart';
import 'package:louanges_a_dieu/core/database/app_database.dart';

/// Base en mémoire (même moteur SQLite + FTS5 que sur l'appareil).
AppDatabase memoryDatabase() => AppDatabase(NativeDatabase.memory());

/// UUID déterministe pour un numéro de test (« 37bis » → …0370002).
String hymnUuid(String label) {
  final m = RegExp(r'^(\d+)(bis|ter)?$').firstMatch(label)!;
  final suffix = switch (m.group(2)) {
    'bis' => 2,
    'ter' => 3,
    _ => 0,
  };
  final n = int.parse(m.group(1)!) * 10 + suffix;
  return '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
}

/// UUID de section déterministe (numéro du cantique + position).
String _sectionUuid(String label, int order) =>
    '00000000-0000-4000-9000-${hymnUuid(label).substring(24, 34)}${order.toString().padLeft(2, '0')}';

/// Cantique synthétique conforme au contrat PublishedHymn.
Map<String, Object?> hymnJson(
  String label,
  String title, {
  List<List<String>> verses = const [],
  List<String>? refrain,
  String? openingLine,
}) {
  final m = RegExp(r'^(\d+)(bis|ter)?$').firstMatch(label)!;
  final sections = <Map<String, Object?>>[];
  Map<String, Object?> section(String type, List<String> lines) => {
    'id': _sectionUuid(label, sections.length),
    'type': type,
    'number': null,
    'order': sections.length,
    'lines': [
      for (final l in lines)
        {
          'text': l,
          'repeat': l.endsWith('(bis)')
              ? {'count': 2, 'marker': '(bis)'}
              : null,
        },
    ],
  };
  final body = verses.isEmpty
      ? [
          [title],
        ]
      : verses;
  sections.add(section('verse', body.first));
  if (refrain != null) sections.add(section('refrain', refrain));
  for (final v in body.skip(1)) {
    sections.add(section('verse', v));
  }
  return {
    'id': hymnUuid(label),
    'numberLabel': label,
    'numberNumeric': int.parse(m.group(1)!),
    'numberSuffix': m.group(2),
    'title': title,
    'openingLine': openingLine ?? body.first.first,
    'languageCode': 'fr',
    'sections': sections,
    'bibleReferences': const <Object?>[],
    'relations': m.group(2) == 'bis'
        ? [
            {'type': 'bis_of', 'relatedHymnId': hymnUuid(m.group(1)!)},
          ]
        : const <Object?>[],
    'people': const <Object?>[],
    'themes': const <Object?>[],
  };
}

/// Petit recueil synthétique couvrant les cas de recherche.
List<Map<String, Object?>> sampleHymns() => [
  hymnJson(
    '1',
    'Ô jour heureux',
    verses: [
      ['Ô jour heureux, jour de bonheur,', 'Lumière de mon cœur. (bis)'],
      ['Second couplet du premier chant,', 'Il est vivant.'],
    ],
  ),
  hymnJson(
    '2',
    'L’Éternel est mon berger',
    verses: [
      ['L’Éternel est mon berger,', 'Je ne manquerai de rien.'],
    ],
    refrain: ['Alléluia, gloire à Dieu,', 'Chantons Son Nom.'],
  ),
  hymnJson(
    '3',
    'Mon cœur Te loue',
    verses: [
      ['Mon cœur Te loue, Seigneur,', 'Dans la joie et dans la peine.'],
    ],
  ),
  hymnJson(
    '30',
    'Trentième chant',
    verses: [
      ['Un chant pour la moisson,', 'Les épis sont dorés.'],
    ],
  ),
  hymnJson(
    '37',
    'Au matin',
    verses: [
      ['Au matin je Te cherche,', 'Ta grâce me suffit.'],
    ],
  ),
  hymnJson(
    '37bis',
    'Autre texte sur la même mélodie',
    verses: [
      ['Autre texte sur la même mélodie,', 'Le jour se lève.'],
    ],
  ),
];

CatalogSnapshot snapshotOf(int releaseId, List<Map<String, Object?>> hymns) =>
    CatalogSnapshot.fromJson({
      'releaseId': releaseId,
      'contentHash': 'hash-$releaseId',
      'hymns': hymns,
    });
