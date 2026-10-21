import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../user_data/user_data_models.dart';
import '../user_data/user_data_repository.dart';

/// Source distante des données utilisateur (RPC sync_* en production).
abstract interface class UserDataRemote {
  Future<void> pushFavorites(List<FavoriteChange> changes);
  Future<void> pushPlaylist(PlaylistDto playlist);
  Future<void> pushWorshipService(WorshipServiceDto service);
  Future<UserChanges> pull(int since);
}

sealed class UserSyncOutcome {
  const UserSyncOutcome();
}

final class UserSyncSkipped extends UserSyncOutcome {
  const UserSyncSkipped(this.reason);
  final String reason;
}

final class UserSyncDone extends UserSyncOutcome {
  const UserSyncDone({
    required this.pushed,
    required this.pulled,
    required this.revision,
  });
  final int pushed;
  final int pulled;
  final int revision;
}

/// Échec (réseau, serveur) : les modifications locales restent en attente.
final class UserSyncPending extends UserSyncOutcome {
  const UserSyncPending({required this.pending, required this.error});
  final int pending;
  final Object error;
}

/// Synchronisation des données utilisateur (ADR-006) : envoi des modifications
/// locales, puis réception des changements des autres appareils. La dernière
/// écriture reçue par le serveur l'emporte ; une modification locale encore
/// en attente n'est jamais écrasée par la réception.
class UserSync {
  UserSync({
    required AppDatabase db,
    required this._remote,
    required this._isSignedIn,
  }) : _db = db,
       _repo = UserDataRepository(db);

  final AppDatabase _db;
  final UserDataRepository _repo;
  final UserDataRemote _remote;
  final bool Function() _isSignedIn;

  static const _revisionKey = 'user.revision';

  Future<UserSyncOutcome> sync() async {
    if (!_isSignedIn()) return const UserSyncSkipped('Aucun compte connecté');
    var pushed = 0;
    try {
      pushed = await _push();
      final pulled = await _pull();
      return UserSyncDone(
        pushed: pushed,
        pulled: pulled.$1,
        revision: pulled.$2,
      );
    } on Object catch (error) {
      return UserSyncPending(pending: await _repo.pendingCount(), error: error);
    }
  }

  /// Envoie l'état courant de chaque entité en attente. Une entrée n'est
  /// effacée que si elle n'a pas été modifiée pendant l'envoi (même version).
  Future<int> _push() async {
    final entries = await _db.select(_db.outbox).get();
    if (entries.isEmpty) return 0;
    var pushed = 0;

    final favorites = entries
        .where((e) => e.entity == UserDataRepository.favorite)
        .toList();
    if (favorites.isNotEmpty) {
      final rows = await (_db.select(
        _db.favorites,
      )..where((f) => f.hymnId.isIn(favorites.map((e) => e.entityId)))).get();
      await _attempt(favorites, () async {
        await _remote.pushFavorites([
          for (final r in rows)
            FavoriteChange(hymnId: r.hymnId, deleted: !r.isFavorite),
        ]);
      });
      pushed += favorites.length;
    }

    for (final e in entries.where(
      (e) => e.entity == UserDataRepository.playlist,
    )) {
      final p = await (_db.select(
        _db.playlists,
      )..where((x) => x.id.equals(e.entityId))).getSingleOrNull();
      if (p == null) {
        await _done([e]);
        continue;
      }
      final hymnIds = await _repo.playlistHymnIds(p.id);
      await _attempt([e], () async {
        await _remote.pushPlaylist(
          PlaylistDto(
            id: p.id,
            name: p.name,
            description: p.description,
            icon: p.icon,
            color: p.color,
            deleted: p.deleted,
            hymnIds: hymnIds,
          ),
        );
      });
      pushed++;
    }

    for (final e in entries.where(
      (e) => e.entity == UserDataRepository.worshipService,
    )) {
      final w = await (_db.select(
        _db.worshipServices,
      )..where((x) => x.id.equals(e.entityId))).getSingleOrNull();
      if (w == null) {
        await _done([e]);
        continue;
      }
      final items = await _repo.worshipServiceItems(w.id);
      await _attempt([e], () async {
        await _remote.pushWorshipService(
          WorshipServiceDto(
            id: w.id,
            title: w.title,
            serviceDate: w.serviceDate,
            status: w.status,
            location: w.location,
            description: w.description,
            cover: w.cover,
            isTemplate: w.isTemplate,
            options: ProgramOptions.rawJson(w.options),
            deleted: w.deleted,
            items: [
              for (final i in items)
                WorshipItemDto(
                  id: i.id,
                  hymnId: i.hymnId,
                  label: i.label,
                  notes: i.notes,
                ),
            ],
          ),
        );
      });
      pushed++;
    }
    return pushed;
  }

  Future<void> _attempt(
    List<OutboxRow> entries,
    Future<void> Function() send,
  ) async {
    try {
      await send();
    } on Object catch (error) {
      for (final e in entries) {
        await (_db.update(_db.outbox)..where((o) => o.id.equals(e.id))).write(
          OutboxCompanion(
            attempts: Value(e.attempts + 1),
            lastError: Value('$error'),
          ),
        );
      }
      rethrow;
    }
    await _done(entries);
  }

  Future<void> _done(List<OutboxRow> entries) async {
    for (final e in entries) {
      await (_db.delete(
        _db.outbox,
      )..where((o) => o.id.equals(e.id) & o.version.equals(e.version))).go();
    }
  }

  Future<(int, int)> _pull() async {
    final sinceRow = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(_revisionKey))).getSingleOrNull();
    final since = sinceRow == null ? 0 : int.parse(sinceRow.value);
    final changes = await _remote.pull(since);

    var applied = 0;
    await _db.transaction(() async {
      final pending = {
        for (final o in await _db.select(_db.outbox).get())
          '${o.entity}:${o.entityId}',
      };
      bool isPending(String entity, String id) =>
          pending.contains('$entity:$id');

      for (final f in changes.favorites) {
        if (isPending(UserDataRepository.favorite, f.hymnId)) continue;
        await _repo.applyRemoteFavorite(f);
        applied++;
      }
      for (final p in changes.playlists) {
        if (isPending(UserDataRepository.playlist, p.id)) continue;
        await _repo.applyRemotePlaylist(p);
        applied++;
      }
      for (final w in changes.worshipServices) {
        if (isPending(UserDataRepository.worshipService, w.id)) continue;
        await _repo.applyRemoteWorshipService(w);
        applied++;
      }
      await _db
          .into(_db.syncState)
          .insertOnConflictUpdate(
            SyncStateCompanion.insert(
              key: _revisionKey,
              value: '${changes.revision}',
            ),
          );
    });
    return (applied, changes.revision);
  }
}
