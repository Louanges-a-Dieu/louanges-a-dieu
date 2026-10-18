import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_models.dart';
import 'package:louanges_a_dieu/core/catalog/hymn_of_the_day.dart';

void main() {
  final hymns = [
    for (var n = 1; n <= 100; n++)
      HymnSummary(
        id: '$n',
        numberLabel: '$n',
        numberNumeric: n,
        title: 'T$n',
        openingLine: null,
      ),
  ];

  test('identique toute la journée, quelle que soit l’heure', () {
    expect(
      hymnOfTheDay(hymns, DateTime(2026, 10, 18, 0, 1)),
      hymnOfTheDay(hymns, DateTime(2026, 10, 18, 23, 59)),
    );
  });

  test('change d’un jour à l’autre et parcourt le recueil', () {
    final week = {
      for (var d = 0; d < 7; d++)
        hymnOfTheDay(hymns, DateTime(2026, 10, 18).add(Duration(days: d))),
    };
    expect(week.length, 7);
  });

  test('aucun cantique : aucun cantique du jour', () {
    expect(hymnOfTheDay(const [], DateTime(2026, 10, 18)), isNull);
  });
}
