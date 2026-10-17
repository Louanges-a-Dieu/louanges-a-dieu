import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';

/// Mêmes fixtures que les tests Zod (packages/shared_contracts) :
/// le modèle Dart accepte et refuse exactement les mêmes documents.
void main() {
  final dir = Directory('../../packages/shared_contracts/fixtures/hymn');
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('des fixtures valides et invalides existent', () {
    expect(
      files.where((f) => f.uri.pathSegments.last.startsWith('valid-')),
      isNotEmpty,
    );
    expect(
      files.where((f) => f.uri.pathSegments.last.startsWith('invalid-')),
      isNotEmpty,
    );
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    if (name.startsWith('valid-')) {
      test(
        '$name est accepté',
        () => expect(() => PublishedHymn.fromJson(json), returnsNormally),
      );
    } else {
      test('$name est refusé', () {
        expect(() => PublishedHymn.fromJson(json), throwsFormatException);
      });
    }
  }

  test('lit les répétitions, le refrain et la relation « bis »', () {
    final json = jsonDecode(
      File('${dir.path}/valid-with-refrain-and-bis.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final hymn = PublishedHymn.fromJson(json);
    expect(hymn.numberLabel, '37bis');
    expect(hymn.sections[0].lines[1].repeat?.count, 2);
    expect(hymn.sections[1].type, SectionType.refrain);
    expect(hymn.relations.single.type, RelationType.bisOf);
  });

  test('une valeur inconnue reste null', () {
    final json = jsonDecode(
      File('${dir.path}/valid-minimal-unknown-metadata.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;
    final hymn = PublishedHymn.fromJson(json);
    expect(hymn.openingLine, isNull);
    expect(hymn.people, isEmpty);
  });
}
