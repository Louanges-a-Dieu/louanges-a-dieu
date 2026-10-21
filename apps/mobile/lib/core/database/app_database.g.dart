// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class HymnSearch extends Table
    with
        TableInfo<HymnSearch, HymnSearchData>,
        VirtualTableInfo<HymnSearch, HymnSearchData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  HymnSearch(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hymnIdMeta = const VerificationMeta('hymnId');
  late final GeneratedColumn<String> hymnId = GeneratedColumn<String>(
    'hymn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _lyricsMeta = const VerificationMeta('lyrics');
  late final GeneratedColumn<String> lyrics = GeneratedColumn<String>(
    'lyrics',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [hymnId, number, title, lyrics];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hymn_search';
  @override
  VerificationContext validateIntegrity(
    Insertable<HymnSearchData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hymn_id')) {
      context.handle(
        _hymnIdMeta,
        hymnId.isAcceptableOrUnknown(data['hymn_id']!, _hymnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hymnIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('lyrics')) {
      context.handle(
        _lyricsMeta,
        lyrics.isAcceptableOrUnknown(data['lyrics']!, _lyricsMeta),
      );
    } else if (isInserting) {
      context.missing(_lyricsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  HymnSearchData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HymnSearchData(
      hymnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hymn_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      lyrics: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics'],
      )!,
    );
  }

  @override
  HymnSearch createAlias(String alias) {
    return HymnSearch(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(hymn_id UNINDEXED, number, title, lyrics, tokenize = \'unicode61 remove_diacritics 2\')';
}

class HymnSearchData extends DataClass implements Insertable<HymnSearchData> {
  final String hymnId;
  final String number;
  final String title;
  final String lyrics;
  const HymnSearchData({
    required this.hymnId,
    required this.number,
    required this.title,
    required this.lyrics,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hymn_id'] = Variable<String>(hymnId);
    map['number'] = Variable<String>(number);
    map['title'] = Variable<String>(title);
    map['lyrics'] = Variable<String>(lyrics);
    return map;
  }

  HymnSearchCompanion toCompanion(bool nullToAbsent) {
    return HymnSearchCompanion(
      hymnId: Value(hymnId),
      number: Value(number),
      title: Value(title),
      lyrics: Value(lyrics),
    );
  }

  factory HymnSearchData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HymnSearchData(
      hymnId: serializer.fromJson<String>(json['hymn_id']),
      number: serializer.fromJson<String>(json['number']),
      title: serializer.fromJson<String>(json['title']),
      lyrics: serializer.fromJson<String>(json['lyrics']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hymn_id': serializer.toJson<String>(hymnId),
      'number': serializer.toJson<String>(number),
      'title': serializer.toJson<String>(title),
      'lyrics': serializer.toJson<String>(lyrics),
    };
  }

  HymnSearchData copyWith({
    String? hymnId,
    String? number,
    String? title,
    String? lyrics,
  }) => HymnSearchData(
    hymnId: hymnId ?? this.hymnId,
    number: number ?? this.number,
    title: title ?? this.title,
    lyrics: lyrics ?? this.lyrics,
  );
  HymnSearchData copyWithCompanion(HymnSearchCompanion data) {
    return HymnSearchData(
      hymnId: data.hymnId.present ? data.hymnId.value : this.hymnId,
      number: data.number.present ? data.number.value : this.number,
      title: data.title.present ? data.title.value : this.title,
      lyrics: data.lyrics.present ? data.lyrics.value : this.lyrics,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HymnSearchData(')
          ..write('hymnId: $hymnId, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('lyrics: $lyrics')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(hymnId, number, title, lyrics);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HymnSearchData &&
          other.hymnId == this.hymnId &&
          other.number == this.number &&
          other.title == this.title &&
          other.lyrics == this.lyrics);
}

class HymnSearchCompanion extends UpdateCompanion<HymnSearchData> {
  final Value<String> hymnId;
  final Value<String> number;
  final Value<String> title;
  final Value<String> lyrics;
  final Value<int> rowid;
  const HymnSearchCompanion({
    this.hymnId = const Value.absent(),
    this.number = const Value.absent(),
    this.title = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HymnSearchCompanion.insert({
    required String hymnId,
    required String number,
    required String title,
    required String lyrics,
    this.rowid = const Value.absent(),
  }) : hymnId = Value(hymnId),
       number = Value(number),
       title = Value(title),
       lyrics = Value(lyrics);
  static Insertable<HymnSearchData> custom({
    Expression<String>? hymnId,
    Expression<String>? number,
    Expression<String>? title,
    Expression<String>? lyrics,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hymnId != null) 'hymn_id': hymnId,
      if (number != null) 'number': number,
      if (title != null) 'title': title,
      if (lyrics != null) 'lyrics': lyrics,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HymnSearchCompanion copyWith({
    Value<String>? hymnId,
    Value<String>? number,
    Value<String>? title,
    Value<String>? lyrics,
    Value<int>? rowid,
  }) {
    return HymnSearchCompanion(
      hymnId: hymnId ?? this.hymnId,
      number: number ?? this.number,
      title: title ?? this.title,
      lyrics: lyrics ?? this.lyrics,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hymnId.present) {
      map['hymn_id'] = Variable<String>(hymnId.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (lyrics.present) {
      map['lyrics'] = Variable<String>(lyrics.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HymnSearchCompanion(')
          ..write('hymnId: $hymnId, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('lyrics: $lyrics, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogHymnsTable extends CatalogHymns
    with TableInfo<$CatalogHymnsTable, CatalogHymnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogHymnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberLabelMeta = const VerificationMeta(
    'numberLabel',
  );
  @override
  late final GeneratedColumn<String> numberLabel = GeneratedColumn<String>(
    'number_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberNumericMeta = const VerificationMeta(
    'numberNumeric',
  );
  @override
  late final GeneratedColumn<int> numberNumeric = GeneratedColumn<int>(
    'number_numeric',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberSuffixMeta = const VerificationMeta(
    'numberSuffix',
  );
  @override
  late final GeneratedColumn<String> numberSuffix = GeneratedColumn<String>(
    'number_suffix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openingLineMeta = const VerificationMeta(
    'openingLine',
  );
  @override
  late final GeneratedColumn<String> openingLine = GeneratedColumn<String>(
    'opening_line',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortKeyMeta = const VerificationMeta(
    'sortKey',
  );
  @override
  late final GeneratedColumn<String> sortKey = GeneratedColumn<String>(
    'sort_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    numberLabel,
    numberNumeric,
    numberSuffix,
    title,
    openingLine,
    sortKey,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_hymns';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogHymnRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('number_label')) {
      context.handle(
        _numberLabelMeta,
        numberLabel.isAcceptableOrUnknown(
          data['number_label']!,
          _numberLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_numberLabelMeta);
    }
    if (data.containsKey('number_numeric')) {
      context.handle(
        _numberNumericMeta,
        numberNumeric.isAcceptableOrUnknown(
          data['number_numeric']!,
          _numberNumericMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_numberNumericMeta);
    }
    if (data.containsKey('number_suffix')) {
      context.handle(
        _numberSuffixMeta,
        numberSuffix.isAcceptableOrUnknown(
          data['number_suffix']!,
          _numberSuffixMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('opening_line')) {
      context.handle(
        _openingLineMeta,
        openingLine.isAcceptableOrUnknown(
          data['opening_line']!,
          _openingLineMeta,
        ),
      );
    }
    if (data.containsKey('sort_key')) {
      context.handle(
        _sortKeyMeta,
        sortKey.isAcceptableOrUnknown(data['sort_key']!, _sortKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_sortKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogHymnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogHymnRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      numberLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number_label'],
      )!,
      numberNumeric: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number_numeric'],
      )!,
      numberSuffix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number_suffix'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      openingLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opening_line'],
      ),
      sortKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $CatalogHymnsTable createAlias(String alias) {
    return $CatalogHymnsTable(attachedDatabase, alias);
  }
}

class CatalogHymnRow extends DataClass implements Insertable<CatalogHymnRow> {
  final String id;
  final String numberLabel;
  final int numberNumeric;
  final String? numberSuffix;
  final String title;
  final String? openingLine;

  /// Clé de tri alphabétique (titre normalisé).
  final String sortKey;

  /// Contenu complet (JSON PublishedHymn), validé avant insertion.
  final String payload;
  const CatalogHymnRow({
    required this.id,
    required this.numberLabel,
    required this.numberNumeric,
    this.numberSuffix,
    required this.title,
    this.openingLine,
    required this.sortKey,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['number_label'] = Variable<String>(numberLabel);
    map['number_numeric'] = Variable<int>(numberNumeric);
    if (!nullToAbsent || numberSuffix != null) {
      map['number_suffix'] = Variable<String>(numberSuffix);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || openingLine != null) {
      map['opening_line'] = Variable<String>(openingLine);
    }
    map['sort_key'] = Variable<String>(sortKey);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CatalogHymnsCompanion toCompanion(bool nullToAbsent) {
    return CatalogHymnsCompanion(
      id: Value(id),
      numberLabel: Value(numberLabel),
      numberNumeric: Value(numberNumeric),
      numberSuffix: numberSuffix == null && nullToAbsent
          ? const Value.absent()
          : Value(numberSuffix),
      title: Value(title),
      openingLine: openingLine == null && nullToAbsent
          ? const Value.absent()
          : Value(openingLine),
      sortKey: Value(sortKey),
      payload: Value(payload),
    );
  }

  factory CatalogHymnRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogHymnRow(
      id: serializer.fromJson<String>(json['id']),
      numberLabel: serializer.fromJson<String>(json['numberLabel']),
      numberNumeric: serializer.fromJson<int>(json['numberNumeric']),
      numberSuffix: serializer.fromJson<String?>(json['numberSuffix']),
      title: serializer.fromJson<String>(json['title']),
      openingLine: serializer.fromJson<String?>(json['openingLine']),
      sortKey: serializer.fromJson<String>(json['sortKey']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'numberLabel': serializer.toJson<String>(numberLabel),
      'numberNumeric': serializer.toJson<int>(numberNumeric),
      'numberSuffix': serializer.toJson<String?>(numberSuffix),
      'title': serializer.toJson<String>(title),
      'openingLine': serializer.toJson<String?>(openingLine),
      'sortKey': serializer.toJson<String>(sortKey),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CatalogHymnRow copyWith({
    String? id,
    String? numberLabel,
    int? numberNumeric,
    Value<String?> numberSuffix = const Value.absent(),
    String? title,
    Value<String?> openingLine = const Value.absent(),
    String? sortKey,
    String? payload,
  }) => CatalogHymnRow(
    id: id ?? this.id,
    numberLabel: numberLabel ?? this.numberLabel,
    numberNumeric: numberNumeric ?? this.numberNumeric,
    numberSuffix: numberSuffix.present ? numberSuffix.value : this.numberSuffix,
    title: title ?? this.title,
    openingLine: openingLine.present ? openingLine.value : this.openingLine,
    sortKey: sortKey ?? this.sortKey,
    payload: payload ?? this.payload,
  );
  CatalogHymnRow copyWithCompanion(CatalogHymnsCompanion data) {
    return CatalogHymnRow(
      id: data.id.present ? data.id.value : this.id,
      numberLabel: data.numberLabel.present
          ? data.numberLabel.value
          : this.numberLabel,
      numberNumeric: data.numberNumeric.present
          ? data.numberNumeric.value
          : this.numberNumeric,
      numberSuffix: data.numberSuffix.present
          ? data.numberSuffix.value
          : this.numberSuffix,
      title: data.title.present ? data.title.value : this.title,
      openingLine: data.openingLine.present
          ? data.openingLine.value
          : this.openingLine,
      sortKey: data.sortKey.present ? data.sortKey.value : this.sortKey,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogHymnRow(')
          ..write('id: $id, ')
          ..write('numberLabel: $numberLabel, ')
          ..write('numberNumeric: $numberNumeric, ')
          ..write('numberSuffix: $numberSuffix, ')
          ..write('title: $title, ')
          ..write('openingLine: $openingLine, ')
          ..write('sortKey: $sortKey, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    numberLabel,
    numberNumeric,
    numberSuffix,
    title,
    openingLine,
    sortKey,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogHymnRow &&
          other.id == this.id &&
          other.numberLabel == this.numberLabel &&
          other.numberNumeric == this.numberNumeric &&
          other.numberSuffix == this.numberSuffix &&
          other.title == this.title &&
          other.openingLine == this.openingLine &&
          other.sortKey == this.sortKey &&
          other.payload == this.payload);
}

class CatalogHymnsCompanion extends UpdateCompanion<CatalogHymnRow> {
  final Value<String> id;
  final Value<String> numberLabel;
  final Value<int> numberNumeric;
  final Value<String?> numberSuffix;
  final Value<String> title;
  final Value<String?> openingLine;
  final Value<String> sortKey;
  final Value<String> payload;
  final Value<int> rowid;
  const CatalogHymnsCompanion({
    this.id = const Value.absent(),
    this.numberLabel = const Value.absent(),
    this.numberNumeric = const Value.absent(),
    this.numberSuffix = const Value.absent(),
    this.title = const Value.absent(),
    this.openingLine = const Value.absent(),
    this.sortKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogHymnsCompanion.insert({
    required String id,
    required String numberLabel,
    required int numberNumeric,
    this.numberSuffix = const Value.absent(),
    required String title,
    this.openingLine = const Value.absent(),
    required String sortKey,
    required String payload,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       numberLabel = Value(numberLabel),
       numberNumeric = Value(numberNumeric),
       title = Value(title),
       sortKey = Value(sortKey),
       payload = Value(payload);
  static Insertable<CatalogHymnRow> custom({
    Expression<String>? id,
    Expression<String>? numberLabel,
    Expression<int>? numberNumeric,
    Expression<String>? numberSuffix,
    Expression<String>? title,
    Expression<String>? openingLine,
    Expression<String>? sortKey,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (numberLabel != null) 'number_label': numberLabel,
      if (numberNumeric != null) 'number_numeric': numberNumeric,
      if (numberSuffix != null) 'number_suffix': numberSuffix,
      if (title != null) 'title': title,
      if (openingLine != null) 'opening_line': openingLine,
      if (sortKey != null) 'sort_key': sortKey,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogHymnsCompanion copyWith({
    Value<String>? id,
    Value<String>? numberLabel,
    Value<int>? numberNumeric,
    Value<String?>? numberSuffix,
    Value<String>? title,
    Value<String?>? openingLine,
    Value<String>? sortKey,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return CatalogHymnsCompanion(
      id: id ?? this.id,
      numberLabel: numberLabel ?? this.numberLabel,
      numberNumeric: numberNumeric ?? this.numberNumeric,
      numberSuffix: numberSuffix ?? this.numberSuffix,
      title: title ?? this.title,
      openingLine: openingLine ?? this.openingLine,
      sortKey: sortKey ?? this.sortKey,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (numberLabel.present) {
      map['number_label'] = Variable<String>(numberLabel.value);
    }
    if (numberNumeric.present) {
      map['number_numeric'] = Variable<int>(numberNumeric.value);
    }
    if (numberSuffix.present) {
      map['number_suffix'] = Variable<String>(numberSuffix.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (openingLine.present) {
      map['opening_line'] = Variable<String>(openingLine.value);
    }
    if (sortKey.present) {
      map['sort_key'] = Variable<String>(sortKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogHymnsCompanion(')
          ..write('id: $id, ')
          ..write('numberLabel: $numberLabel, ')
          ..write('numberNumeric: $numberNumeric, ')
          ..write('numberSuffix: $numberSuffix, ')
          ..write('title: $title, ')
          ..write('openingLine: $openingLine, ')
          ..write('sortKey: $sortKey, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hymnIdMeta = const VerificationMeta('hymnId');
  @override
  late final GeneratedColumn<String> hymnId = GeneratedColumn<String>(
    'hymn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [hymnId, isFavorite, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hymn_id')) {
      context.handle(
        _hymnIdMeta,
        hymnId.isAcceptableOrUnknown(data['hymn_id']!, _hymnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hymnIdMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    } else if (isInserting) {
      context.missing(_isFavoriteMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hymnId};
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      hymnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hymn_id'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final String hymnId;
  final bool isFavorite;
  final DateTime updatedAt;
  const FavoriteRow({
    required this.hymnId,
    required this.isFavorite,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hymn_id'] = Variable<String>(hymnId);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      hymnId: Value(hymnId),
      isFavorite: Value(isFavorite),
      updatedAt: Value(updatedAt),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      hymnId: serializer.fromJson<String>(json['hymnId']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hymnId': serializer.toJson<String>(hymnId),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FavoriteRow copyWith({
    String? hymnId,
    bool? isFavorite,
    DateTime? updatedAt,
  }) => FavoriteRow(
    hymnId: hymnId ?? this.hymnId,
    isFavorite: isFavorite ?? this.isFavorite,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FavoriteRow copyWithCompanion(FavoritesCompanion data) {
    return FavoriteRow(
      hymnId: data.hymnId.present ? data.hymnId.value : this.hymnId,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('hymnId: $hymnId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(hymnId, isFavorite, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.hymnId == this.hymnId &&
          other.isFavorite == this.isFavorite &&
          other.updatedAt == this.updatedAt);
}

class FavoritesCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<String> hymnId;
  final Value<bool> isFavorite;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.hymnId = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String hymnId,
    required bool isFavorite,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : hymnId = Value(hymnId),
       isFavorite = Value(isFavorite),
       updatedAt = Value(updatedAt);
  static Insertable<FavoriteRow> custom({
    Expression<String>? hymnId,
    Expression<bool>? isFavorite,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hymnId != null) 'hymn_id': hymnId,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? hymnId,
    Value<bool>? isFavorite,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      hymnId: hymnId ?? this.hymnId,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hymnId.present) {
      map['hymn_id'] = Variable<String>(hymnId.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('hymnId: $hymnId, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    icon,
    color,
    deleted,
    updatedAt,
    serverRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final String id;
  final String name;
  final String? description;

  /// Icône et couleur choisies (noms de [ListIcon] et [ListColor]), ou null.
  final String? icon;
  final String? color;
  final bool deleted;
  final DateTime updatedAt;
  final int serverRevision;
  const PlaylistRow({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    required this.deleted,
    required this.updatedAt,
    required this.serverRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['server_revision'] = Variable<int>(serverRevision);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      serverRevision: Value(serverRevision),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
    };
  }

  PlaylistRow copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
    bool? deleted,
    DateTime? updatedAt,
    int? serverRevision,
  }) => PlaylistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    serverRevision: serverRevision ?? this.serverRevision,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverRevision: $serverRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    icon,
    color,
    deleted,
    updatedAt,
    serverRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.serverRevision == this.serverRevision);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<bool> deleted;
  final Value<DateTime> updatedAt;
  final Value<int> serverRevision;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.deleted = const Value.absent(),
    required DateTime updatedAt,
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<PlaylistRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<bool>? deleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? serverRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? icon,
    Value<String?>? color,
    Value<bool>? deleted,
    Value<DateTime>? updatedAt,
    Value<int>? serverRevision,
    Value<int>? rowid,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistItemsTable extends PlaylistItems
    with TableInfo<$PlaylistItemsTable, PlaylistItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _hymnIdMeta = const VerificationMeta('hymnId');
  @override
  late final GeneratedColumn<String> hymnId = GeneratedColumn<String>(
    'hymn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, hymnId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('hymn_id')) {
      context.handle(
        _hymnIdMeta,
        hymnId.isAcceptableOrUnknown(data['hymn_id']!, _hymnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hymnIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, position};
  @override
  PlaylistItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistItemRow(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      hymnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hymn_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistItemsTable createAlias(String alias) {
    return $PlaylistItemsTable(attachedDatabase, alias);
  }
}

class PlaylistItemRow extends DataClass implements Insertable<PlaylistItemRow> {
  final String playlistId;
  final String hymnId;
  final int position;
  const PlaylistItemRow({
    required this.playlistId,
    required this.hymnId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['hymn_id'] = Variable<String>(hymnId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistItemsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistItemsCompanion(
      playlistId: Value(playlistId),
      hymnId: Value(hymnId),
      position: Value(position),
    );
  }

  factory PlaylistItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistItemRow(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      hymnId: serializer.fromJson<String>(json['hymnId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'hymnId': serializer.toJson<String>(hymnId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistItemRow copyWith({
    String? playlistId,
    String? hymnId,
    int? position,
  }) => PlaylistItemRow(
    playlistId: playlistId ?? this.playlistId,
    hymnId: hymnId ?? this.hymnId,
    position: position ?? this.position,
  );
  PlaylistItemRow copyWithCompanion(PlaylistItemsCompanion data) {
    return PlaylistItemRow(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      hymnId: data.hymnId.present ? data.hymnId.value : this.hymnId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItemRow(')
          ..write('playlistId: $playlistId, ')
          ..write('hymnId: $hymnId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, hymnId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistItemRow &&
          other.playlistId == this.playlistId &&
          other.hymnId == this.hymnId &&
          other.position == this.position);
}

class PlaylistItemsCompanion extends UpdateCompanion<PlaylistItemRow> {
  final Value<String> playlistId;
  final Value<String> hymnId;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistItemsCompanion({
    this.playlistId = const Value.absent(),
    this.hymnId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistItemsCompanion.insert({
    required String playlistId,
    required String hymnId,
    required int position,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       hymnId = Value(hymnId),
       position = Value(position);
  static Insertable<PlaylistItemRow> custom({
    Expression<String>? playlistId,
    Expression<String>? hymnId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (hymnId != null) 'hymn_id': hymnId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistItemsCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? hymnId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PlaylistItemsCompanion(
      playlistId: playlistId ?? this.playlistId,
      hymnId: hymnId ?? this.hymnId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (hymnId.present) {
      map['hymn_id'] = Variable<String>(hymnId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItemsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('hymnId: $hymnId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorshipServicesTable extends WorshipServices
    with TableInfo<$WorshipServicesTable, WorshipServiceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorshipServicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceDateMeta = const VerificationMeta(
    'serviceDate',
  );
  @override
  late final GeneratedColumn<String> serviceDate = GeneratedColumn<String>(
    'service_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverMeta = const VerificationMeta('cover');
  @override
  late final GeneratedColumn<String> cover = GeneratedColumn<String>(
    'cover',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isTemplateMeta = const VerificationMeta(
    'isTemplate',
  );
  @override
  late final GeneratedColumn<bool> isTemplate = GeneratedColumn<bool>(
    'is_template',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_template" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _optionsMeta = const VerificationMeta(
    'options',
  );
  @override
  late final GeneratedColumn<String> options = GeneratedColumn<String>(
    'options',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverRevisionMeta = const VerificationMeta(
    'serverRevision',
  );
  @override
  late final GeneratedColumn<int> serverRevision = GeneratedColumn<int>(
    'server_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    serviceDate,
    status,
    location,
    description,
    cover,
    isTemplate,
    options,
    deleted,
    updatedAt,
    serverRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worship_services';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorshipServiceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('service_date')) {
      context.handle(
        _serviceDateMeta,
        serviceDate.isAcceptableOrUnknown(
          data['service_date']!,
          _serviceDateMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cover')) {
      context.handle(
        _coverMeta,
        cover.isAcceptableOrUnknown(data['cover']!, _coverMeta),
      );
    }
    if (data.containsKey('is_template')) {
      context.handle(
        _isTemplateMeta,
        isTemplate.isAcceptableOrUnknown(data['is_template']!, _isTemplateMeta),
      );
    }
    if (data.containsKey('options')) {
      context.handle(
        _optionsMeta,
        options.isAcceptableOrUnknown(data['options']!, _optionsMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_revision')) {
      context.handle(
        _serverRevisionMeta,
        serverRevision.isAcceptableOrUnknown(
          data['server_revision']!,
          _serverRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorshipServiceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorshipServiceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      serviceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      cover: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover'],
      ),
      isTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_template'],
      )!,
      options: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      serverRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_revision'],
      )!,
    );
  }

  @override
  $WorshipServicesTable createAlias(String alias) {
    return $WorshipServicesTable(attachedDatabase, alias);
  }
}

class WorshipServiceRow extends DataClass
    implements Insertable<WorshipServiceRow> {
  final String id;
  final String title;

  /// Date du culte au format AAAA-MM-JJ, ou null.
  final String? serviceDate;

  /// draft | published | archived
  final String status;

  /// Lieu, description, image d'illustration (photo de l'app) ; null si
  /// absents.
  final String? location;
  final String? description;
  final String? cover;

  /// Modèle réutilisable (hors des listes « À venir » et « Historique »).
  final bool isTemplate;

  /// Options de projection du programme (JSON, [ProgramOptions]).
  final String options;
  final bool deleted;
  final DateTime updatedAt;
  final int serverRevision;
  const WorshipServiceRow({
    required this.id,
    required this.title,
    this.serviceDate,
    required this.status,
    this.location,
    this.description,
    this.cover,
    required this.isTemplate,
    required this.options,
    required this.deleted,
    required this.updatedAt,
    required this.serverRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || serviceDate != null) {
      map['service_date'] = Variable<String>(serviceDate);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || cover != null) {
      map['cover'] = Variable<String>(cover);
    }
    map['is_template'] = Variable<bool>(isTemplate);
    map['options'] = Variable<String>(options);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['server_revision'] = Variable<int>(serverRevision);
    return map;
  }

  WorshipServicesCompanion toCompanion(bool nullToAbsent) {
    return WorshipServicesCompanion(
      id: Value(id),
      title: Value(title),
      serviceDate: serviceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(serviceDate),
      status: Value(status),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      cover: cover == null && nullToAbsent
          ? const Value.absent()
          : Value(cover),
      isTemplate: Value(isTemplate),
      options: Value(options),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      serverRevision: Value(serverRevision),
    );
  }

  factory WorshipServiceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorshipServiceRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      serviceDate: serializer.fromJson<String?>(json['serviceDate']),
      status: serializer.fromJson<String>(json['status']),
      location: serializer.fromJson<String?>(json['location']),
      description: serializer.fromJson<String?>(json['description']),
      cover: serializer.fromJson<String?>(json['cover']),
      isTemplate: serializer.fromJson<bool>(json['isTemplate']),
      options: serializer.fromJson<String>(json['options']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverRevision: serializer.fromJson<int>(json['serverRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'serviceDate': serializer.toJson<String?>(serviceDate),
      'status': serializer.toJson<String>(status),
      'location': serializer.toJson<String?>(location),
      'description': serializer.toJson<String?>(description),
      'cover': serializer.toJson<String?>(cover),
      'isTemplate': serializer.toJson<bool>(isTemplate),
      'options': serializer.toJson<String>(options),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverRevision': serializer.toJson<int>(serverRevision),
    };
  }

  WorshipServiceRow copyWith({
    String? id,
    String? title,
    Value<String?> serviceDate = const Value.absent(),
    String? status,
    Value<String?> location = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    bool? isTemplate,
    String? options,
    bool? deleted,
    DateTime? updatedAt,
    int? serverRevision,
  }) => WorshipServiceRow(
    id: id ?? this.id,
    title: title ?? this.title,
    serviceDate: serviceDate.present ? serviceDate.value : this.serviceDate,
    status: status ?? this.status,
    location: location.present ? location.value : this.location,
    description: description.present ? description.value : this.description,
    cover: cover.present ? cover.value : this.cover,
    isTemplate: isTemplate ?? this.isTemplate,
    options: options ?? this.options,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    serverRevision: serverRevision ?? this.serverRevision,
  );
  WorshipServiceRow copyWithCompanion(WorshipServicesCompanion data) {
    return WorshipServiceRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      serviceDate: data.serviceDate.present
          ? data.serviceDate.value
          : this.serviceDate,
      status: data.status.present ? data.status.value : this.status,
      location: data.location.present ? data.location.value : this.location,
      description: data.description.present
          ? data.description.value
          : this.description,
      cover: data.cover.present ? data.cover.value : this.cover,
      isTemplate: data.isTemplate.present
          ? data.isTemplate.value
          : this.isTemplate,
      options: data.options.present ? data.options.value : this.options,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverRevision: data.serverRevision.present
          ? data.serverRevision.value
          : this.serverRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorshipServiceRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('serviceDate: $serviceDate, ')
          ..write('status: $status, ')
          ..write('location: $location, ')
          ..write('description: $description, ')
          ..write('cover: $cover, ')
          ..write('isTemplate: $isTemplate, ')
          ..write('options: $options, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverRevision: $serverRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    serviceDate,
    status,
    location,
    description,
    cover,
    isTemplate,
    options,
    deleted,
    updatedAt,
    serverRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorshipServiceRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.serviceDate == this.serviceDate &&
          other.status == this.status &&
          other.location == this.location &&
          other.description == this.description &&
          other.cover == this.cover &&
          other.isTemplate == this.isTemplate &&
          other.options == this.options &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.serverRevision == this.serverRevision);
}

class WorshipServicesCompanion extends UpdateCompanion<WorshipServiceRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> serviceDate;
  final Value<String> status;
  final Value<String?> location;
  final Value<String?> description;
  final Value<String?> cover;
  final Value<bool> isTemplate;
  final Value<String> options;
  final Value<bool> deleted;
  final Value<DateTime> updatedAt;
  final Value<int> serverRevision;
  final Value<int> rowid;
  const WorshipServicesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.serviceDate = const Value.absent(),
    this.status = const Value.absent(),
    this.location = const Value.absent(),
    this.description = const Value.absent(),
    this.cover = const Value.absent(),
    this.isTemplate = const Value.absent(),
    this.options = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorshipServicesCompanion.insert({
    required String id,
    required String title,
    this.serviceDate = const Value.absent(),
    this.status = const Value.absent(),
    this.location = const Value.absent(),
    this.description = const Value.absent(),
    this.cover = const Value.absent(),
    this.isTemplate = const Value.absent(),
    this.options = const Value.absent(),
    this.deleted = const Value.absent(),
    required DateTime updatedAt,
    this.serverRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<WorshipServiceRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? serviceDate,
    Expression<String>? status,
    Expression<String>? location,
    Expression<String>? description,
    Expression<String>? cover,
    Expression<bool>? isTemplate,
    Expression<String>? options,
    Expression<bool>? deleted,
    Expression<DateTime>? updatedAt,
    Expression<int>? serverRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (serviceDate != null) 'service_date': serviceDate,
      if (status != null) 'status': status,
      if (location != null) 'location': location,
      if (description != null) 'description': description,
      if (cover != null) 'cover': cover,
      if (isTemplate != null) 'is_template': isTemplate,
      if (options != null) 'options': options,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverRevision != null) 'server_revision': serverRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorshipServicesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? serviceDate,
    Value<String>? status,
    Value<String?>? location,
    Value<String?>? description,
    Value<String?>? cover,
    Value<bool>? isTemplate,
    Value<String>? options,
    Value<bool>? deleted,
    Value<DateTime>? updatedAt,
    Value<int>? serverRevision,
    Value<int>? rowid,
  }) {
    return WorshipServicesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      serviceDate: serviceDate ?? this.serviceDate,
      status: status ?? this.status,
      location: location ?? this.location,
      description: description ?? this.description,
      cover: cover ?? this.cover,
      isTemplate: isTemplate ?? this.isTemplate,
      options: options ?? this.options,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      serverRevision: serverRevision ?? this.serverRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (serviceDate.present) {
      map['service_date'] = Variable<String>(serviceDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (cover.present) {
      map['cover'] = Variable<String>(cover.value);
    }
    if (isTemplate.present) {
      map['is_template'] = Variable<bool>(isTemplate.value);
    }
    if (options.present) {
      map['options'] = Variable<String>(options.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverRevision.present) {
      map['server_revision'] = Variable<int>(serverRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorshipServicesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('serviceDate: $serviceDate, ')
          ..write('status: $status, ')
          ..write('location: $location, ')
          ..write('description: $description, ')
          ..write('cover: $cover, ')
          ..write('isTemplate: $isTemplate, ')
          ..write('options: $options, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverRevision: $serverRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorshipServiceItemsTable extends WorshipServiceItems
    with TableInfo<$WorshipServiceItemsTable, WorshipServiceItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorshipServiceItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceIdMeta = const VerificationMeta(
    'serviceId',
  );
  @override
  late final GeneratedColumn<String> serviceId = GeneratedColumn<String>(
    'service_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES worship_services (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _hymnIdMeta = const VerificationMeta('hymnId');
  @override
  late final GeneratedColumn<String> hymnId = GeneratedColumn<String>(
    'hymn_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serviceId,
    hymnId,
    label,
    notes,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worship_service_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorshipServiceItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('service_id')) {
      context.handle(
        _serviceIdMeta,
        serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serviceIdMeta);
    }
    if (data.containsKey('hymn_id')) {
      context.handle(
        _hymnIdMeta,
        hymnId.isAcceptableOrUnknown(data['hymn_id']!, _hymnIdMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorshipServiceItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorshipServiceItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_id'],
      )!,
      hymnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hymn_id'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $WorshipServiceItemsTable createAlias(String alias) {
    return $WorshipServiceItemsTable(attachedDatabase, alias);
  }
}

class WorshipServiceItemRow extends DataClass
    implements Insertable<WorshipServiceItemRow> {
  final String id;
  final String serviceId;
  final String? hymnId;
  final String? label;
  final String? notes;
  final int position;
  const WorshipServiceItemRow({
    required this.id,
    required this.serviceId,
    this.hymnId,
    this.label,
    this.notes,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['service_id'] = Variable<String>(serviceId);
    if (!nullToAbsent || hymnId != null) {
      map['hymn_id'] = Variable<String>(hymnId);
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  WorshipServiceItemsCompanion toCompanion(bool nullToAbsent) {
    return WorshipServiceItemsCompanion(
      id: Value(id),
      serviceId: Value(serviceId),
      hymnId: hymnId == null && nullToAbsent
          ? const Value.absent()
          : Value(hymnId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      position: Value(position),
    );
  }

  factory WorshipServiceItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorshipServiceItemRow(
      id: serializer.fromJson<String>(json['id']),
      serviceId: serializer.fromJson<String>(json['serviceId']),
      hymnId: serializer.fromJson<String?>(json['hymnId']),
      label: serializer.fromJson<String?>(json['label']),
      notes: serializer.fromJson<String?>(json['notes']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serviceId': serializer.toJson<String>(serviceId),
      'hymnId': serializer.toJson<String?>(hymnId),
      'label': serializer.toJson<String?>(label),
      'notes': serializer.toJson<String?>(notes),
      'position': serializer.toJson<int>(position),
    };
  }

  WorshipServiceItemRow copyWith({
    String? id,
    String? serviceId,
    Value<String?> hymnId = const Value.absent(),
    Value<String?> label = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    int? position,
  }) => WorshipServiceItemRow(
    id: id ?? this.id,
    serviceId: serviceId ?? this.serviceId,
    hymnId: hymnId.present ? hymnId.value : this.hymnId,
    label: label.present ? label.value : this.label,
    notes: notes.present ? notes.value : this.notes,
    position: position ?? this.position,
  );
  WorshipServiceItemRow copyWithCompanion(WorshipServiceItemsCompanion data) {
    return WorshipServiceItemRow(
      id: data.id.present ? data.id.value : this.id,
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      hymnId: data.hymnId.present ? data.hymnId.value : this.hymnId,
      label: data.label.present ? data.label.value : this.label,
      notes: data.notes.present ? data.notes.value : this.notes,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorshipServiceItemRow(')
          ..write('id: $id, ')
          ..write('serviceId: $serviceId, ')
          ..write('hymnId: $hymnId, ')
          ..write('label: $label, ')
          ..write('notes: $notes, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serviceId, hymnId, label, notes, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorshipServiceItemRow &&
          other.id == this.id &&
          other.serviceId == this.serviceId &&
          other.hymnId == this.hymnId &&
          other.label == this.label &&
          other.notes == this.notes &&
          other.position == this.position);
}

class WorshipServiceItemsCompanion
    extends UpdateCompanion<WorshipServiceItemRow> {
  final Value<String> id;
  final Value<String> serviceId;
  final Value<String?> hymnId;
  final Value<String?> label;
  final Value<String?> notes;
  final Value<int> position;
  final Value<int> rowid;
  const WorshipServiceItemsCompanion({
    this.id = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.hymnId = const Value.absent(),
    this.label = const Value.absent(),
    this.notes = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorshipServiceItemsCompanion.insert({
    required String id,
    required String serviceId,
    this.hymnId = const Value.absent(),
    this.label = const Value.absent(),
    this.notes = const Value.absent(),
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       serviceId = Value(serviceId),
       position = Value(position);
  static Insertable<WorshipServiceItemRow> custom({
    Expression<String>? id,
    Expression<String>? serviceId,
    Expression<String>? hymnId,
    Expression<String>? label,
    Expression<String>? notes,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serviceId != null) 'service_id': serviceId,
      if (hymnId != null) 'hymn_id': hymnId,
      if (label != null) 'label': label,
      if (notes != null) 'notes': notes,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorshipServiceItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? serviceId,
    Value<String?>? hymnId,
    Value<String?>? label,
    Value<String?>? notes,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return WorshipServiceItemsCompanion(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      hymnId: hymnId ?? this.hymnId,
      label: label ?? this.label,
      notes: notes ?? this.notes,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serviceId.present) {
      map['service_id'] = Variable<String>(serviceId.value);
    }
    if (hymnId.present) {
      map['hymn_id'] = Variable<String>(hymnId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorshipServiceItemsCompanion(')
          ..write('id: $id, ')
          ..write('serviceId: $serviceId, ')
          ..write('hymnId: $hymnId, ')
          ..write('label: $label, ')
          ..write('notes: $notes, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entity,
    entityId,
    version,
    attempts,
    lastError,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {entity, entityId},
  ];
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int id;

  /// favorite | playlist | worshipService
  final String entity;
  final String entityId;

  /// Incrémentée à chaque nouvelle modification de l'entité : une entrée
  /// envoyée n'est effacée que si elle n'a pas été modifiée entre-temps.
  final int version;
  final int attempts;
  final String? lastError;
  final DateTime updatedAt;
  const OutboxRow({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.version,
    required this.attempts,
    this.lastError,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['version'] = Variable<int>(version);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      entity: Value(entity),
      entityId: Value(entityId),
      version: Value(version),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      updatedAt: Value(updatedAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      version: serializer.fromJson<int>(json['version']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'version': serializer.toJson<int>(version),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? entity,
    String? entityId,
    int? version,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? updatedAt,
  }) => OutboxRow(
    id: id ?? this.id,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    version: version ?? this.version,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      version: data.version.present ? data.version.value : this.version,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entity,
    entityId,
    version,
    attempts,
    lastError,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.version == this.version &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.updatedAt == this.updatedAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<int> version;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> updatedAt;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.version = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String entity,
    required String entityId,
    this.version = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime updatedAt,
  }) : entity = Value(entity),
       entityId = Value(entityId),
       updatedAt = Value(updatedAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<int>? version,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (version != null) 'version': version,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? entity,
    Value<String>? entityId,
    Value<int>? version,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? updatedAt,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      version: version ?? this.version,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String key;
  final String value;
  const SyncStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncStateRow copyWith({String? key, String? value}) =>
      SyncStateRow(key: key ?? this.key, value: value ?? this.value);
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final HymnSearch hymnSearch = HymnSearch(this);
  late final $CatalogHymnsTable catalogHymns = $CatalogHymnsTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistItemsTable playlistItems = $PlaylistItemsTable(this);
  late final $WorshipServicesTable worshipServices = $WorshipServicesTable(
    this,
  );
  late final $WorshipServiceItemsTable worshipServiceItems =
      $WorshipServiceItemsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    hymnSearch,
    catalogHymns,
    favorites,
    playlists,
    playlistItems,
    worshipServices,
    worshipServiceItems,
    outbox,
    syncState,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'worship_services',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('worship_service_items', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $HymnSearchCreateCompanionBuilder = HymnSearchCompanion Function({
  required String hymnId,
  required String number,
  required String title,
  required String lyrics,
  Value<int> rowid,
});
typedef $HymnSearchUpdateCompanionBuilder = HymnSearchCompanion Function({
  Value<String> hymnId,
  Value<String> number,
  Value<String> title,
  Value<String> lyrics,
  Value<int> rowid,
});

class $HymnSearchFilterComposer extends Composer<_$AppDatabase, HymnSearch> {
  $HymnSearchFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hymnId => $composableBuilder(
    column: $table.hymnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyrics => $composableBuilder(
    column: $table.lyrics,
    builder: (column) => ColumnFilters(column),
  );
}

class $HymnSearchOrderingComposer extends Composer<_$AppDatabase, HymnSearch> {
  $HymnSearchOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hymnId => $composableBuilder(
    column: $table.hymnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyrics => $composableBuilder(
    column: $table.lyrics,
    builder: (column) => ColumnOrderings(column),
  );
}

class $HymnSearchAnnotationComposer
    extends Composer<_$AppDatabase, HymnSearch> {
  $HymnSearchAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hymnId =>
      $composableBuilder(column: $table.hymnId, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get lyrics =>
      $composableBuilder(column: $table.lyrics, builder: (column) => column);
}

class $HymnSearchTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          HymnSearch,
          HymnSearchData,
          $HymnSearchFilterComposer,
          $HymnSearchOrderingComposer,
          $HymnSearchAnnotationComposer,
          $HymnSearchCreateCompanionBuilder,
          $HymnSearchUpdateCompanionBuilder,
          (
            HymnSearchData,
            BaseReferences<_$AppDatabase, HymnSearch, HymnSearchData>,
          ),
          HymnSearchData,
          PrefetchHooks Function()
        > {
  $HymnSearchTableManager(_$AppDatabase db, HymnSearch table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $HymnSearchFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $HymnSearchOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $HymnSearchAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hymnId = const Value.absent(),
                Value<String> number = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> lyrics = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HymnSearchCompanion(
                hymnId: hymnId,
                number: number,
                title: title,
                lyrics: lyrics,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hymnId,
                required String number,
                required String title,
                required String lyrics,
                Value<int> rowid = const Value.absent(),
              }) => HymnSearchCompanion.insert(
                hymnId: hymnId,
                number: number,
                title: title,
                lyrics: lyrics,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<HymnSearch, HymnSearchData>(table),
                  BaseReferences<_$AppDatabase, HymnSearch, HymnSearchData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $HymnSearchProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      HymnSearch,
      HymnSearchData,
      $HymnSearchFilterComposer,
      $HymnSearchOrderingComposer,
      $HymnSearchAnnotationComposer,
      $HymnSearchCreateCompanionBuilder,
      $HymnSearchUpdateCompanionBuilder,
      (
        HymnSearchData,
        BaseReferences<_$AppDatabase, HymnSearch, HymnSearchData>,
      ),
      HymnSearchData,
      PrefetchHooks Function()
    >;
typedef $$CatalogHymnsTableCreateCompanionBuilder =
    CatalogHymnsCompanion Function({
      required String id,
      required String numberLabel,
      required int numberNumeric,
      Value<String?> numberSuffix,
      required String title,
      Value<String?> openingLine,
      required String sortKey,
      required String payload,
      Value<int> rowid,
    });
typedef $$CatalogHymnsTableUpdateCompanionBuilder =
    CatalogHymnsCompanion Function({
      Value<String> id,
      Value<String> numberLabel,
      Value<int> numberNumeric,
      Value<String?> numberSuffix,
      Value<String> title,
      Value<String?> openingLine,
      Value<String> sortKey,
      Value<String> payload,
      Value<int> rowid,
    });

class $$CatalogHymnsTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogHymnsTable> {
  $$CatalogHymnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get numberLabel => $composableBuilder(
    column: $table.numberLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numberNumeric => $composableBuilder(
    column: $table.numberNumeric,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get numberSuffix => $composableBuilder(
    column: $table.numberSuffix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openingLine => $composableBuilder(
    column: $table.openingLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogHymnsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogHymnsTable> {
  $$CatalogHymnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get numberLabel => $composableBuilder(
    column: $table.numberLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numberNumeric => $composableBuilder(
    column: $table.numberNumeric,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get numberSuffix => $composableBuilder(
    column: $table.numberSuffix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openingLine => $composableBuilder(
    column: $table.openingLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortKey => $composableBuilder(
    column: $table.sortKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogHymnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogHymnsTable> {
  $$CatalogHymnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get numberLabel => $composableBuilder(
    column: $table.numberLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get numberNumeric => $composableBuilder(
    column: $table.numberNumeric,
    builder: (column) => column,
  );

  GeneratedColumn<String> get numberSuffix => $composableBuilder(
    column: $table.numberSuffix,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get openingLine => $composableBuilder(
    column: $table.openingLine,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sortKey =>
      $composableBuilder(column: $table.sortKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$CatalogHymnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogHymnsTable,
          CatalogHymnRow,
          $$CatalogHymnsTableFilterComposer,
          $$CatalogHymnsTableOrderingComposer,
          $$CatalogHymnsTableAnnotationComposer,
          $$CatalogHymnsTableCreateCompanionBuilder,
          $$CatalogHymnsTableUpdateCompanionBuilder,
          (
            CatalogHymnRow,
            BaseReferences<_$AppDatabase, $CatalogHymnsTable, CatalogHymnRow>,
          ),
          CatalogHymnRow,
          PrefetchHooks Function()
        > {
  $$CatalogHymnsTableTableManager(_$AppDatabase db, $CatalogHymnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogHymnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogHymnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogHymnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> numberLabel = const Value.absent(),
                Value<int> numberNumeric = const Value.absent(),
                Value<String?> numberSuffix = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> openingLine = const Value.absent(),
                Value<String> sortKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogHymnsCompanion(
                id: id,
                numberLabel: numberLabel,
                numberNumeric: numberNumeric,
                numberSuffix: numberSuffix,
                title: title,
                openingLine: openingLine,
                sortKey: sortKey,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String numberLabel,
                required int numberNumeric,
                Value<String?> numberSuffix = const Value.absent(),
                required String title,
                Value<String?> openingLine = const Value.absent(),
                required String sortKey,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => CatalogHymnsCompanion.insert(
                id: id,
                numberLabel: numberLabel,
                numberNumeric: numberNumeric,
                numberSuffix: numberSuffix,
                title: title,
                openingLine: openingLine,
                sortKey: sortKey,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogHymnsTable, CatalogHymnRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CatalogHymnsTable,
                    CatalogHymnRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogHymnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogHymnsTable,
      CatalogHymnRow,
      $$CatalogHymnsTableFilterComposer,
      $$CatalogHymnsTableOrderingComposer,
      $$CatalogHymnsTableAnnotationComposer,
      $$CatalogHymnsTableCreateCompanionBuilder,
      $$CatalogHymnsTableUpdateCompanionBuilder,
      (
        CatalogHymnRow,
        BaseReferences<_$AppDatabase, $CatalogHymnsTable, CatalogHymnRow>,
      ),
      CatalogHymnRow,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder = FavoritesCompanion Function({
  required String hymnId,
  required bool isFavorite,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$FavoritesTableUpdateCompanionBuilder = FavoritesCompanion Function({
  Value<String> hymnId,
  Value<bool> isFavorite,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hymnId => $composableBuilder(
    column: $table.hymnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hymnId => $composableBuilder(
    column: $table.hymnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hymnId =>
      $composableBuilder(column: $table.hymnId, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          FavoriteRow,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (
            FavoriteRow,
            BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
          ),
          FavoriteRow,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hymnId = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                hymnId: hymnId,
                isFavorite: isFavorite,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hymnId,
                required bool isFavorite,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                hymnId: hymnId,
                isFavorite: isFavorite,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoritesTable, FavoriteRow>(table),
                  BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      FavoriteRow,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (
        FavoriteRow,
        BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
      ),
      FavoriteRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  required String id,
  required String name,
  Value<String?> description,
  Value<String?> icon,
  Value<String?> color,
  Value<bool> deleted,
  required DateTime updatedAt,
  Value<int> serverRevision,
  Value<int> rowid,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<String?> icon,
  Value<String?> color,
  Value<bool> deleted,
  Value<DateTime> updatedAt,
  Value<int> serverRevision,
  Value<int> rowid,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistRow> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistItemsTable, List<PlaylistItemRow>>
  _playlistItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistItems,
    aliasName: 'playlists__id__playlist_items__playlist_id',
  );

  $$PlaylistItemsTableProcessedTableManager get playlistItemsRefs {
    final manager = $$PlaylistItemsTableTableManager(
      $_db,
      $_db.playlistItems,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistItemsRefs(
    Expression<bool> Function($$PlaylistItemsTableFilterComposer f) f,
  ) {
    final $$PlaylistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistItems,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistItemsTableFilterComposer(
            $db: $db,
            $table: $db.playlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  Expression<T> playlistItemsRefs<T extends Object>(
    Expression<T> Function($$PlaylistItemsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistItems,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (PlaylistRow, $$PlaylistsTableReferences),
          PlaylistRow,
          PrefetchHooks Function({bool playlistItemsRefs})
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                description: description,
                icon: icon,
                color: color,
                deleted: deleted,
                updatedAt: updatedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required DateTime updatedAt,
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                description: description,
                icon: icon,
                color: color,
                deleted: deleted,
                updatedAt: updatedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, PlaylistRow>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistItemsRefs) db.playlistItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistItemsRefs)
                    await $_getPrefetchedData<
                      PlaylistRow,
                      $PlaylistsTable,
                      PlaylistItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (PlaylistRow, $$PlaylistsTableReferences),
      PlaylistRow,
      PrefetchHooks Function({bool playlistItemsRefs})
    >;
typedef $$PlaylistItemsTableCreateCompanionBuilder =
    PlaylistItemsCompanion Function({
      required String playlistId,
      required String hymnId,
      required int position,
      Value<int> rowid,
    });
typedef $$PlaylistItemsTableUpdateCompanionBuilder =
    PlaylistItemsCompanion Function({
      Value<String> playlistId,
      Value<String> hymnId,
      Value<int> position,
      Value<int> rowid,
    });

final class $$PlaylistItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PlaylistItemsTable, PlaylistItemRow> {
  $$PlaylistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_items__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hymnId => $composableBuilder(
    column: $table.hymnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hymnId => $composableBuilder(
    column: $table.hymnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hymnId =>
      $composableBuilder(column: $table.hymnId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistItemsTable,
          PlaylistItemRow,
          $$PlaylistItemsTableFilterComposer,
          $$PlaylistItemsTableOrderingComposer,
          $$PlaylistItemsTableAnnotationComposer,
          $$PlaylistItemsTableCreateCompanionBuilder,
          $$PlaylistItemsTableUpdateCompanionBuilder,
          (PlaylistItemRow, $$PlaylistItemsTableReferences),
          PlaylistItemRow,
          PrefetchHooks Function({bool playlistId})
        > {
  $$PlaylistItemsTableTableManager(_$AppDatabase db, $PlaylistItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> hymnId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistItemsCompanion(
                playlistId: playlistId,
                hymnId: hymnId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String hymnId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistItemsCompanion.insert(
                playlistId: playlistId,
                hymnId: hymnId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistItemsTable, PlaylistItemRow>(table),
                  $$PlaylistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistItemsTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistItemsTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistItemsTable,
      PlaylistItemRow,
      $$PlaylistItemsTableFilterComposer,
      $$PlaylistItemsTableOrderingComposer,
      $$PlaylistItemsTableAnnotationComposer,
      $$PlaylistItemsTableCreateCompanionBuilder,
      $$PlaylistItemsTableUpdateCompanionBuilder,
      (PlaylistItemRow, $$PlaylistItemsTableReferences),
      PlaylistItemRow,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$WorshipServicesTableCreateCompanionBuilder =
    WorshipServicesCompanion Function({
      required String id,
      required String title,
      Value<String?> serviceDate,
      Value<String> status,
      Value<String?> location,
      Value<String?> description,
      Value<String?> cover,
      Value<bool> isTemplate,
      Value<String> options,
      Value<bool> deleted,
      required DateTime updatedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });
typedef $$WorshipServicesTableUpdateCompanionBuilder =
    WorshipServicesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> serviceDate,
      Value<String> status,
      Value<String?> location,
      Value<String?> description,
      Value<String?> cover,
      Value<bool> isTemplate,
      Value<String> options,
      Value<bool> deleted,
      Value<DateTime> updatedAt,
      Value<int> serverRevision,
      Value<int> rowid,
    });

final class $$WorshipServicesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorshipServicesTable,
          WorshipServiceRow
        > {
  $$WorshipServicesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $WorshipServiceItemsTable,
    List<WorshipServiceItemRow>
  >
  _worshipServiceItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.worshipServiceItems,
        aliasName: 'worship_services__id__worship_service_items__service_id',
      );

  $$WorshipServiceItemsTableProcessedTableManager get worshipServiceItemsRefs {
    final manager = $$WorshipServiceItemsTableTableManager(
      $_db,
      $_db.worshipServiceItems,
    ).filter((f) => f.serviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _worshipServiceItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorshipServicesTableFilterComposer
    extends Composer<_$AppDatabase, $WorshipServicesTable> {
  $$WorshipServicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> worshipServiceItemsRefs(
    Expression<bool> Function($$WorshipServiceItemsTableFilterComposer f) f,
  ) {
    final $$WorshipServiceItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.worshipServiceItems,
      getReferencedColumn: (t) => t.serviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorshipServiceItemsTableFilterComposer(
            $db: $db,
            $table: $db.worshipServiceItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorshipServicesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorshipServicesTable> {
  $$WorshipServicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cover => $composableBuilder(
    column: $table.cover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get options => $composableBuilder(
    column: $table.options,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorshipServicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorshipServicesTable> {
  $$WorshipServicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cover =>
      $composableBuilder(column: $table.cover, builder: (column) => column);

  GeneratedColumn<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get options =>
      $composableBuilder(column: $table.options, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get serverRevision => $composableBuilder(
    column: $table.serverRevision,
    builder: (column) => column,
  );

  Expression<T> worshipServiceItemsRefs<T extends Object>(
    Expression<T> Function($$WorshipServiceItemsTableAnnotationComposer a) f,
  ) {
    final $$WorshipServiceItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.worshipServiceItems,
          getReferencedColumn: (t) => t.serviceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorshipServiceItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.worshipServiceItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorshipServicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorshipServicesTable,
          WorshipServiceRow,
          $$WorshipServicesTableFilterComposer,
          $$WorshipServicesTableOrderingComposer,
          $$WorshipServicesTableAnnotationComposer,
          $$WorshipServicesTableCreateCompanionBuilder,
          $$WorshipServicesTableUpdateCompanionBuilder,
          (WorshipServiceRow, $$WorshipServicesTableReferences),
          WorshipServiceRow,
          PrefetchHooks Function({bool worshipServiceItemsRefs})
        > {
  $$WorshipServicesTableTableManager(
    _$AppDatabase db,
    $WorshipServicesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorshipServicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorshipServicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorshipServicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> serviceDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<bool> isTemplate = const Value.absent(),
                Value<String> options = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorshipServicesCompanion(
                id: id,
                title: title,
                serviceDate: serviceDate,
                status: status,
                location: location,
                description: description,
                cover: cover,
                isTemplate: isTemplate,
                options: options,
                deleted: deleted,
                updatedAt: updatedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> serviceDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> cover = const Value.absent(),
                Value<bool> isTemplate = const Value.absent(),
                Value<String> options = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required DateTime updatedAt,
                Value<int> serverRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorshipServicesCompanion.insert(
                id: id,
                title: title,
                serviceDate: serviceDate,
                status: status,
                location: location,
                description: description,
                cover: cover,
                isTemplate: isTemplate,
                options: options,
                deleted: deleted,
                updatedAt: updatedAt,
                serverRevision: serverRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorshipServicesTable, WorshipServiceRow>(table),
                  $$WorshipServicesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({worshipServiceItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (worshipServiceItemsRefs) db.worshipServiceItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (worshipServiceItemsRefs)
                    await $_getPrefetchedData<
                      WorshipServiceRow,
                      $WorshipServicesTable,
                      WorshipServiceItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$WorshipServicesTableReferences
                          ._worshipServiceItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorshipServicesTableReferences(
                            db,
                            table,
                            p0,
                          ).worshipServiceItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.serviceId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorshipServicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorshipServicesTable,
      WorshipServiceRow,
      $$WorshipServicesTableFilterComposer,
      $$WorshipServicesTableOrderingComposer,
      $$WorshipServicesTableAnnotationComposer,
      $$WorshipServicesTableCreateCompanionBuilder,
      $$WorshipServicesTableUpdateCompanionBuilder,
      (WorshipServiceRow, $$WorshipServicesTableReferences),
      WorshipServiceRow,
      PrefetchHooks Function({bool worshipServiceItemsRefs})
    >;
typedef $$WorshipServiceItemsTableCreateCompanionBuilder =
    WorshipServiceItemsCompanion Function({
      required String id,
      required String serviceId,
      Value<String?> hymnId,
      Value<String?> label,
      Value<String?> notes,
      required int position,
      Value<int> rowid,
    });
typedef $$WorshipServiceItemsTableUpdateCompanionBuilder =
    WorshipServiceItemsCompanion Function({
      Value<String> id,
      Value<String> serviceId,
      Value<String?> hymnId,
      Value<String?> label,
      Value<String?> notes,
      Value<int> position,
      Value<int> rowid,
    });

final class $$WorshipServiceItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorshipServiceItemsTable,
          WorshipServiceItemRow
        > {
  $$WorshipServiceItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorshipServicesTable _serviceIdTable(_$AppDatabase db) => db
      .worshipServices
      .createAlias('worship_service_items__service_id__worship_services__id');

  $$WorshipServicesTableProcessedTableManager get serviceId {
    final $_column = $_itemColumn<String>('service_id')!;

    final manager = $$WorshipServicesTableTableManager(
      $_db,
      $_db.worshipServices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_serviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorshipServiceItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WorshipServiceItemsTable> {
  $$WorshipServiceItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hymnId => $composableBuilder(
    column: $table.hymnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$WorshipServicesTableFilterComposer get serviceId {
    final $$WorshipServicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serviceId,
      referencedTable: $db.worshipServices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorshipServicesTableFilterComposer(
            $db: $db,
            $table: $db.worshipServices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorshipServiceItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorshipServiceItemsTable> {
  $$WorshipServiceItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hymnId => $composableBuilder(
    column: $table.hymnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorshipServicesTableOrderingComposer get serviceId {
    final $$WorshipServicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serviceId,
      referencedTable: $db.worshipServices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorshipServicesTableOrderingComposer(
            $db: $db,
            $table: $db.worshipServices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorshipServiceItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorshipServiceItemsTable> {
  $$WorshipServiceItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hymnId =>
      $composableBuilder(column: $table.hymnId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$WorshipServicesTableAnnotationComposer get serviceId {
    final $$WorshipServicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serviceId,
      referencedTable: $db.worshipServices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorshipServicesTableAnnotationComposer(
            $db: $db,
            $table: $db.worshipServices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorshipServiceItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorshipServiceItemsTable,
          WorshipServiceItemRow,
          $$WorshipServiceItemsTableFilterComposer,
          $$WorshipServiceItemsTableOrderingComposer,
          $$WorshipServiceItemsTableAnnotationComposer,
          $$WorshipServiceItemsTableCreateCompanionBuilder,
          $$WorshipServiceItemsTableUpdateCompanionBuilder,
          (WorshipServiceItemRow, $$WorshipServiceItemsTableReferences),
          WorshipServiceItemRow,
          PrefetchHooks Function({bool serviceId})
        > {
  $$WorshipServiceItemsTableTableManager(
    _$AppDatabase db,
    $WorshipServiceItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorshipServiceItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorshipServiceItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorshipServiceItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> serviceId = const Value.absent(),
                Value<String?> hymnId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorshipServiceItemsCompanion(
                id: id,
                serviceId: serviceId,
                hymnId: hymnId,
                label: label,
                notes: notes,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String serviceId,
                Value<String?> hymnId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => WorshipServiceItemsCompanion.insert(
                id: id,
                serviceId: serviceId,
                hymnId: hymnId,
                label: label,
                notes: notes,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorshipServiceItemsTable, WorshipServiceItemRow>(
                    table,
                  ),
                  $$WorshipServiceItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({serviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (serviceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.serviceId,
                        referencedTable: $$WorshipServiceItemsTableReferences
                            ._serviceIdTable(db),
                        referencedColumn: $$WorshipServiceItemsTableReferences
                            ._serviceIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorshipServiceItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorshipServiceItemsTable,
      WorshipServiceItemRow,
      $$WorshipServiceItemsTableFilterComposer,
      $$WorshipServiceItemsTableOrderingComposer,
      $$WorshipServiceItemsTableAnnotationComposer,
      $$WorshipServiceItemsTableCreateCompanionBuilder,
      $$WorshipServiceItemsTableUpdateCompanionBuilder,
      (WorshipServiceItemRow, $$WorshipServiceItemsTableReferences),
      WorshipServiceItemRow,
      PrefetchHooks Function({bool serviceId})
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  required String entity,
  required String entityId,
  Value<int> version,
  Value<int> attempts,
  Value<String?> lastError,
  required DateTime updatedAt,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> id,
  Value<String> entity,
  Value<String> entityId,
  Value<int> version,
  Value<int> attempts,
  Value<String?> lastError,
  Value<DateTime> updatedAt,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                entity: entity,
                entityId: entityId,
                version: version,
                attempts: attempts,
                lastError: lastError,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entity,
                required String entityId,
                Value<int> version = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime updatedAt,
              }) => OutboxCompanion.insert(
                id: id,
                entity: entity,
                entityId: entityId,
                version: version,
                attempts: attempts,
                lastError: lastError,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateRow>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $HymnSearchTableManager get hymnSearch =>
      $HymnSearchTableManager(_db, _db.hymnSearch);
  $$CatalogHymnsTableTableManager get catalogHymns =>
      $$CatalogHymnsTableTableManager(_db, _db.catalogHymns);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistItemsTableTableManager get playlistItems =>
      $$PlaylistItemsTableTableManager(_db, _db.playlistItems);
  $$WorshipServicesTableTableManager get worshipServices =>
      $$WorshipServicesTableTableManager(_db, _db.worshipServices);
  $$WorshipServiceItemsTableTableManager get worshipServiceItems =>
      $$WorshipServiceItemsTableTableManager(_db, _db.worshipServiceItems);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
