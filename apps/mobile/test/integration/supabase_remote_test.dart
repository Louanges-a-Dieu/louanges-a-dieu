import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_repository.dart';
import 'package:louanges_a_dieu/core/network/supabase_remotes.dart';
import 'package:louanges_a_dieu/core/sync/catalog_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/catalog_fixtures.dart';

class _NoBundle implements BundledCatalogSource {
  @override
  Future<Null> load() async => null;
}

/// Contre la base de DÉVELOPPEMENT (config/dev.json, non versionné), avec la
/// seule clé publishable, comme l'application. Sauté sans configuration.
void main() {
  final config = File('config/dev.json');
  final skip = config.existsSync() ? false : 'config/dev.json absent';

  late SupabaseCatalogRemote remote;
  setUpAll(() {
    if (!config.existsSync()) return;
    final c = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
    remote = SupabaseCatalogRemote(
      SupabaseClient(
        c['SUPABASE_URL']! as String,
        c['SUPABASE_PUBLISHABLE_KEY']! as String,
      ),
    );
  });

  test('manifeste et deltas publics', () async {
    final manifest = (await remote.manifest())!;
    expect(manifest.hymnCount, greaterThan(0));
    final none = await remote.delta(manifest.releaseId);
    expect(none.upserts, isEmpty);
    expect(none.removedIds, isEmpty);
    expect((await remote.delta(999999999)).fullSnapshotRequired, isTrue);
  }, skip: skip);

  test(
    'premier lancement sans instantané embarqué : téléchargement complet de bout en bout',
    () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      final sync = CatalogSync(db: db, remote: remote, bundled: _NoBundle());
      expect(await sync.ensureLocalCatalog(), isFalse);
      final outcome = await sync.refresh(force: true);
      expect(outcome, isA<CatalogUpdated>());
      final manifest = (await remote.manifest())!;
      expect(await CatalogRepository(db).count(), manifest.hymnCount);
      expect(await sync.refresh(force: true), isA<CatalogUpToDate>());
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
