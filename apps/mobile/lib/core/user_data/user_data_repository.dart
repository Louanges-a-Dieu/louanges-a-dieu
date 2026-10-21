import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'user_data_models.dart';

/// Données personnelles locales (favoris, listes, programmes). Chaque
/// modification est enregistrée immédiatement en local et ajoutée à la file
/// d'envoi (outbox) : elle fonctionne hors connexion (F-FAV-001, T-005).
class UserDataRepository {
  UserDataRepository(
    this._db, {
    DateTime Function()? now,
    String Function()? newId,
    this.onChanged,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? _uuidV4;

  final AppDatabase _db;

  /// Appelé après chaque modification locale (déclenche une synchronisation différée).
  final void Function()? onChanged;
  final DateTime Function() _now;
  final String Function() _newId;

  static const favorite = 'favorite';
  static const playlist = 'playlist';
  static const worshipService = 'worshipService';

  // ------------------------------------------------------------------ favoris

  /// Favoris du plus récent au plus ancien (onglet « Récents »).
  Stream<List<String>> watchRecentFavoriteIds() =>
      (_db.select(_db.favorites)
            ..where((f) => f.isFavorite.equals(true))
            ..orderBy([(f) => OrderingTerm.desc(f.updatedAt)]))
          .watch()
          .map((rows) => [for (final r in rows) r.hymnId]);

  Stream<Set<String>> watchFavoriteIds() =>
      (_db.select(_db.favorites)..where((f) => f.isFavorite.equals(true)))
          .watch()
          .map((rows) => {for (final r in rows) r.hymnId});

  Future<void> setFavorite(String hymnId, {required bool isFavorite}) =>
      _write(() async {
        await _db
            .into(_db.favorites)
            .insertOnConflictUpdate(
              FavoritesCompanion.insert(
                hymnId: hymnId,
                isFavorite: isFavorite,
                updatedAt: _now(),
              ),
            );
        await _enqueue(favorite, hymnId);
      });

  // ------------------------------------------------------------------- listes

  Stream<List<PlaylistRow>> watchPlaylists() =>
      (_db.select(_db.playlists)
            ..where((p) => p.deleted.equals(false))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .watch();

  Future<String> createPlaylist(
    String name, {
    String? description,
    String? icon,
    String? color,
  }) async {
    final id = _newId();
    await _write(() async {
      await _db
          .into(_db.playlists)
          .insert(
            PlaylistsCompanion.insert(
              id: id,
              name: _required(name, 'Nom de liste'),
              description: Value(_optional(description)),
              icon: Value(icon),
              color: Value(color),
              updatedAt: _now(),
            ),
          );
      await _enqueue(playlist, id);
    });
    return id;
  }

  Future<void> renamePlaylist(String id, String name) =>
      updatePlaylist(id, name: name);

  /// Modifie une liste ; les champs absents ne changent pas (`Value(null)`
  /// efface la description, l'icône ou la couleur).
  Future<void> updatePlaylist(
    String id, {
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
  }) => _write(() async {
    await (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
      PlaylistsCompanion(
        name: name == null
            ? const Value.absent()
            : Value(_required(name, 'Nom de liste')),
        description: description.present
            ? Value(_optional(description.value))
            : const Value.absent(),
        icon: icon,
        color: color,
        updatedAt: Value(_now()),
      ),
    );
    await _enqueue(playlist, id);
  });

  Future<void> deletePlaylist(String id) => _write(() async {
    await (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
      PlaylistsCompanion(deleted: const Value(true), updatedAt: Value(_now())),
    );
    await _enqueue(playlist, id);
  });

  /// Nombre de cantiques de chaque liste.
  Stream<Map<String, int>> watchPlaylistCounts() => _db
      .customSelect(
        'SELECT playlist_id, COUNT(*) AS n FROM playlist_items '
        'GROUP BY playlist_id',
        readsFrom: {_db.playlistItems},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('playlist_id'): r.read<int>('n'),
        },
      );

  /// Listes qui contiennent [hymnId].
  Stream<Set<String>> watchPlaylistsContaining(String hymnId) =>
      (_db.select(_db.playlistItems)..where((i) => i.hymnId.equals(hymnId)))
          .watch()
          .map((rows) => {for (final r in rows) r.playlistId});

  /// Contenu ordonné d'une liste, mis à jour en continu.
  Stream<List<String>> watchPlaylistHymnIds(String playlistId) =>
      (_db.select(_db.playlistItems)
            ..where((i) => i.playlistId.equals(playlistId))
            ..orderBy([(i) => OrderingTerm.asc(i.position)]))
          .watch()
          .map((rows) => [for (final r in rows) r.hymnId]);

  Future<List<String>> playlistHymnIds(String playlistId) async {
    final rows =
        await (_db.select(_db.playlistItems)
              ..where((i) => i.playlistId.equals(playlistId))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    return [for (final r in rows) r.hymnId];
  }

  /// Remplace le contenu ordonné de la liste (ajout, retrait, réordonnancement).
  Future<void> setPlaylistHymns(String playlistId, List<String> hymnIds) =>
      _write(() async {
        await _replacePlaylistItems(playlistId, hymnIds);
        await (_db.update(_db.playlists)..where((p) => p.id.equals(playlistId)))
            .write(PlaylistsCompanion(updatedAt: Value(_now())));
        await _enqueue(playlist, playlistId);
      });

  Future<void> _replacePlaylistItems(
    String playlistId,
    List<String> hymnIds,
  ) async {
    await (_db.delete(
      _db.playlistItems,
    )..where((i) => i.playlistId.equals(playlistId))).go();
    await _db.batch(
      (b) => b.insertAll(_db.playlistItems, [
        for (var i = 0; i < hymnIds.length; i++)
          PlaylistItemsCompanion.insert(
            playlistId: playlistId,
            hymnId: hymnIds[i],
            position: i,
          ),
      ]),
    );
  }

  // --------------------------------------------------------------- programmes

  Stream<List<WorshipServiceRow>> watchWorshipServices() =>
      (_db.select(_db.worshipServices)
            ..where((w) => w.deleted.equals(false))
            ..orderBy([(w) => OrderingTerm.desc(w.serviceDate)]))
          .watch();

  Future<String> createWorshipService(
    String title, {
    String? serviceDate,
    String? location,
    String? description,
    String? cover,
    bool isTemplate = false,
    String? options,
  }) async {
    final id = _newId();
    await _write(() async {
      await _db
          .into(_db.worshipServices)
          .insert(
            WorshipServicesCompanion.insert(
              id: id,
              title: _required(title, 'Titre du programme'),
              serviceDate: Value(serviceDate),
              location: Value(_optional(location)),
              description: Value(_optional(description)),
              cover: Value(cover),
              isTemplate: Value(isTemplate),
              options: options == null ? const Value.absent() : Value(options),
              updatedAt: _now(),
            ),
          );
      await _enqueue(worshipService, id);
    });
    return id;
  }

  /// Modifie un programme ; les champs absents ne changent pas
  /// (`Value(null)` efface le lieu, la description ou l'image).
  Future<void> updateWorshipService(
    String id, {
    String? title,
    String? serviceDate,
    String? status,
    Value<String?> location = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> cover = const Value.absent(),
    bool? isTemplate,
    ProgramOptions? options,
  }) => _write(() async {
    await (_db.update(
      _db.worshipServices,
    )..where((w) => w.id.equals(id))).write(
      WorshipServicesCompanion(
        title: title == null
            ? const Value.absent()
            : Value(_required(title, 'Titre du programme')),
        serviceDate: serviceDate == null
            ? const Value.absent()
            : Value(serviceDate),
        status: status == null ? const Value.absent() : Value(status),
        location: location.present
            ? Value(_optional(location.value))
            : const Value.absent(),
        description: description.present
            ? Value(_optional(description.value))
            : const Value.absent(),
        cover: cover,
        isTemplate: isTemplate == null
            ? const Value.absent()
            : Value(isTemplate),
        options: options == null
            ? const Value.absent()
            : Value(options.encode()),
        updatedAt: Value(_now()),
      ),
    );
    await _enqueue(worshipService, id);
  });

  Future<void> deleteWorshipService(String id) => _write(() async {
    await (_db.update(
      _db.worshipServices,
    )..where((w) => w.id.equals(id))).write(
      WorshipServicesCompanion(
        deleted: const Value(true),
        updatedAt: Value(_now()),
      ),
    );
    await _enqueue(worshipService, id);
  });

  /// Nombre de cantiques de chaque programme (moments libres exclus).
  Stream<Map<String, int>> watchWorshipHymnCounts() => _db
      .customSelect(
        'SELECT service_id, COUNT(*) AS n FROM worship_service_items '
        'WHERE hymn_id IS NOT NULL GROUP BY service_id',
        readsFrom: {_db.worshipServiceItems},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('service_id'): r.read<int>('n'),
        },
      );

  /// Éléments ordonnés d'un programme, mis à jour en continu.
  Stream<List<WorshipServiceItemRow>> watchWorshipServiceItems(
    String serviceId,
  ) =>
      (_db.select(_db.worshipServiceItems)
            ..where((i) => i.serviceId.equals(serviceId))
            ..orderBy([(i) => OrderingTerm.asc(i.position)]))
          .watch();

  /// Identifiant d'un nouvel élément de programme (créé hors connexion).
  String newItemId() => _newId();

  /// Copie un programme (titre fourni, même date, mêmes éléments, en
  /// brouillon) ; [isTemplate] : enregistrer comme modèle, ou créer un
  /// programme depuis un modèle ([serviceDate] remplace alors la date).
  Future<String> duplicateWorshipService(
    String sourceId, {
    required String title,
    bool isTemplate = false,
    String? serviceDate,
  }) async {
    final source = await (_db.select(
      _db.worshipServices,
    )..where((w) => w.id.equals(sourceId))).getSingle();
    final items = await worshipServiceItems(sourceId);
    final id = await createWorshipService(
      title,
      serviceDate: isTemplate ? null : serviceDate ?? source.serviceDate,
      location: source.location,
      description: source.description,
      cover: source.cover,
      isTemplate: isTemplate,
      options: source.options,
    );
    await setWorshipServiceItems(id, [
      for (final i in items)
        WorshipItemDto(
          id: _newId(),
          hymnId: i.hymnId,
          label: i.label,
          notes: i.notes,
        ),
    ]);
    return id;
  }

  Future<List<WorshipServiceItemRow>> worshipServiceItems(String serviceId) =>
      (_db.select(_db.worshipServiceItems)
            ..where((i) => i.serviceId.equals(serviceId))
            ..orderBy([(i) => OrderingTerm.asc(i.position)]))
          .get();

  /// Remplace les éléments ordonnés du programme (cantiques et sections libres).
  Future<void> setWorshipServiceItems(
    String serviceId,
    List<WorshipItemDto> items,
  ) => _write(() async {
    for (final item in items) {
      if (item.hymnId == null &&
          (item.label == null || item.label!.trim().isEmpty)) {
        throw ArgumentError(
          'Un élément est un cantique ou une section libre avec un libellé',
        );
      }
    }
    await _replaceWorshipItems(serviceId, items);
    await (_db.update(_db.worshipServices)
          ..where((w) => w.id.equals(serviceId)))
        .write(WorshipServicesCompanion(updatedAt: Value(_now())));
    await _enqueue(worshipService, serviceId);
  });

  Future<void> _replaceWorshipItems(
    String serviceId,
    List<WorshipItemDto> items,
  ) async {
    await (_db.delete(
      _db.worshipServiceItems,
    )..where((i) => i.serviceId.equals(serviceId))).go();
    await _db.batch(
      (b) => b.insertAll(_db.worshipServiceItems, [
        for (var i = 0; i < items.length; i++)
          WorshipServiceItemsCompanion.insert(
            id: items[i].id,
            serviceId: serviceId,
            hymnId: Value(items[i].hymnId),
            label: Value(_optional(items[i].label)),
            notes: Value(_optional(items[i].notes)),
            position: i,
          ),
      ]),
    );
  }

  // ------------------------------------------------- application des changements serveur

  /// Utilisé par la synchronisation pour appliquer l'état serveur.
  Future<void> applyRemotePlaylist(PlaylistDto p) async {
    await _db
        .into(_db.playlists)
        .insertOnConflictUpdate(
          PlaylistsCompanion.insert(
            id: p.id,
            name: p.name,
            description: Value(p.description),
            icon: Value(p.icon),
            color: Value(p.color),
            deleted: Value(p.deleted),
            updatedAt: _now(),
            serverRevision: Value(p.revision),
          ),
        );
    await _replacePlaylistItems(p.id, p.hymnIds);
  }

  Future<void> applyRemoteWorshipService(WorshipServiceDto w) async {
    await _db
        .into(_db.worshipServices)
        .insertOnConflictUpdate(
          WorshipServicesCompanion.insert(
            id: w.id,
            title: w.title,
            serviceDate: Value(w.serviceDate),
            status: Value(w.status),
            location: Value(w.location),
            description: Value(w.description),
            cover: Value(w.cover),
            isTemplate: Value(w.isTemplate),
            options: Value(jsonEncode(w.options)),
            deleted: Value(w.deleted),
            updatedAt: _now(),
            serverRevision: Value(w.revision),
          ),
        );
    await _replaceWorshipItems(w.id, w.items);
  }

  Future<void> applyRemoteFavorite(FavoriteChange f) => _db
      .into(_db.favorites)
      .insertOnConflictUpdate(
        FavoritesCompanion.insert(
          hymnId: f.hymnId,
          isFavorite: !f.deleted,
          updatedAt: _now(),
        ),
      );

  /// Écriture utilisateur : transaction, PUIS notification (jamais à
  /// l'intérieur de la transaction, sinon les lectures déclenchées par la
  /// notification seraient rattachées à une transaction déjà fermée).
  Future<T> _write<T>(Future<T> Function() action) async {
    final result = await _db.transaction(action);
    onChanged?.call();
    return result;
  }

  // -------------------------------------------------------------------- outbox

  Future<int> pendingCount() async {
    final c = _db.outbox.id.count();
    return (await (_db.selectOnly(
          _db.outbox,
        )..addColumns([c])).getSingle()).read(c) ??
        0;
  }

  Future<void> _enqueue(String entity, String entityId) async {
    await _db.customStatement(
      'INSERT INTO outbox (entity, entity_id, version, attempts, updated_at) '
      'VALUES (?, ?, 1, 0, ?) '
      'ON CONFLICT (entity, entity_id) DO UPDATE SET '
      'version = version + 1, attempts = 0, last_error = NULL, updated_at = excluded.updated_at',
      [entity, entityId, _now().toUtc().toIso8601String()],
    );
  }

  /// Après déconnexion : retire de l'appareil les listes et programmes (liés au
  /// compte) et, au choix, les favoris. La révision est remise à zéro pour que
  /// le prochain compte reçoive tout son contenu.
  Future<void> clearAccountData({required bool keepFavorites}) =>
      _db.transaction(() async {
        await _db.delete(_db.playlists).go();
        await _db.delete(_db.worshipServices).go();
        await (_db.delete(
          _db.outbox,
        )..where((o) => o.entity.isIn([playlist, worshipService]))).go();
        if (!keepFavorites) {
          await _db.delete(_db.favorites).go();
          await (_db.delete(
            _db.outbox,
          )..where((o) => o.entity.equals(favorite))).go();
        }
        await (_db.delete(
          _db.syncState,
        )..where((s) => s.key.equals('user.revision'))).go();
      });

  /// Nombre de modifications de listes et programmes non encore envoyées.
  Future<int> pendingAccountChanges() async {
    final rows = await (_db.select(
      _db.outbox,
    )..where((o) => o.entity.isIn([playlist, worshipService]))).get();
    return rows.length;
  }

  static String _required(String value, String what) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError('$what : valeur obligatoire');
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static final _random = Random.secure();

  /// UUID v4 aléatoire (identifiant créé hors connexion, ADR-006).
  static String _uuidV4() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
