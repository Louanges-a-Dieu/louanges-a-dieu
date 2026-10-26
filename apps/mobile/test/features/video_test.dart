import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';
import 'package:louanges_a_dieu/features/video/video_screen.dart';

import '../support/app_harness.dart';
import '../support/catalog_fixtures.dart';
import 'audio_test.dart' show openHymn;
import 'faithful_journey_test.dart' show idle;

/// Le cantique 2 avec deux vidéos YouTube de la chorale.
List<Map<String, Object?>> hymnsWithVideos() {
  final hymns = sampleHymns();
  final hymn = hymns.firstWhere((h) => h['numberLabel'] == '2');
  hymn['videos'] = [
    {
      'id': '00000000-0000-4000-8000-0000000b0001',
      'mediaType': 'choir',
      'youtubeId': 'dQw4w9WgXcQ',
      'title': 'Chorale du dimanche',
    },
    {
      'id': '00000000-0000-4000-8000-0000000b0002',
      'mediaType': 'choir',
      'youtubeId': 'a_b-c1D2e3F',
      'title': null,
    },
  ];
  return hymns;
}

void main() {
  test('nom des versions : numérotées si plusieurs du même type', () {
    const choir1 = HymnVideo(
      id: '1',
      mediaType: MediaType.choir,
      youtubeId: 'dQw4w9WgXcQ',
      title: null,
    );
    const choir2 = HymnVideo(
      id: '2',
      mediaType: MediaType.choir,
      youtubeId: 'a_b-c1D2e3F',
      title: null,
    );
    const instrumental = HymnVideo(
      id: '3',
      mediaType: MediaType.instrumental,
      youtubeId: 'bbbbbbbbbbb',
      title: null,
    );
    final videos = [choir1, choir2, instrumental];
    expect(videoName(videos, choir1), 'Chorale 1');
    expect(videoName(videos, choir2), 'Chorale 2');
    expect(videoName(videos, instrumental), 'Instrumental');
  });

  testApp('pas de vidéo : aucun bouton « Regarder »', (tester, _) async {
    await openHymn(tester, '2', 'L’Éternel est mon berger');
    expect(find.text('Regarder'), findsNothing);
  });

  testApp(
    'sans Internet : message clair, paroles strophe par strophe',
    (tester, _) async {
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      await tester.tap(find.text('Regarder'));
      await idle(tester);

      expect(find.text('Connexion nécessaire'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Chorale du dimanche'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Chorale 2'), findsOneWidget);

      // Ordre chanté : couplet 1, refrain, couplet 2, refrain.
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('L’Éternel est mon berger,'), findsOneWidget);
      await tester.tap(find.byTooltip('Strophe suivante'));
      await idle(tester);
      expect(find.text('2 / 4'), findsOneWidget);
      expect(find.text('Alléluia, gloire à Dieu,'), findsOneWidget);
      expect(find.text('L’Éternel est mon berger,'), findsNothing);
      await tester.tap(find.byTooltip('Strophe précédente'));
      await idle(tester);
      expect(find.text('1 / 4'), findsOneWidget);
    },
    hymns: hymnsWithVideos(),
    overrides: [internetCheckProvider.overrideWithValue(() async => false)],
  );

  testApp(
    'onglet Médias : les vidéos ouvrent l’écran « Regarder »',
    (tester, _) async {
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      await tester.tap(find.text('Médias'));
      await idle(tester);
      expect(find.text('Chorale du dimanche'), findsOneWidget);
      expect(find.text('Chorale 2'), findsOneWidget);
      await tester.tap(find.text('Chorale 2'));
      await idle(tester);
      expect(find.text('Connexion nécessaire'), findsOneWidget);
    },
    hymns: hymnsWithVideos(),
    overrides: [internetCheckProvider.overrideWithValue(() async => false)],
  );
}
