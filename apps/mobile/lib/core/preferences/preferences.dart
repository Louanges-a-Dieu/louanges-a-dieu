import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../design_system/tokens.g.dart';

/// Apparence de l'app ou du mode lecture : `system` suit le réglage de
/// l'appareil (clair ou sombre) ; sépia : papier chaud, pour les longues
/// lectures (planche 3).
enum LadAppearance { system, light, dark, sepia }

/// Police des paroles (planche 3) : Classique (Literata, serif de lecture),
/// Moderne (Inter), Éditorial (Cormorant Garamond).
enum LyricsFont { classic, modern, editorial }

enum ReaderMargins { standard, wide }

enum ReaderOrientation { auto, portrait, landscape }

/// Préférences de lecture et d'écoute, conservées dans la base locale (hors
/// connexion).
@immutable
final class ReadingPreferences {
  const ReadingPreferences({
    this.lyricsSize = LadLyricsSize.defaultSize,
    this.appearance = LadAppearance.system,
    this.sungOrder = false,
    this.readerTheme = LadAppearance.system,
    this.lyricsFont = LyricsFont.classic,
    this.lineSpacing = 1.0,
    this.margins = ReaderMargins.standard,
    this.showNumber = true,
    this.showTitle = true,
    this.showReferences = true,
    this.keepScreenOn = true,
    this.orientation = ReaderOrientation.auto,
    this.audioSpeed = 1.0,
    this.audioLoop = false,
    this.autoAdvanceSeconds = 8,
    this.projectionBackground = 'dark',
    this.projectionShowNumber = true,
    this.projectionScale = 1.0,
  });

  /// Taille des paroles (pt), entre [LadLyricsSize.min] et [LadLyricsSize.max].
  final double lyricsSize;

  /// Apparence de l'app.
  final LadAppearance appearance;

  /// Répéter le refrain après chaque couplet sur la fiche (ordre chanté) ;
  /// le mode lecture l’applique toujours.
  /// Désactivé par défaut : la fiche suit l'ordre imprimé (Q-07, ADR-009).
  final bool sungOrder;

  /// Apparence du mode lecture : `system` suit l'apparence de l'app.
  final LadAppearance readerTheme;

  final LyricsFont lyricsFont;

  /// Interligne des paroles, en multiple de l'interligne du design system.
  final double lineSpacing;
  final ReaderMargins margins;

  /// Mode lecture : numéro, titre et références bibliques en tête.
  final bool showNumber;
  final bool showTitle;
  final bool showReferences;

  /// Écran maintenu allumé pendant la lecture.
  final bool keepScreenOn;
  final ReaderOrientation orientation;

  /// Vitesse d'écoute (0,75 à 1,5) et lecture en boucle.
  final double audioSpeed;
  final bool audioLoop;

  /// Délai entre deux strophes en défilement automatique (plein écran,
  /// projection).
  final int autoAdvanceSeconds;

  /// Apparence de l'écran projeté pour un cantique seul (un programme garde
  /// la sienne) : fond (`dark`, `light`, `image:<photo>`), numéro, taille.
  final String projectionBackground;
  final bool projectionShowNumber;
  final double projectionScale;

  static const lineSpacings = [0.9, 1.0, 1.15, 1.3, 1.5];
  static const audioSpeeds = [0.75, 1.0, 1.25, 1.5];
  static const autoAdvanceChoices = [5, 8, 10, 15, 20, 30];

  ReadingPreferences copyWith({
    double? lyricsSize,
    LadAppearance? appearance,
    bool? sungOrder,
    LadAppearance? readerTheme,
    LyricsFont? lyricsFont,
    double? lineSpacing,
    ReaderMargins? margins,
    bool? showNumber,
    bool? showTitle,
    bool? showReferences,
    bool? keepScreenOn,
    ReaderOrientation? orientation,
    double? audioSpeed,
    bool? audioLoop,
    int? autoAdvanceSeconds,
    String? projectionBackground,
    bool? projectionShowNumber,
    double? projectionScale,
  }) => ReadingPreferences(
    lyricsSize: (lyricsSize ?? this.lyricsSize).clamp(
      LadLyricsSize.min,
      LadLyricsSize.max,
    ),
    appearance: appearance ?? this.appearance,
    sungOrder: sungOrder ?? this.sungOrder,
    readerTheme: readerTheme ?? this.readerTheme,
    lyricsFont: lyricsFont ?? this.lyricsFont,
    lineSpacing: (lineSpacing ?? this.lineSpacing).clamp(
      lineSpacings.first,
      lineSpacings.last,
    ),
    margins: margins ?? this.margins,
    showNumber: showNumber ?? this.showNumber,
    showTitle: showTitle ?? this.showTitle,
    showReferences: showReferences ?? this.showReferences,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    orientation: orientation ?? this.orientation,
    audioSpeed: (audioSpeed ?? this.audioSpeed).clamp(
      audioSpeeds.first,
      audioSpeeds.last,
    ),
    audioLoop: audioLoop ?? this.audioLoop,
    autoAdvanceSeconds: (autoAdvanceSeconds ?? this.autoAdvanceSeconds).clamp(
      autoAdvanceChoices.first,
      autoAdvanceChoices.last,
    ),
    projectionBackground: projectionBackground ?? this.projectionBackground,
    projectionShowNumber: projectionShowNumber ?? this.projectionShowNumber,
    projectionScale: (projectionScale ?? this.projectionScale).clamp(0.7, 1.3),
  );

