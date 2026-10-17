import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../catalog/catalog_models.dart';
import '../catalog/catalog_repository.dart';
import '../catalog/published_hymn.dart';
import '../database/app_database.dart';
import 'normalize.dart';

/// Résultat dans les paroles, avec le vers qui correspond (texte verbatim).
@immutable
final class LyricMatch {
  const LyricMatch({required this.hymn, required this.excerpt});

  final HymnSummary hymn;
  final String excerpt;
}

@immutable
final class SearchResults {
  const SearchResults({
    this.exactNumber,
    this.numberMatches = const [],
    this.titleMatches = const [],
    this.lyricMatches = const [],
  });

  static const empty = SearchResults();

  /// Cantique dont le numéro est exactement celui saisi (« 37 », « 37bis »).
  final HymnSummary? exactNumber;

  /// Autres numéros commençant par la saisie (« 3 » → 30, 31…).
  final List<HymnSummary> numberMatches;

  /// Correspondances dans le titre ou le premier vers.
  final List<HymnSummary> titleMatches;

  /// Correspondances dans les paroles uniquement.
  final List<LyricMatch> lyricMatches;

  bool get isEmpty =>
      exactNumber == null &&
      numberMatches.isEmpty &&
      titleMatches.isEmpty &&
      lyricMatches.isEmpty;
}

/// Recherche locale, sans réseau (F-SEA-001, ADR-007).
class SearchService {
  SearchService(this._db);

  final AppDatabase _db;

  static final _number = RegExp(
    r'^(\d{1,4})\s*(bis|ter)?$',
    caseSensitive: false,
  );
  static const _limit = 50;

  Future<SearchResults> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return SearchResults.empty;

    final numberMatch = _number.firstMatch(trimmed);
    if (numberMatch != null) {
      final digits = numberMatch.group(1)!;
      final label =
          '${int.parse(digits)}${numberMatch.group(2)?.toLowerCase() ?? ''}';
      final exact = await (_db.select(
        _db.catalogHymns,
      )..where((h) => h.numberLabel.equals(label))).getSingleOrNull();
      final others = numberMatch.group(2) != null
          ? const <CatalogHymnRow>[]
          : await (_db.select(_db.catalogHymns)
                  ..where(
                    (h) =>
                        h.numberLabel.like('${int.parse(digits)}%') &
                        h.numberLabel.equals(label).not(),
                  )
                  ..orderBy([
                    (h) => OrderingTerm.asc(h.numberNumeric),
                    (h) => OrderingTerm.asc(h.numberLabel),
                  ])
                  ..limit(30))
                .get();
      return SearchResults(
        exactNumber: exact == null ? null : CatalogRepository.summaryOf(exact),
        numberMatches: others
            .map(CatalogRepository.summaryOf)
            .toList(growable: false),
      );
    }

    final tokens = fold(trimmed).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return SearchResults.empty;
    final terms = tokens.map((t) => '"$t"*').join(' ');

    final titleIds = await _matchIds('{title} : ($terms)');
    final lyricIds = (await _matchIds('{lyrics} : ($terms)'))
        .where((id) => !titleIds.contains(id));

    final titleRows = await _rowsInOrder(titleIds);
    final folded = tokens.join(' ');
    // Les titres qui COMMENCENT par la saisie passent en premier.
    final titleMatches = [
      ...titleRows.where((r) => r.sortKey.startsWith(folded)),
      ...titleRows.where((r) => !r.sortKey.startsWith(folded)),
    ].map(CatalogRepository.summaryOf).toList(growable: false);

    final lyricRows = await _rowsInOrder(lyricIds.toList());
    final lyricMatches = [
      for (final row in lyricRows)
        LyricMatch(
          hymn: CatalogRepository.summaryOf(row),
          excerpt: _excerpt(row, tokens),
        ),
    ];

    return SearchResults(
      titleMatches: titleMatches,
      lyricMatches: lyricMatches,
    );
  }

  Future<List<String>> _matchIds(String match) async {
    final rows = await _db
        .customSelect(
          'SELECT hymn_id FROM hymn_search WHERE hymn_search MATCH ? ORDER BY rank LIMIT $_limit',
          variables: [Variable.withString(match)],
          readsFrom: {_db.hymnSearch},
        )
        .get();
    return rows.map((r) => r.read<String>('hymn_id')).toList(growable: false);
  }

  Future<List<CatalogHymnRow>> _rowsInOrder(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (_db.select(
      _db.catalogHymns,
    )..where((h) => h.id.isIn(ids))).get();
    final byId = {for (final r in rows) r.id: r};
    return [for (final id in ids) ?byId[id]];
  }

  /// Premier vers contenant tous les mots cherchés (début de mot), sinon le
  /// premier vers contenant le premier mot.
  static String _excerpt(CatalogHymnRow row, List<String> tokens) {
    final hymn = PublishedHymn.fromJson(
      jsonDecode(row.payload) as Map<String, Object?>,
    );
    final lines = hymn.sections
        .expand((s) => s.lines)
        .map((l) => l.text)
        .toList();
    bool has(String line, String token) =>
        fold(line).split(' ').any((word) => word.startsWith(token));
    return lines.firstWhere(
      (l) => tokens.every((t) => has(l, t)),
      orElse: () => lines.firstWhere(
        (l) => has(l, tokens.first),
        orElse: () => lines.first,
      ),
    );
  }
}
