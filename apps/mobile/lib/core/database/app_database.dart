import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Base locale (offline-first, ADR-005/006/007).
///
/// - Catalogue : copie de la dernière release publiée, en lecture seule pour
///   l'utilisateur ; contenu complet de chaque cantique dans [CatalogHymns.payload]
///   (JSON du contrat PublishedHymn) et index plein texte FTS5 `hymn_search`
///   (search.drift).
/// - Données utilisateur : écrites ici d'abord, puis envoyées via [Outbox].
@DriftDatabase(
  tables: [
    CatalogHymns,
    Favorites,
    Playlists,
    PlaylistItems,
    WorshipServices,
    WorshipServiceItems,
    Outbox,
    SyncState,
  ],
  include: {'search.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Version du schéma local. Toute modification de table impose de
  /// l'incrémenter et d'écrire une migration (test/drift/).
  static const currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 (planche 4) : icône et couleur des listes ; lieu, description,
      // image, modèle et options de projection des programmes.
      if (from < 2) {
        await m.addColumn(playlists, playlists.icon);
        await m.addColumn(playlists, playlists.color);
        await m.addColumn(worshipServices, worshipServices.location);
        await m.addColumn(worshipServices, worshipServices.description);
        await m.addColumn(worshipServices, worshipServices.cover);
        await m.addColumn(worshipServices, worshipServices.isTemplate);
        await m.addColumn(worshipServices, worshipServices.options);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Cantique de la release locale.
@DataClassName('CatalogHymnRow')
class CatalogHymns extends Table {
  TextColumn get id => text()();
  TextColumn get numberLabel => text()();
  IntColumn get numberNumeric => integer()();
  TextColumn get numberSuffix => text().nullable()();
  TextColumn get title => text()();
  TextColumn get openingLine => text().nullable()();

  /// Clé de tri alphabétique (titre normalisé).
  TextColumn get sortKey => text()();

  /// Contenu complet (JSON PublishedHymn), validé avant insertion.
  TextColumn get payload => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Favori (y compris pour un visiteur sans compte).
@DataClassName('FavoriteRow')
class Favorites extends Table {
  TextColumn get hymnId => text()();
  BoolColumn get isFavorite => boolean()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {hymnId};
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// Icône et couleur choisies (noms de [ListIcon] et [ListColor]), ou null.
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlaylistItemRow')
class PlaylistItems extends Table {
  TextColumn get playlistId =>
      text().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get hymnId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, position};
}

@DataClassName('WorshipServiceRow')
class WorshipServices extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();

  /// Date du culte au format AAAA-MM-JJ, ou null.
  TextColumn get serviceDate => text().nullable()();

  /// draft | published | archived
  TextColumn get status => text().withDefault(const Constant('draft'))();

  /// Lieu, description, image d'illustration (photo de l'app) ; null si
  /// absents.
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get cover => text().nullable()();

  /// Modèle réutilisable (hors des listes « À venir » et « Historique »).
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();

  /// Options de projection du programme (JSON, [ProgramOptions]).
  TextColumn get options => text().withDefault(const Constant('{}'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get serverRevision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WorshipServiceItemRow')
class WorshipServiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get serviceId =>
      text().references(WorshipServices, #id, onDelete: KeyAction.cascade)();
  TextColumn get hymnId => text().nullable()();
  TextColumn get label => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Modifications locales en attente d'envoi (une entrée par entité).
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// favorite | playlist | worshipService
  TextColumn get entity => text()();
  TextColumn get entityId => text()();

  /// Incrémentée à chaque nouvelle modification de l'entité : une entrée
  /// envoyée n'est effacée que si elle n'a pas été modifiée entre-temps.
  IntColumn get version => integer().withDefault(const Constant(1))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {entity, entityId},
  ];
}

/// Petites valeurs d'état (release locale, révision utilisateur…).
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
