import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/bundled_catalog.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_repository.dart';
import 'package:louanges_a_dieu/core/search/search_service.dart';

import '../support/catalog_fixtures.dart';

/// Sur le VRAI catalogue (instantané généré par `content-tools export-snapshot`,
/// non versionné). Sauté, et signalé comme tel, si l'instantané est absent.
void main() {
  final file = File('assets/catalog/catalog_snapshot.json.gz');
  final skip = file.existsSync()
      ? false
      : 'instantané réel absent (non versionné)';

  test('le catalogue réel est conforme au contrat Dart, importé et recherché en moins de 100 ms', () async {
    final watch = Stopwatch()..start();
    final snapshot = decodeSnapshot(file.readAsBytesSync());
    final decodeMs = watch.elapsedMilliseconds;
    expect(snapshot.hymns.length, greaterThan(1000));

    final db = memoryDatabase();
    addTearDown(db.close);
    watch.reset();
    await CatalogRepository(db).replaceAll(snapshot);
    final importMs = watch.elapsedMilliseconds;

    final search = SearchService(db);
    final timings = <String, int>{};
    for (final q in [
      '37',
      '37bis',
      '596',
      'eternel berger',
      'coeur',
      'alleluia',
      'sang de jesus',
      'jesus',
      'gloire a dieu',
    ]) {
      watch.reset();
      final r = await search.search(q);
      timings[q] = watch.elapsedMilliseconds;
      expect(r.isEmpty, isFalse, reason: 'aucun résultat pour « $q »');
    }
    // ignore: avoid_print
    print(
      'décodage $decodeMs ms, import $importMs ms, recherches (ms) : $timings',
    );

    expect(timings.values.every((ms) => ms < 100), isTrue, reason: '$timings');
    expect((await search.search('37bis')).exactNumber?.numberLabel, '37bis');
    expect((await search.search('596')).exactNumber?.numberLabel, '596');
    expect((await search.search('666')).exactNumber, isNull);
  }, skip: skip);
}
