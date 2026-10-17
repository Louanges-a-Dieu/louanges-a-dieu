import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/database/app_database.dart';
import 'package:louanges_a_dieu/core/sync/user_sync.dart';
import 'package:louanges_a_dieu/core/user_data/user_data_models.dart';
import 'package:louanges_a_dieu/core/user_data/user_data_repository.dart';

import '../../support/catalog_fixtures.dart';

/// Serveur simulé, fidèle aux RPC sync_* : révision serveur croissante,
/// pierres tombales, la dernière écriture reçue l'emporte.
class FakeServer implements UserDataRemote {
  var _revision = 0;
  bool offline = false;
  final favorites = <String, FavoriteChange>{};
  final playlists = <String, PlaylistDto>{};
  final services = <String, WorshipServiceDto>{};
  Future<void> Function()? duringPull;
  Future<void> Function()? duringPush;

  void _check() {
    if (offline) throw const SocketException('Hors connexion');
  }

  @override
  Future<void> pushFavorites(List<FavoriteChange> changes) async {
    _check();
    for (final c in changes) {
      favorites[c.hymnId] = FavoriteChange(
        hymnId: c.hymnId,
        deleted: c.deleted,
        revision: ++_revision,
      );
    }
  }

  @override
  Future<void> pushPlaylist(PlaylistDto p) async {
    _check();
    await duringPush?.call();
    playlists[p.id] = PlaylistDto(
      id: p.id,
      name: p.name,
      description: p.description,
      deleted: p.deleted,
      hymnIds: p.hymnIds,
      revision: ++_revision,
    );
  }

  @override
  Future<void> pushWorshipService(WorshipServiceDto w) async {
    _check();
    services[w.id] = WorshipServiceDto(
      id: w.id,
      title: w.title,
      serviceDate: w.serviceDate,
      status: w.status,
      deleted: w.deleted,
      items: w.items,
      revision: ++_revision,
    );
  }

  @override
  Future<UserChanges> pull(int since) async {
    _check();
    await duringPull?.call();
    return UserChanges(
      revision: _revision,
      favorites: favorites.values.where((f) => f.revision > since).toList(),
      playlists: playlists.values.where((p) => p.revision > since).toList(),
      worshipServices: services.values
          .where((w) => w.revision > since)
          .toList(),
    );
  }
}

class Device {
  Device(FakeServer server, {this.signedIn = true}) : db = memoryDatabase() {
    repo = UserDataRepository(db);
    sync = UserSync(db: db, remote: server, isSignedIn: () => signedIn);
  }

  final AppDatabase db;
  late final UserDataRepository repo;
  late final UserSync sync;
  bool signedIn;
}

