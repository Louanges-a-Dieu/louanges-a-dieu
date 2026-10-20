import 'package:flutter/foundation.dart';

/// Cantique publié, tel que distribué par les releases de catalogue.
///
/// Miroir Dart du contrat `PublishedHymn` (packages/shared_contracts) : mêmes
/// règles, vérifiées sur les mêmes fixtures. Une valeur inconnue vaut `null` ;
/// une chaîne vide est refusée pour qu'aucun écran n'affiche de donnée fictive.
@immutable
final class PublishedHymn {
  const PublishedHymn({
    required this.id,
    required this.numberLabel,
    required this.numberNumeric,
    required this.numberSuffix,
    required this.title,
    required this.openingLine,
    required this.languageCode,
    required this.sections,
    required this.bibleReferences,
    required this.relations,
    required this.people,
    required this.themes,
    this.audio = const [],
  });

  /// Lève [FormatException] si le contenu ne respecte pas le contrat.
  factory PublishedHymn.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'cantique');
    final hymn = PublishedHymn(
      id: reader.uuid('id'),
      numberLabel: reader.string('numberLabel'),
      numberNumeric: reader.integer('numberNumeric'),
      numberSuffix: reader.nullableString('numberSuffix'),
      title: reader.string('title'),
      openingLine: reader.nullableString('openingLine'),
      languageCode: reader.string('languageCode'),
      sections: reader.list('sections', HymnSection.fromJson),
      bibleReferences: reader.list('bibleReferences', BibleReference.fromJson),
      relations: reader.list('relations', HymnRelation.fromJson),
      people: reader.list('people', HymnPerson.fromJson),
      themes: reader.stringList('themes'),
      audio: json.containsKey('audio')
          ? reader.list('audio', AudioTrack.fromJson)
          : const [],
    );
    if (json.containsKey('audio') && hymn.audio.isEmpty) {
      throw const FormatException(
        'cantique.audio : clé absente attendue quand il n’y a aucun enregistrement',
      );
    }
    hymn._validate();
    return hymn;
  }

  final String id;

  /// Libellé imprimé : « 37 », « 37bis ».
  final String numberLabel;
  final int numberNumeric;

  /// « bis », « ter » ou `null`.
  final String? numberSuffix;
  final String title;
  final String? openingLine;
  final String languageCode;
  final List<HymnSection> sections;
  final List<BibleReference> bibleReferences;
  final List<HymnRelation> relations;
  final List<HymnPerson> people;
  final List<String> themes;

  /// Enregistrements diffusables (vide si le cantique n'en a aucun).
  final List<AudioTrack> audio;

  void _validate() {
    if (!RegExp(r'^[1-9]\d{0,3}(bis|ter)?$').hasMatch(numberLabel)) {
      throw FormatException('Libellé de numéro invalide : $numberLabel');
    }
    if (numberSuffix != null &&
        numberSuffix != 'bis' &&
        numberSuffix != 'ter') {
      throw FormatException('Suffixe invalide : $numberSuffix');
    }
    if (numberLabel != '$numberNumeric${numberSuffix ?? ''}') {
      throw FormatException('Numéro incohérent : $numberLabel');
    }
    if (sections.isEmpty) {
      throw const FormatException('Un cantique publié a au moins une section');
    }
    final orders = sections.map((s) => s.order).toSet();
    if (orders.length != sections.length) {
      throw const FormatException('Ordre de section dupliqué');
    }
    final lineCounts = {for (final s in sections) s.id: s.lines.length};
    for (final track in audio) {
      for (final segment in track.segments) {
        final sectionId = segment.sectionId;
        if (sectionId == null) continue;
        final lines = lineCounts[sectionId];
        if (lines == null) {
          throw FormatException('Passage audio : section inconnue $sectionId');
        }
        final line = segment.lineIndex;
        if (line != null && line >= lines) {
          throw FormatException('Passage audio : ligne $line inexistante');
        }
      }
    }
    if (relations.any((r) => r.relatedHymnId == id)) {
      throw const FormatException('Relation d’un cantique avec lui-même');
    }
  }
}

enum SectionType { verse, refrain, bridge, intro, outro, note }

/// Nom d'une section tel qu'affiché (« Couplet 2 », « Refrain ») ; le numéro
/// n'apparaît que s'il est imprimé.
String sectionName(SectionType type, int? number) => [
  switch (type) {
    SectionType.verse => 'Couplet',
    SectionType.refrain => 'Refrain',
    SectionType.bridge => 'Pont',
    SectionType.intro => 'Introduction',
    SectionType.outro => 'Conclusion',
    SectionType.note => 'Note',
  },
  ?number?.toString(),
].join(' ');

@immutable
final class HymnSection {
  const HymnSection({
    required this.id,
    required this.type,
    required this.number,
    required this.order,
    required this.lines,
  });

