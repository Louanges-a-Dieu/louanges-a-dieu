import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../design_system/tokens.g.dart';

/// Préférences de lecture, conservées dans la base locale (hors connexion).
@immutable
final class ReadingPreferences {
  const ReadingPreferences({
    this.lyricsSize = LadLyricsSize.defaultSize,
    this.themeMode = ThemeMode.system,
    this.sungOrder = false,
    this.readerTheme = ThemeMode.system,
  });

  /// Taille des paroles (pt), entre [LadLyricsSize.min] et [LadLyricsSize.max].
  final double lyricsSize;
  final ThemeMode themeMode;

  /// Répéter le refrain après chaque couplet sur la fiche (ordre chanté) ;
  /// le mode lecture l’applique toujours.
  /// Désactivé par défaut : la fiche suit l'ordre imprimé (Q-07, ADR-009).
  final bool sungOrder;

  /// Apparence du mode lecture : `system` suit l'apparence de l'app.
  final ThemeMode readerTheme;

  ReadingPreferences copyWith({
    double? lyricsSize,
    ThemeMode? themeMode,
    bool? sungOrder,
    ThemeMode? readerTheme,
  }) => ReadingPreferences(
    lyricsSize: (lyricsSize ?? this.lyricsSize).clamp(
      LadLyricsSize.min,
      LadLyricsSize.max,
    ),
    themeMode: themeMode ?? this.themeMode,
    sungOrder: sungOrder ?? this.sungOrder,
    readerTheme: readerTheme ?? this.readerTheme,
  );
}

class PreferencesRepository {
  PreferencesRepository(this._db);

  final AppDatabase _db;

  static const _size = 'pref.lyricsSize';
  static const _theme = 'pref.themeMode';
  static const _sung = 'pref.sungOrder';
  static const _readerTheme = 'pref.readerTheme';

  Future<ReadingPreferences> load() async {
    final rows = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.like('pref.%'))).get();
    final values = {for (final r in rows) r.key: r.value};
    return const ReadingPreferences().copyWith(
      lyricsSize: double.tryParse(values[_size] ?? ''),
      themeMode: ThemeMode.values.asNameMap()[values[_theme]],
      sungOrder: values[_sung] == null ? null : values[_sung] == 'true',
      readerTheme: ThemeMode.values.asNameMap()[values[_readerTheme]],
    );
  }

  Future<void> save(ReadingPreferences p) => _db.batch(
    (b) => b.insertAllOnConflictUpdate(_db.syncState, [
      SyncStateCompanion.insert(key: _size, value: '${p.lyricsSize}'),
      SyncStateCompanion.insert(key: _theme, value: p.themeMode.name),
      SyncStateCompanion.insert(key: _sung, value: '${p.sungOrder}'),
      SyncStateCompanion.insert(key: _readerTheme, value: p.readerTheme.name),
    ]),
  );
}
