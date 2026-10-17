import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_models.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_repository.dart';
import 'package:louanges_a_dieu/core/database/app_database.dart';
import 'package:louanges_a_dieu/core/search/search_service.dart';
import 'package:louanges_a_dieu/core/sync/catalog_sync.dart';

import '../../support/catalog_fixtures.dart';

/// Serveur simulé : releases successives, panne réseau à la demande.
class FakeRemote implements CatalogRemote {
  final releases = <int, List<Map<String, Object?>>>{};
  bool offline = false;
  int snapshotCalls = 0;
  int deltaCalls = 0;
  Object? corrupt;

  int? get latest =>
      releases.isEmpty ? null : releases.keys.reduce((a, b) => a > b ? a : b);

  void _check() {
    if (offline) throw const SocketException('Mode avion');
  }

  @override
  Future<CatalogManifest?> manifest() async {
    _check();
    final id = latest;
    if (id == null) return null;
    return CatalogManifest(
      releaseId: id,
      hymnCount: releases[id]!.length,
      contentHash: 'hash-$id',
    );
  }

  @override
  Future<CatalogSnapshot> snapshot() async {
    _check();
    snapshotCalls++;
    if (corrupt != null) throw corrupt!;
    return snapshotOf(latest!, releases[latest!]!);
  }

  @override
  Future<CatalogDelta> delta(int fromRelease) async {
    _check();
    deltaCalls++;
    final from = releases[fromRelease];
    final to = releases[latest!]!;
    if (from == null) {
      return CatalogDelta.fromJson({
        'fromRelease': fromRelease,
        'toRelease': latest,
        'fullSnapshotRequired': true,
      });
    }
    final fromById = {for (final h in from) h['id']: h.toString()};
    final toIds = {for (final h in to) h['id']};
    return CatalogDelta.fromJson({
      'fromRelease': fromRelease,
      'toRelease': latest,
      'fullSnapshotRequired': false,
      'upserts': [
        for (final h in to)
          if (fromById[h['id']] != h.toString()) h,
      ],
      'removedIds': [
        for (final h in from)
          if (!toIds.contains(h['id'])) h['id'],
      ],
    });
  }
}

class FakeBundled implements BundledCatalogSource {
  FakeBundled(this.snapshot);
  final CatalogSnapshot? snapshot;
  int loads = 0;

  @override
  Future<CatalogSnapshot?> load() async {
    loads++;
    return snapshot;
  }
}

