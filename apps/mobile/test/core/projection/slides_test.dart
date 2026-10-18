import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';
import 'package:louanges_a_dieu/core/projection/slides.dart';

/// Mêmes fixtures que les tests TypeScript (packages/shared_contracts).
void main() {
  final files =
      Directory('../../packages/shared_contracts/fixtures/projection')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test(
    'les fixtures existent',
    () => expect(files.length, greaterThanOrEqualTo(7)),
  );

  for (final file in files) {
    final f = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final o = f['options']! as Map<String, Object?>;
    final options = ProjectionOptions(
      repeatRefrain: o['repeatRefrain']! as bool,
      maxLines: o['maxLines']! as int,
    );
    PublishedHymn parse(Object? json) =>
        PublishedHymn.fromJson(json! as Map<String, Object?>);

    test('${file.uri.pathSegments.last} — ${f['description']}', () {
      final slides = f['program'] != null
          ? programSlides([
              for (final e
                  in (f['program']! as List).cast<Map<String, Object?>>())
                if (e.containsKey('label'))
                  LabelEntry(e['label']! as String)
                else
                  HymnEntry(e['hymn'] == null ? null : parse(e['hymn'])),
            ], options)
          : hymnSlides(parse(f['hymn']), options);
      expect([for (final s in slides) s.toJson()], f['expected']);
    });
  }

  test('splitLines équilibre les parties', () {
    List<String> n(int k) => [for (var i = 0; i < k; i++) '$i'];
    expect(splitLines(n(7), 6).map((p) => p.length), [4, 3]);
    expect(splitLines(n(13), 6).map((p) => p.length), [5, 4, 4]);
    expect(splitLines(n(12), 6).map((p) => p.length), [6, 6]);
  });
}
