import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Derniers cantiques ouverts, du plus récent au plus ancien (« Reprendre
/// votre lecture »). Conservés sur l'appareil seulement : ni compte, ni
/// synchronisation, ni journal d'erreurs ; effaçables depuis l'accueil.
class ReadingHistoryRepository {
  ReadingHistoryRepository(this._db);

  final AppDatabase _db;

  static const key = 'history.recent';
  static const max = 5;

  SimpleSelectStatement<$SyncStateTable, SyncStateRow> get _row =>
      _db.select(_db.syncState)..where((s) => s.key.equals(key));

  static List<String> _decode(SyncStateRow? row) {
    if (row == null) return const [];
    try {
      return (jsonDecode(row.value) as List<Object?>)
          .whereType<String>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Stream<List<String>> watch() => _row.watchSingleOrNull().map(_decode);

  Future<List<String>> read() async => _decode(await _row.getSingleOrNull());

  /// Place [hymnId] en tête, sans doublon, en gardant les [max] plus récents.
  Future<void> record(String hymnId) => _db.transaction(() async {
    final ids = [
      hymnId,
      ...(await read()).where((id) => id != hymnId),
    ].take(max).toList();
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(key: key, value: jsonEncode(ids)),
        );
  });

  Future<void> clear() =>
      (_db.delete(_db.syncState)..where((s) => s.key.equals(key))).go();
}