  /// Réglages de lecture remis par défaut (« Réinitialiser ») ; l'apparence
  /// de l'app et l'écoute ne changent pas.
  ReadingPreferences resetReading() {
    const d = ReadingPreferences();
    return ReadingPreferences(
      appearance: appearance,
      sungOrder: sungOrder,
      audioSpeed: audioSpeed,
      audioLoop: audioLoop,
      projectionBackground: projectionBackground,
      projectionShowNumber: projectionShowNumber,
      projectionScale: projectionScale,
      lyricsSize: d.lyricsSize,
      readerTheme: d.readerTheme,
      lyricsFont: d.lyricsFont,
      lineSpacing: d.lineSpacing,
      margins: d.margins,
      showNumber: d.showNumber,
      showTitle: d.showTitle,
      showReferences: d.showReferences,
      keepScreenOn: d.keepScreenOn,
      orientation: d.orientation,
      autoAdvanceSeconds: d.autoAdvanceSeconds,
    );
  }
}

class PreferencesRepository {
  PreferencesRepository(this._db);

  final AppDatabase _db;

  static const _size = 'pref.lyricsSize';
  // Nom historique : contenait un ThemeMode (system / light / dark).
  static const _appearance = 'pref.themeMode';
  static const _sung = 'pref.sungOrder';
  static const _readerTheme = 'pref.readerTheme';
  static const _font = 'pref.lyricsFont';
  static const _spacing = 'pref.lineSpacing';
  static const _margins = 'pref.margins';
  static const _number = 'pref.showNumber';
  static const _title = 'pref.showTitle';
  static const _references = 'pref.showReferences';
  static const _awake = 'pref.keepScreenOn';
  static const _orientation = 'pref.orientation';
  static const _speed = 'pref.audioSpeed';
  static const _loop = 'pref.audioLoop';
  static const _auto = 'pref.autoAdvanceSeconds';
  static const _projBackground = 'pref.projectionBackground';
  static const _projNumber = 'pref.projectionShowNumber';
  static const _projScale = 'pref.projectionScale';

  Future<ReadingPreferences> load() async {
    final rows = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.like('pref.%'))).get();
    final values = {for (final r in rows) r.key: r.value};
    bool? flag(String key) =>
        values[key] == null ? null : values[key] == 'true';
    return const ReadingPreferences().copyWith(
      lyricsSize: double.tryParse(values[_size] ?? ''),
      appearance: LadAppearance.values.asNameMap()[values[_appearance]],
      sungOrder: flag(_sung),
      readerTheme: LadAppearance.values.asNameMap()[values[_readerTheme]],
      lyricsFont: LyricsFont.values.asNameMap()[values[_font]],
      lineSpacing: double.tryParse(values[_spacing] ?? ''),
      margins: ReaderMargins.values.asNameMap()[values[_margins]],
      showNumber: flag(_number),
      showTitle: flag(_title),
      showReferences: flag(_references),
      keepScreenOn: flag(_awake),
      orientation: ReaderOrientation.values.asNameMap()[values[_orientation]],
      audioSpeed: double.tryParse(values[_speed] ?? ''),
      audioLoop: flag(_loop),
      autoAdvanceSeconds: int.tryParse(values[_auto] ?? ''),
      projectionBackground: values[_projBackground],
      projectionShowNumber: flag(_projNumber),
      projectionScale: double.tryParse(values[_projScale] ?? ''),
    );
  }

  Future<void> save(ReadingPreferences p) => _db.batch(
    (b) => b.insertAllOnConflictUpdate(_db.syncState, [
      for (final (key, value) in [
        (_size, '${p.lyricsSize}'),
        (_appearance, p.appearance.name),
        (_sung, '${p.sungOrder}'),
        (_readerTheme, p.readerTheme.name),
        (_font, p.lyricsFont.name),
        (_spacing, '${p.lineSpacing}'),
        (_margins, p.margins.name),
        (_number, '${p.showNumber}'),
        (_title, '${p.showTitle}'),
        (_references, '${p.showReferences}'),
        (_awake, '${p.keepScreenOn}'),
        (_orientation, p.orientation.name),
        (_speed, '${p.audioSpeed}'),
        (_loop, '${p.audioLoop}'),
        (_auto, '${p.autoAdvanceSeconds}'),
        (_projBackground, p.projectionBackground),
        (_projNumber, '${p.projectionShowNumber}'),
        (_projScale, '${p.projectionScale}'),
      ])
        SyncStateCompanion.insert(key: key, value: value),
    ]),
  );
}
