import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../search/normalize.dart';
import 'catalog_models.dart';
import 'published_hymn.dart';

/// Accès au catalogue local. Toutes les écritures sont atomiques : une mise à
/// jour interrompue laisse le catalogue précédent intact.
class CatalogRepository {
  CatalogRepository(this._db);

  final AppDatabase _db;

  static const _releaseKey = 'catalog.releaseId';
  static const _hashKey = 'catalog.contentHash';

  Future<int?> currentReleaseId() async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(_releaseKey))).getSingleOrNull();
    return row == null ? null : int.parse(row.value);
  }

  Future<int> count() async {
    final c = _db.catalogHymns.id.count();
    final row = await (_db.selectOnly(
      _db.catalogHymns,
    )..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  /// Remplace tout le catalogue local par une release complète.
  /// [expectedCount] : nombre attendu (manifeste), vérifié avant validation.
  Future<void> replaceAll(CatalogSnapshot snapshot, {int? expectedCount}) {
    return _db.transaction(() async {
      await _db.delete(_db.catalogHymns).go();
      await _db.customStatement('DELETE FROM hymn_search');
      await _insertAll(snapshot.hymns);
      await _setRelease(snapshot.releaseId, snapshot.contentHash);
      await _verifyCount(expectedCount ?? snapshot.hymns.length);
    });
  }

  /// Applique un delta (ajouts, modifications, retraits).
  Future<void> applyDelta(
    CatalogDelta delta, {
    required String contentHash,
    int? expectedCount,
  }) {
    return _db.transaction(() async {
      final ids = [...delta.upserts.map((h) => h.hymn.id), ...delta.removedIds];
      for (final chunk in _chunks(ids, 500)) {
        await (_db.delete(
          _db.catalogHymns,
        )..where((h) => h.id.isIn(chunk))).go();
        await _db.customStatement(
          'DELETE FROM hymn_search WHERE hymn_id IN (${List.filled(chunk.length, '?').join(',')})',
          chunk,
        );
      }
      await _insertAll(delta.upserts);
      await _setRelease(delta.toRelease, contentHash);
      if (expectedCount != null) await _verifyCount(expectedCount);
    });
  }

  Future<void> _insertAll(List<ValidatedHymn> hymns) async {
    await _db.batch((b) {
      b.insertAll(_db.catalogHymns, [
        for (final v in hymns)
          CatalogHymnsCompanion.insert(
            id: v.hymn.id,
            numberLabel: v.hymn.numberLabel,
            numberNumeric: v.hymn.numberNumeric,
            numberSuffix: Value(v.hymn.numberSuffix),
            title: v.hymn.title,
            openingLine: Value(v.hymn.openingLine),
            sortKey: fold(v.hymn.title),
            payload: jsonEncode(v.json),
          ),
      ]);
      for (final v in hymns) {
        b.customStatement(
          'INSERT INTO hymn_search (hymn_id, number, title, lyrics) VALUES (?, ?, ?, ?)',
          [
            v.hymn.id,
            v.hymn.numberLabel,
            fold('${v.hymn.title} ${v.hymn.openingLine ?? ''}'),
            fold(
              v.hymn.sections
                  .expand((s) => s.lines)
                  .map((l) => l.text)
                  .join(' '),
            ),
          ],
        );
      }
    });
  }

  Future<void> _setRelease(int releaseId, String contentHash) async {
    await _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.syncState, [
        SyncStateCompanion.insert(key: _releaseKey, value: '$releaseId'),
        SyncStateCompanion.insert(key: _hashKey, value: contentHash),
      ]);
    });
  }

  Future<void> _verifyCount(int expected) async {
    final actual = await count();
    if (actual != expected) {
      throw StateError(
        'Catalogue incohérent : $actual cantiques au lieu de $expected',
      );
    }
  }

  /// Recueil trié par numéro (les « bis » suivent leur numéro principal).
  Stream<List<HymnSummary>> watchByNumber() {
    final q = _db.select(_db.catalogHymns)
      ..orderBy([
        (h) => OrderingTerm.asc(h.numberNumeric),
        (h) => OrderingTerm.asc(h.numberLabel),
      ]);
    return q.watch().map((rows) => rows.map(_summary).toList(growable: false));
  }

  /// Recueil par ordre alphabétique des titres (accents ignorés).
  Stream<List<HymnSummary>> watchAlphabetical() {
    final q = _db.select(_db.catalogHymns)
      ..orderBy([
        (h) => OrderingTerm.asc(h.sortKey),
        (h) => OrderingTerm.asc(h.numberNumeric),
      ]);
    return q.watch().map((rows) => rows.map(_summary).toList(growable: false));
  }

  Future<PublishedHymn?> hymnById(String id) async {
    final row = await (_db.select(
      _db.catalogHymns,
    )..where((h) => h.id.equals(id))).getSingleOrNull();
    return row == null ? null : _parse(row);
  }

  Future<PublishedHymn?> hymnByLabel(String numberLabel) async {
    final row = await (_db.select(
      _db.catalogHymns,
    )..where((h) => h.numberLabel.equals(numberLabel))).getSingleOrNull();
    return row == null ? null : _parse(row);
  }

  /// Cantiques qui ont au moins un enregistrement publié, par numéro
  /// (téléchargements pour l'écoute hors connexion).
  Future<List<PublishedHymn>> hymnsWithAudio() async {
    final rows =
        await (_db.select(_db.catalogHymns)
              ..where((h) => h.payload.like('%"audio"%'))
              ..orderBy([
                (h) => OrderingTerm.asc(h.numberNumeric),
                (h) => OrderingTerm.asc(h.numberLabel),
              ]))
            .get();
    return [
      for (final row in rows)
        if (_parse(row) case final hymn when hymn.audio.isNotEmpty) hymn,
    ];
  }

  /// Cantique précédent / suivant dans l'ordre du recueil (mode lecture).
  Future<HymnSummary?> neighbour(String id, {required bool next}) async {
    final all = await watchByNumber().first;
    final index = all.indexWhere((h) => h.id == id);
    if (index == -1) return null;
    final target = index + (next ? 1 : -1);
    return target < 0 || target >= all.length ? null : all[target];
  }

  static PublishedHymn _parse(CatalogHymnRow row) =>
      PublishedHymn.fromJson(jsonDecode(row.payload) as Map<String, Object?>);

  static HymnSummary _summary(CatalogHymnRow row) => HymnSummary(
    id: row.id,
    numberLabel: row.numberLabel,
    numberNumeric: row.numberNumeric,
    title: row.title,
    openingLine: row.openingLine,
  );

  static HymnSummary summaryOf(CatalogHymnRow row) => _summary(row);

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}