  factory HymnSection.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'section');
    final lines = reader.list('lines', HymnLine.fromJson);
    if (lines.isEmpty) throw const FormatException('Section sans vers');
    return HymnSection(
      id: reader.uuid('id'),
      type: reader.enumValue('type', SectionType.values),
      number: reader.nullableInteger('number'),
      order: reader.integer('order', min: 0),
      lines: lines,
    );
  }

  final String id;
  final SectionType type;

  /// Numéro de couplet s'il est imprimé, sinon `null` (jamais inventé).
  final int? number;
  final int order;
  final List<HymnLine> lines;
}

@immutable
final class HymnLine {
  const HymnLine({required this.text, required this.repeat});

  factory HymnLine.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'vers');
    final repeat = json['repeat'];
    return HymnLine(
      text: reader.string('text'),
      repeat: repeat == null
          ? null
          : LineRepeat.fromJson(_Reader.asMap(repeat, 'repeat')),
    );
  }

  /// Texte verbatim, marqueur de répétition inclus.
  final String text;
  final LineRepeat? repeat;
}

@immutable
final class LineRepeat {
  const LineRepeat({required this.count, required this.marker});

  factory LineRepeat.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'répétition');
    return LineRepeat(
      count: reader.integer('count', min: 2, max: 12),
      marker: reader.string('marker'),
    );
  }

  final int count;
  final String marker;
}

@immutable
final class BibleReference {
  const BibleReference({
    required this.displayText,
    required this.book,
    required this.chapterStart,
    required this.verseStart,
    required this.chapterEnd,
    required this.verseEnd,
  });

  factory BibleReference.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'référence');
    return BibleReference(
      displayText: reader.string('displayText'),
      book: reader.nullableString('book'),
      chapterStart: reader.nullableInteger('chapterStart'),
      verseStart: reader.nullableInteger('verseStart'),
      chapterEnd: reader.nullableInteger('chapterEnd'),
      verseEnd: reader.nullableInteger('verseEnd'),
    );
  }

  final String displayText;
  final String? book;
  final int? chapterStart;
  final int? verseStart;
  final int? chapterEnd;
  final int? verseEnd;
}

enum RelationType { sameMelody, variant, bisOf, related }

@immutable
final class HymnRelation {
  const HymnRelation({required this.type, required this.relatedHymnId});

  factory HymnRelation.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'relation');
    final type = switch (reader.string('type')) {
      'same_melody' => RelationType.sameMelody,
      'variant' => RelationType.variant,
      'bis_of' => RelationType.bisOf,
      'related' => RelationType.related,
      final other => throw FormatException('Type de relation inconnu : $other'),
    };
    return HymnRelation(
      type: type,
      relatedHymnId: reader.uuid('relatedHymnId'),
    );
  }

  final RelationType type;
  final String relatedHymnId;
}

enum PersonRole { author, composer, translator, arranger }

@immutable
final class HymnPerson {
  const HymnPerson({required this.role, required this.fullName});

  factory HymnPerson.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'personne');
    return HymnPerson(
      role: reader.enumValue('role', PersonRole.values),
      fullName: reader.string('fullName'),
    );
  }

  final PersonRole role;
  final String fullName;
}

enum MediaType {
  melody,
  accompaniment,
  choir,
  soprano,
  alto,
  tenor,
  bass,
  instrumental,
  other,
}

/// Nom d'un type d'enregistrement tel qu'affiché.
String mediaTypeName(MediaType type) => switch (type) {
  MediaType.melody => 'Mélodie',
  MediaType.accompaniment => 'Accompagnement',
  MediaType.choir => 'Chorale',
  MediaType.soprano => 'Soprano',
  MediaType.alto => 'Alto',
  MediaType.tenor => 'Ténor',
  MediaType.bass => 'Basse',
  MediaType.instrumental => 'Instrumental',
  MediaType.other => 'Enregistrement',
};

/// Enregistrement audio d'un cantique, hébergé hors de la base (ADR-016).
@immutable
final class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.mediaType,
    required this.storageKey,
    required this.duration,
    required this.segments,
  });

  factory AudioTrack.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'audio');
    final key = reader.string('storageKey');
    if (!_storageKey.hasMatch(key) ||
        key.contains('..') ||
        key.contains('//')) {
      throw FormatException('audio.storageKey : clé relative attendue ($key)');
    }
    final seconds = reader.nullablePositiveNumber('durationSeconds');
    return AudioTrack(
      id: reader.uuid('id'),
      mediaType: reader.enumValue('mediaType', MediaType.values),
      storageKey: key,
      duration: seconds == null
          ? null
          : Duration(milliseconds: (seconds * 1000).round()),
      segments: reader.list('segments', AudioSegment.fromJson),
    );
  }

  static final _storageKey = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._/-]*\.(mp3|m4a|aac)$',
  );

  final String id;
  final MediaType mediaType;

  /// Chemin relatif dans le stockage des médias (jamais une URL).
  final String storageKey;

  /// Durée connue à la publication, sinon `null` (lue sur le fichier).
  final Duration? duration;
  final List<AudioSegment> segments;

  /// Vrai si la piste est synchronisée ligne par ligne : karaoké possible.
  bool get hasLineCues => segments.any((s) => s.lineIndex != null);
}

