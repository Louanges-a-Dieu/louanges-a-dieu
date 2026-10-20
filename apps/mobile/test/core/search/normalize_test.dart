import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/search/normalize.dart';

void main() {
  final fixture = jsonDecode(
    File('../../packages/shared_contracts/fixtures/search/normalization.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;
  final cases = (fixture['cases']! as List<Object?>)
      .cast<Map<String, Object?>>();

  test('le jeu de cas partagé n’est pas vide', () => expect(cases, isNotEmpty));

  for (final c in cases) {
    test('fold(${jsonEncode(c['input'])})', () {
      expect(fold(c['input']! as String), c['folded']);
    });
  }

  test('est idempotent', () {
    for (final c in cases) {
      final once = fold(c['input']! as String);
      expect(fold(once), once);
    }
  });

  test('numéro saisi → numéro imprimé', () {
    expect(parseNumberLabel('37'), '37');
    expect(parseNumberLabel(' 037 '), '37');
    expect(parseNumberLabel('37 BIS'), '37bis');
    expect(parseNumberLabel('239bis'), '239bis');
    expect(parseNumberLabel('grâce'), isNull);
    expect(parseNumberLabel('12345'), isNull);
  });
}
