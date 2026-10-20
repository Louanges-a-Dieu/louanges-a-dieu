import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_models.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_repository.dart';
import 'package:louanges_a_dieu/core/database/app_database.dart';

import '../../support/catalog_fixtures.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository repo;

  setUp(() async {
    db = memoryDatabase();
    repo = CatalogRepository(db);
    await repo.replaceAll(snapshotOf(1, sampleHymns()));
  });
  tearDown(() => db.close());

  test('enregistre la release et tous les cantiques', () async {
    expect(await repo.currentReleaseId(), 1);
    expect(await repo.count(), 6);
  });

  test(
    'trie le recueil par numéro, le « bis » après son numéro principal',
    () async {
      final labels = (await repo.watchByNumber().first).map(
        (h) => h.numberLabel,
      );
      expect(labels, ['1', '2', '3', '30', '37', '37bis']);
    },
  );

  test('trie l’ordre alphabétique sans tenir compte des accents', () async {
    final titles = (await repo.watchAlphabetical().first).map((h) => h.title);
    expect(titles.first, 'Au matin');
    expect(
      titles.toList().indexOf('Ô jour heureux'),
      lessThan(titles.toList().indexOf('Trentième chant')),
    );
  });

  test(
    'restitue le contenu complet d’un cantique (refrain, répétitions)',
    () async {
      final hymn = (await repo.hymnByLabel('2'))!;
      expect(hymn.sections.map((s) => s.type.name), ['verse', 'refrain', 'verse']);
      final one = (await repo.hymnByLabel('1'))!;
      expect(one.sections.first.lines.last.repeat?.count, 2);
    },
  );

  test('navigue vers le cantique précédent et suivant', () async {
    final id37 = (await repo.hymnByLabel('37'))!.id;
    expect((await repo.neighbour(id37, next: true))?.numberLabel, '37bis');
    expect((await repo.neighbour(id37, next: false))?.numberLabel, '30');
  });

  test('applique un delta : ajout, modification, retrait', () async {
    final hymns = sampleHymns();
    await repo.applyDelta(
      CatalogDelta.fromJson({
        'fromRelease': 1,
        'toRelease': 2,
        'fullSnapshotRequired': false,
        'upserts': [
          hymnJson('3', 'Mon cœur Te loue (corrigé)'),
          hymnJson('4', 'Nouveau chant'),
        ],
        'removedIds': [hymns[3]['id']],
      }),
      contentHash: 'hash-2',
      expectedCount: 6,
    );
    expect(await repo.currentReleaseId(), 2);
    expect((await repo.hymnByLabel('3'))!.title, 'Mon cœur Te loue (corrigé)');
    expect(await repo.hymnByLabel('4'), isNotNull);
    expect(await repo.hymnByLabel('30'), isNull);
  });

  test(
    'une mise à jour incohérente est annulée et laisse le catalogue intact',
    () async {
      await expectLater(
        repo.replaceAll(
          snapshotOf(9, sampleHymns().take(2).toList()),
          expectedCount: 6,
        ),
        throwsStateError,
      );
      expect(await repo.currentReleaseId(), 1);
      expect(await repo.count(), 6);
    },
  );

  test('refuse un instantané qui ne respecte pas le contrat', () {
    final bad = hymnJson('5', 'Cinq')..['openingLine'] = '';
    expect(() => snapshotOf(3, [bad]), throwsFormatException);
  });
}
