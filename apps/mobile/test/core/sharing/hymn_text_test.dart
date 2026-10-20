import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';
import 'package:louanges_a_dieu/core/sharing/hymn_text.dart';

import '../../support/catalog_fixtures.dart';

void main() {
  test(
    'partage : numéro, titre, paroles verbatim dans l’ordre imprimé, source',
    () {
      final hymn = PublishedHymn.fromJson(
        hymnJson(
          '37bis',
          'Le jour se lève',
          verses: [
            ['Le jour se lève.', 'Chantons (bis)'],
            ['Le soir descend.'],
          ],
          refrain: ['Gloire à Dieu !'],
        ),
      );
      final text = hymnShareText(hymn);
      expect(text, startsWith('37bis — Le jour se lève\n'));
      expect(text, contains('Le jour se lève.\nChantons (bis)\n'));
      expect(text, contains('Refrain\nGloire à Dieu !\n'));
      expect(text, endsWith('Louanges à Dieu, n° 37bis'));
      // Ordre imprimé : le refrain n'est pas répété après chaque couplet.
      expect('Gloire à Dieu !'.allMatches(text), hasLength(1));
    },
  );

  test('nom de section : numéro seulement s’il est imprimé', () {
    expect(sectionName(SectionType.verse, 2), 'Couplet 2');
    expect(sectionName(SectionType.verse, null), 'Couplet');
    expect(sectionName(SectionType.refrain, null), 'Refrain');
  });
}