void main() {
  late FakeServer server;
  late Device a;
  late Device b;
  final h1 = hymnUuid('1');
  final h2 = hymnUuid('2');
  final h3 = hymnUuid('3');

  setUp(() {
    server = FakeServer();
    a = Device(server);
    b = Device(server);
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  group('favoris (T-005)', () {
    test(
      'ajouté hors ligne, conservé localement, envoyé au retour du réseau',
      () async {
        server.offline = true;
        await a.repo.setFavorite(h1, isFavorite: true);
        expect(await a.repo.watchFavoriteIds().first, {h1});

        final offline = await a.sync.sync();
        expect(
          offline,
          isA<UserSyncPending>().having((o) => o.pending, 'en attente', 1),
        );

        server.offline = false;
        expect(
          await a.sync.sync(),
          isA<UserSyncDone>().having((o) => o.pushed, 'envoyés', 1),
        );
        expect(server.favorites[h1]?.deleted, isFalse);
        expect(await a.repo.pendingCount(), 0);
      },
    );

    test('un échec d’envoi est tracé (tentatives, erreur)', () async {
      server.offline = true;
      await a.repo.setFavorite(h1, isFavorite: true);
      await a.sync.sync();
      final entry = await a.db.select(a.db.outbox).getSingle();
      expect(entry.attempts, 1);
      expect(entry.lastError, contains('Hors connexion'));
    });

    test(
      'visiteur : favoris gardés localement, envoyés à la première connexion',
      () async {
        a.signedIn = false;
        await a.repo.setFavorite(h1, isFavorite: true);
        expect(await a.sync.sync(), isA<UserSyncSkipped>());
        expect(server.favorites, isEmpty);
        a.signedIn = true;
        await server.pushFavorites([
          FavoriteChange(hymnId: h2, deleted: false),
        ]);
        await a.sync.sync();
        expect(await a.repo.watchFavoriteIds().first, {
          h1,
          h2,
        }, reason: 'union des favoris');
      },
    );

    test(
      'un retrait est propagé aux autres appareils (pierre tombale)',
      () async {
        await a.repo.setFavorite(h1, isFavorite: true);
        await a.sync.sync();
        await b.sync.sync();
        expect(await b.repo.watchFavoriteIds().first, {h1});

        await a.repo.setFavorite(h1, isFavorite: false);
        await a.sync.sync();
        await b.sync.sync();
        expect(await b.repo.watchFavoriteIds().first, isEmpty);
      },
    );
  });

  group('listes', () {
    test(
      'une liste ordonnée créée sur un appareil apparaît sur l’autre',
      () async {
        final id = await a.repo.createPlaylist('Culte du soir');
        await a.repo.setPlaylistHymns(id, [h3, h1, h2]);
        await a.sync.sync();
        await b.sync.sync();
        expect(
          (await b.repo.watchPlaylists().first).single.name,
          'Culte du soir',
        );
        expect(await b.repo.playlistHymnIds(id), [h3, h1, h2]);
      },
    );

    test(
      'conflit de réordonnancement : la dernière écriture reçue l’emporte',
      () async {
        final id = await a.repo.createPlaylist('Liste');
        await a.repo.setPlaylistHymns(id, [h1, h2, h3]);
        await a.sync.sync();
        await b.sync.sync();

        await a.repo.setPlaylistHymns(id, [h3, h2, h1]);
        await b.repo.setPlaylistHymns(id, [h2, h1, h3]);
        await a.sync.sync();
        await b.sync.sync(); // reçue en dernier : l'emporte
        await a.sync.sync();

        expect(await a.repo.playlistHymnIds(id), [h2, h1, h3]);
        expect(await b.repo.playlistHymnIds(id), [h2, h1, h3]);
      },
    );

    test('une suppression est propagée', () async {
      final id = await a.repo.createPlaylist('À supprimer');
      await a.sync.sync();
      await b.sync.sync();
      await a.repo.deletePlaylist(id);
      await a.sync.sync();
      await b.sync.sync();
      expect(await b.repo.watchPlaylists().first, isEmpty);
    });

    test('une modification faite pendant l’envoi n’est pas perdue', () async {
      final id = await a.repo.createPlaylist('Avant');
      server.duringPush = () async {
        server.duringPush = null;
        await a.repo.renamePlaylist(id, 'Pendant');
      };
      await a.sync.sync();
      expect(
        await a.repo.pendingCount(),
        1,
        reason: 'la nouvelle version reste à envoyer',
      );
      expect((await a.repo.watchPlaylists().first).single.name, 'Pendant');
      await a.sync.sync();
      expect(server.playlists[id]?.name, 'Pendant');
    });

    test(
      'la réception n’écrase pas une modification locale en attente',
      () async {
        final id = await a.repo.createPlaylist('Commune');
        await a.sync.sync();
        await b.sync.sync();
        await a.repo.renamePlaylist(id, 'Version A');
        await a.sync.sync();

        server.duringPull = () async {
          server.duringPull = null;
          await b.repo.renamePlaylist(id, 'Version B (en cours)');
        };
        await b.sync.sync();
        expect(
          (await b.repo.watchPlaylists().first).single.name,
          'Version B (en cours)',
        );
        await b.sync.sync();
        expect(server.playlists[id]?.name, 'Version B (en cours)');
      },
    );

    test('un nom vide est refusé', () {
      expect(() => a.repo.createPlaylist('   '), throwsArgumentError);
    });
  });

  group('programmes de culte', () {
    test('cantiques et sections libres, dans l’ordre, synchronisés', () async {
      final id = await a.repo.createWorshipService(
        'Culte de Pâques',
        serviceDate: '2027-03-28',
      );
      await a.repo.setWorshipServiceItems(id, [
        const WorshipItemDto(
          id: '00000000-0000-4000-a000-000000000001',
          hymnId: null,
          label: 'Accueil',
          notes: null,
        ),
        WorshipItemDto(
          id: '00000000-0000-4000-a000-000000000002',
          hymnId: h1,
          label: null,
          notes: 'Deux couplets',
        ),
      ]);
      await a.sync.sync();
      await b.sync.sync();
      final items = await b.repo.worshipServiceItems(id);
      expect(items.map((i) => i.label ?? i.hymnId), ['Accueil', h1]);
      expect(items.last.notes, 'Deux couplets');
    });

    test('un élément sans cantique ni libellé est refusé', () async {
      final id = await a.repo.createWorshipService('Culte');
      expect(
        () => a.repo.setWorshipServiceItems(id, [
          const WorshipItemDto(
            id: '00000000-0000-4000-a000-000000000009',
            hymnId: null,
            label: ' ',
            notes: null,
          ),
        ]),
        throwsArgumentError,
      );
    });
  });

  test('réception incrémentale : rien de neuf au second passage', () async {
    await a.repo.setFavorite(h1, isFavorite: true);
    await a.sync.sync();
    await b.sync.sync();
    final again = await b.sync.sync();
    expect(again, isA<UserSyncDone>().having((o) => o.pulled, 'reçus', 0));
  });
}
