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
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? _uuidV4;

  final AppDatabase _db;
  final DateTime Function() _now;
  final String Function() _newId;

  static const favorite = 'favorite';
  static const playlist = 'playlist';
  static const worshipService = 'worshipService';

  // ------------------------------------------------------------------ favoris

  Stream<Set<String>> watchFavoriteIds() =>
      (_db.select(_db.favorites)..where((f) => f.isFavorite.equals(true)))
          .watch()
          .map((rows) => {for (final r in rows) r.hymnId});

  Future<void> setFavorite(String hymnId, {required bool isFavorite}) =>
      _db.transaction(() async {
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

  Future<String> createPlaylist(String name, {String? description}) async {
    final id = _newId();
    await _db.transaction(() async {
      await _db
          .into(_db.playlists)
          .insert(
            PlaylistsCompanion.insert(
              id: id,
              name: _required(name, 'Nom de liste'),
              description: Value(_optional(description)),
              updatedAt: _now(),
            ),
          );
      await _enqueue(playlist, id);
    });
    return id;
  }

  Future<void> renamePlaylist(String id, String name) =>
      _db.transaction(() async {
        await (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
          PlaylistsCompanion(
            name: Value(_required(name, 'Nom de liste')),
            updatedAt: Value(_now()),
          ),
        );
        await _enqueue(playlist, id);
      });

  Future<void> deletePlaylist(String id) => _db.transaction(() async {
    await (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
      PlaylistsCompanion(deleted: const Value(true), updatedAt: Value(_now())),
    );
    await _enqueue(playlist, id);
  });

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
      _db.transaction(() async {
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
  }) async {
    final id = _newId();
    await _db.transaction(() async {
      await _db
          .into(_db.worshipServices)
          .insert(
            WorshipServicesCompanion.insert(
              id: id,
              title: _required(title, 'Titre du programme'),
              serviceDate: Value(serviceDate),
              updatedAt: _now(),
            ),
          );
      await _enqueue(worshipService, id);
    });
    return id;
  }

  Future<void> updateWorshipService(
    String id, {
    String? title,
    String? serviceDate,
    String? status,
  }) => _db.transaction(() async {
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
        updatedAt: Value(_now()),
      ),
    );
    await _enqueue(worshipService, id);
  });

  Future<void> deleteWorshipService(String id) => _db.transaction(() async {
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

  Future<List<WorshipServiceItemRow>> worshipServiceItems(String serviceId) =>
      (_db.select(_db.worshipServiceItems)
            ..where((i) => i.serviceId.equals(serviceId))
            ..orderBy([(i) => OrderingTerm.asc(i.position)]))
          .get();

  /// Remplace les éléments ordonnés du programme (cantiques et sections libres).
  Future<void> setWorshipServiceItems(
    String serviceId,
    List<WorshipItemDto> items,
  ) => _db.transaction(() async {
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

  // -------------------------------------------------------------------- outbox

  Future<int> pendingCount() async {
    final c = _db.outbox.id.count();
    return (await (_db.selectOnly(
          _db.outbox,
        )..addColumns([c])).getSingle()).read(c) ??
        0;
  }

  Future<void> _enqueue(String entity, String entityId) => _db.customStatement(
    'INSERT INTO outbox (entity, entity_id, version, attempts, updated_at) '
    'VALUES (?, ?, 1, 0, ?) '
    'ON CONFLICT (entity, entity_id) DO UPDATE SET '
    'version = version + 1, attempts = 0, last_error = NULL, updated_at = excluded.updated_at',
    [entity, entityId, _now().toUtc().toIso8601String()],
  );

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