/// Passage d'un enregistrement correspondant à une section des paroles.
@immutable
final class AudioSegment {
  const AudioSegment({
    required this.sectionId,
    this.lineIndex,
    required this.start,
    required this.end,
    required this.order,
  });

  factory AudioSegment.fromJson(Map<String, Object?> json) {
    final reader = _Reader(json, 'passage');
    final start = reader.integer('startMs', min: 0);
    final end = reader.integer('endMs', min: 1);
    if (end <= start) {
      throw const FormatException('passage : fin avant le début');
    }
    final sectionId = json['sectionId'];
    final lineIndex = json['lineIndex'];
    if (lineIndex != null && (lineIndex is! int || lineIndex < 0)) {
      throw const FormatException('passage.lineIndex : entier positif attendu');
    }
    if (lineIndex != null && sectionId == null) {
      throw const FormatException(
        'passage : une ligne appartient à une section',
      );
    }
    return AudioSegment(
      lineIndex: lineIndex as int?,
      sectionId: (reader._has('sectionId') && sectionId == null)
          ? null
          : reader.uuid('sectionId'),
      start: Duration(milliseconds: start),
      end: Duration(milliseconds: end),
      order: reader.integer('order', min: 0),
    );
  }

  /// Section chantée, ou `null` (introduction, interlude…).
  final String? sectionId;

  /// Vers chanté (0 = premier) pour une piste synchronisée ligne par ligne
  /// (karaoké) ; `null` : la section entière.
  final int? lineIndex;
  final Duration start;
  final Duration end;
  final int order;
}

/// Lecture stricte d'un objet JSON (erreurs explicites en français).
final class _Reader {
  _Reader(this.json, this.context);

  final Map<String, Object?> json;
  final String context;

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _blank = RegExp(r'^[\s  ]*$');

  static Map<String, Object?> asMap(Object? value, String context) {
    if (value is Map<String, Object?>) return value;
    throw FormatException('$context : objet attendu');
  }

  Never _fail(String key, String expected) =>
      throw FormatException('$context.$key : $expected attendu');

  bool _has(String key) {
    if (!json.containsKey(key)) _fail(key, 'champ obligatoire');
    return true;
  }

  String string(String key) {
    _has(key);
    final value = json[key];
    if (value is! String) _fail(key, 'texte');
    if (_blank.hasMatch(value)) {
      throw FormatException(
        '$context.$key : chaîne vide interdite (utiliser null pour une valeur inconnue)',
      );
    }
    return value;
  }

  String? nullableString(String key) =>
      (_has(key) && json[key] == null) ? null : string(key);

  String uuid(String key) {
    final value = string(key);
    if (!_uuid.hasMatch(value)) _fail(key, 'UUID');
    return value;
  }

  int integer(String key, {int? min, int? max}) {
    _has(key);
    final value = json[key];
    if (value is! int) _fail(key, 'entier');
    if ((min != null && value < min) || (max != null && value > max)) {
      _fail(key, 'entier entre ${min ?? '-∞'} et ${max ?? '+∞'}');
    }
    return value;
  }

  double? nullablePositiveNumber(String key) {
    _has(key);
    final value = json[key];
    if (value == null) return null;
    if (value is! num || value <= 0) _fail(key, 'nombre positif');
    return value.toDouble();
  }

  int? nullableInteger(String key) =>
      (_has(key) && json[key] == null) ? null : integer(key, min: 1);

  T enumValue<T extends Enum>(String key, List<T> values) {
    final name = string(key);
    return values.firstWhere(
      (v) => v.name == name,
      orElse: () =>
          _fail(key, 'valeur parmi ${values.map((v) => v.name).join(', ')}'),
    );
  }

  List<T> list<T>(String key, T Function(Map<String, Object?>) parse) {
    _has(key);
    final value = json[key];
    if (value is! List<Object?>) _fail(key, 'liste');
    return List.unmodifiable(
      value.map((e) => parse(asMap(e, '$context.$key'))),
    );
  }

  List<String> stringList(String key) {
    _has(key);
    final value = json[key];
    if (value is! List<Object?>) _fail(key, 'liste');
    return List.unmodifiable(
      value.map((e) {
        if (e is! String || _blank.hasMatch(e)) {
          _fail(key, 'liste de textes non vides');
        }
        return e;
      }),
    );
  }
}