void main() {
  late AppDatabase db;
  late FakeRemote remote;
  late DateTime now;

  CatalogSync sync({CatalogSnapshot? bundled, int deltaLimit = 300}) =>
      CatalogSync(
        db: db,
        remote: remote,
        bundled: FakeBundled(bundled),
        now: () => now,
        deltaLimit: deltaLimit,
      );
  CatalogRepository repo() => CatalogRepository(db);

  setUp(() {
    db = memoryDatabase();
    remote = FakeRemote();
    now = DateTime.utc(2026, 10, 18, 9);
  });
  tearDown(() => db.close());

  group('premier lancement', () {
    test('installe le catalogue embarqué sans réseau', () async {
      remote.offline = true;
      expect(
        await sync(bundled: snapshotOf(1, sampleHymns())).ensureLocalCatalog(),
        isTrue,
      );
      expect(await repo().count(), 6);
    });

    test('ne réimporte pas un catalogue déjà présent', () async {
      final bundled = FakeBundled(snapshotOf(1, sampleHymns()));
      final s = CatalogSync(db: db, remote: remote, bundled: bundled);
      await s.ensureLocalCatalog();
      await s.ensureLocalCatalog();
      expect(bundled.loads, 1);
    });

    test('sans instantané embarqué : aucun catalogue tant qu’il n’y a pas de réseau', () async {
      expect(await sync().ensureLocalCatalog(), isFalse);
    });
  });

  group('mode avion (T-004)', () {
    test('recherche et lecture fonctionnent ; la vérification échoue sans rien casser', () async {
      remote.offline = true;
      final s = sync(bundled: snapshotOf(1, sampleHymns()));
      await s.ensureLocalCatalog();

      expect(await s.refresh(force: true), isA<CatalogOffline>());
      expect(await repo().currentReleaseId(), 1);
      expect(await repo().count(), 6);

      final results = await SearchService(db).search('berger');
      expect(results.titleMatches.single.numberLabel, '2');
      expect((await repo().hymnByLabel('2'))!.sections, isNotEmpty);
    });
  });

  group('mises à jour', () {
    setUp(() async {
      remote.releases[1] = sampleHymns();
    });

    test('déjà à jour', () async {
      final s = sync(bundled: snapshotOf(1, sampleHymns()));
      await s.ensureLocalCatalog();
      expect(await s.refresh(force: true), isA<CatalogUpToDate>());
    });

    test('nouvelle release appliquée par delta', () async {
      final s = sync(bundled: snapshotOf(1, sampleHymns()));
      await s.ensureLocalCatalog();
      remote.releases[2] = [
        ...sampleHymns().where((h) => h['numberLabel'] != '30'),
        hymnJson('4', 'Nouveau chant'),
      ];
      final outcome = await s.refresh(force: true);
      expect(
        outcome,
        isA<CatalogUpdated>().having((o) => o.viaDelta, 'delta', isTrue),
      );
      expect((outcome as CatalogUpdated).changed, 1);
      expect(outcome.removed, 1);
      expect(remote.snapshotCalls, 0);
      expect(await repo().currentReleaseId(), 2);
      expect(await repo().hymnByLabel('30'), isNull);
      expect(await repo().hymnByLabel('4'), isNotNull);
    });

    test('trop de changements : instantané complet', () async {
      final s = sync(bundled: snapshotOf(1, sampleHymns()), deltaLimit: 0);
      await s.ensureLocalCatalog();
      remote.releases[2] = [...sampleHymns(), hymnJson('4', 'Nouveau chant')];
      final outcome = await s.refresh(force: true);
      expect(
        outcome,
        isA<CatalogUpdated>().having((o) => o.viaDelta, 'delta', isFalse),
      );
      expect(await repo().count(), 7);
    });

    test('release locale inconnue du serveur : instantané complet', () async {
      final s = sync(bundled: snapshotOf(99, sampleHymns()));
      await s.ensureLocalCatalog();
      remote.releases[2] = sampleHymns();
      await s.refresh(force: true);
      expect(remote.snapshotCalls, 1);
      expect(await repo().currentReleaseId(), 2);
    });

    test(
      'sans catalogue local, le premier accès réseau télécharge tout',
      () async {
        final s = sync();
        expect(await s.ensureLocalCatalog(), isFalse);
        expect(await s.refresh(force: true), isA<CatalogUpdated>());
        expect(await repo().count(), 6);
      },
    );

    test('vérification limitée à une fois par heure (sauf forçage)', () async {
      final s = sync(bundled: snapshotOf(1, sampleHymns()));
      await s.ensureLocalCatalog();
      expect(await s.refresh(), isA<CatalogUpToDate>());
      now = now.add(const Duration(minutes: 30));
      expect(await s.refresh(), isA<CatalogCheckSkipped>());
      now = now.add(const Duration(minutes: 31));
      expect(await s.refresh(), isA<CatalogUpToDate>());
    });

    test(
      'contenu reçu invalide : mise à jour rejetée, catalogue intact',
      () async {
        final s = sync(bundled: snapshotOf(1, sampleHymns()));
        await s.ensureLocalCatalog();
        remote.releases[5] = sampleHymns();
        remote.corrupt = const FormatException('payload invalide');
        await (db.delete(
          db.syncState,
        )..where((r) => r.key.equals('catalog.releaseId'))).go();
        await db
            .into(db.syncState)
            .insertOnConflictUpdate(
              SyncStateCompanion.insert(key: 'catalog.releaseId', value: '99'),
            );
        expect(await s.refresh(force: true), isA<CatalogUpdateRejected>());
        expect(await repo().count(), 6);
      },
    );
  });

  test('aucune release publiée côté serveur', () async {
    final s = sync(bundled: snapshotOf(1, sampleHymns()));
    await s.ensureLocalCatalog();
    expect(await s.refresh(force: true), isA<CatalogCheckSkipped>());
  });
}
