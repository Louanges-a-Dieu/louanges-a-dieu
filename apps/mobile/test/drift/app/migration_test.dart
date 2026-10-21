// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/database/app_database.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // v1 → v2 : les listes et programmes existants sont conservés, avec les
  // nouvelles colonnes vides (ou à leur valeur par défaut).
  test('v1 → v2 : listes et programmes conservés', () async {
    const updated = '2026-10-21T10:00:00.000';
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(
          oldDb.playlists,
          const v1.PlaylistsData(
            id: 'l1',
            name: 'Chants de prière',
            description: null,
            deleted: 0,
            updatedAt: updated,
            serverRevision: 3,
          ),
        );
        batch.insert(
          oldDb.worshipServices,
          const v1.WorshipServicesData(
            id: 'w1',
            title: 'Culte du dimanche',
            serviceDate: '2026-10-25',
            status: 'draft',
            deleted: 0,
            updatedAt: updated,
            serverRevision: 4,
          ),
        );
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.playlists).get(), [
          const v2.PlaylistsData(
            id: 'l1',
            name: 'Chants de prière',
            description: null,
            icon: null,
            color: null,
            deleted: 0,
            updatedAt: updated,
            serverRevision: 3,
          ),
        ]);
        expect(await newDb.select(newDb.worshipServices).get(), [
          const v2.WorshipServicesData(
            id: 'w1',
            title: 'Culte du dimanche',
            serviceDate: '2026-10-25',
            status: 'draft',
            location: null,
            description: null,
            cover: null,
            isTemplate: 0,
            options: '{}',
            deleted: 0,
            updatedAt: updated,
            serverRevision: 4,
          ),
        ]);
      },
    );
  });
}
