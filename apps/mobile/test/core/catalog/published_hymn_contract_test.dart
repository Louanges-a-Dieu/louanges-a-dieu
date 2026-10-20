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

  test('lit les enregistrements : clé relative, durée, passages', () {
    final json = jsonDecode(
      File('${dir.path}/valid-with-audio.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final hymn = PublishedHymn.fromJson(json);
    final melody = hymn.audio.first;
    expect(melody.mediaType, MediaType.melody);
    expect(melody.storageKey, 'cantiques/0038/melodie.mp3');
    expect(melody.duration, const Duration(milliseconds: 125500));
    expect(melody.segments[1].sectionId, hymn.sections[1].id);
    expect(melody.segments[1].start, const Duration(seconds: 30));
    expect(melody.segments[2].sectionId, isNull);
    expect(hymn.audio.last.duration, isNull);
  });

  test('sans clé « audio », aucun enregistrement', () {
    final json = jsonDecode(
      File('${dir.path}/valid-minimal-unknown-metadata.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;
    expect(PublishedHymn.fromJson(json).audio, isEmpty);
  });
}
