import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_repository.dart';
import 'package:louanges_a_dieu/core/database/app_database.dart';
import 'package:louanges_a_dieu/core/search/search_service.dart';

import '../../support/catalog_fixtures.dart';

void main() {
  late AppDatabase db;
  late SearchService search;

  setUp(() async {
    db = memoryDatabase();
    await CatalogRepository(db).replaceAll(snapshotOf(1, sampleHymns()));
    search = SearchService(db);
  });
  tearDown(() => db.close());

  group('par numéro (T-002)', () {
    test('« 37 » : correspondance exacte puis 37bis', () async {
      final r = await search.search('37');
      expect(r.exactNumber?.numberLabel, '37');
      expect(r.numberMatches.map((h) => h.numberLabel), ['37bis']);
    });

    test('« 37bis » et « 37 bis » trouvent le numéro spécial', () async {
      expect((await search.search('37bis')).exactNumber?.numberLabel, '37bis');
      expect((await search.search('37 BIS')).exactNumber?.numberLabel, '37bis');
    });

    test('« 3 » : le 3 puis les numéros qui commencent par 3', () async {
      final r = await search.search('3');
      expect(r.exactNumber?.numberLabel, '3');
      expect(r.numberMatches.map((h) => h.numberLabel), ['30', '37', '37bis']);
    });

    test('un numéro absent ne renvoie rien d’exact', () async {
      expect((await search.search('666')).exactNumber, isNull);
    });
  });

  group('par titre et premier vers', () {
    test('sans accents ni majuscules', () async {
      final r = await search.search('eternel berger');
      expect(r.titleMatches.map((h) => h.numberLabel), ['2']);
    });

    test('« coeur » trouve « cœur »', () async {
      final r = await search.search('coeur');
      expect(r.titleMatches.map((h) => h.numberLabel), contains('3'));
    });

    test('début de mot (correspondance partielle)', () async {
      final r = await search.search('heur');
      expect(r.titleMatches.map((h) => h.numberLabel), ['1']);
    });

    test(
      'les titres qui commencent par la saisie passent en premier',
      () async {
        final r = await search.search('autre texte');
        expect(r.titleMatches.first.numberLabel, '37bis');
      },
    );
  });

  group('dans les paroles (T-003)', () {
    test('renvoie le cantique avec le vers correspondant, verbatim', () async {
      final r = await search.search('epis dores');
      expect(r.lyricMatches.single.hymn.numberLabel, '30');
      expect(r.lyricMatches.single.excerpt, 'Les épis sont dorés.');
    });

    test('trouve un mot du refrain', () async {
      final r = await search.search('alleluia');
      expect(r.lyricMatches.single.hymn.numberLabel, '2');
      expect(r.lyricMatches.single.excerpt, 'Alléluia, gloire à Dieu,');
    });

    test(
      'un cantique trouvé par son titre n’est pas répété dans les paroles',
      () async {
        final r = await search.search('jour heureux');
        expect(r.titleMatches.map((h) => h.numberLabel), ['1']);
        expect(r.lyricMatches, isEmpty);
      },
    );
  });

  test('aucun résultat', () async {
    expect((await search.search('zzzz introuvable')).isEmpty, isTrue);
  });

  test('saisie vide ou ponctuation seule', () async {
    expect((await search.search('   ')).isEmpty, isTrue);
    expect((await search.search('!?…')).isEmpty, isTrue);
  });

  test('une saisie avec guillemets ne casse pas la requête', () async {
    expect(() => search.search('"mon" cœur"'), returnsNormally);
    expect(
      (await search.search('"mon" cœur"')).titleMatches
          .map((h) => h.numberLabel),
      ['3'],
    );
  });
}
