import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/features/audio/audio_player.dart';

import '../support/app_harness.dart';
import '../support/catalog_fixtures.dart';
import 'faithful_journey_test.dart' show idle, search;

/// Lecteur factice : enregistre les ordres reçus, sans réseau ni greffon.
final class FakePlayer implements HymnAudioPlayer {
  final opened = <Uri>[];
  final seeks = <Duration>[];
  var disposed = false;
  var failNextOpen = false;
  final _state = ValueNotifier(const PlaybackState());

  @override
  ValueListenable<PlaybackState> get state => _state;

  void emit(PlaybackState s) => _state.value = s;

  @override
  Future<void> open(Uri url) async {
    opened.add(url);
    _state.value = failNextOpen
        ? const PlaybackState(status: PlaybackStatus.error)
        : const PlaybackState(
            status: PlaybackStatus.ready,
            duration: Duration(seconds: 60),
          );
    failNextOpen = false;
  }

  @override
  Future<void> play() async =>
      _state.value = _state.value.copyWith(playing: true);

  @override
  Future<void> pause() async =>
      _state.value = _state.value.copyWith(playing: false);

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _state.value = _state.value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

const _base = 'https://media.test/lad-audio';
const _audioEnv = {'APP_ENV': 'dev', 'AUDIO_BASE_URL': _base};

/// Recueil d'essai où le cantique 2 (couplet 1, refrain, couplet 2) a une
/// mélodie aux passages repérés et une version chorale.
List<Map<String, Object?>> hymnsWithAudio() {
  final hymns = sampleHymns();
  final hymn = hymns.firstWhere((h) => h['numberLabel'] == '2');
  final ids = [
    for (final s in hymn['sections']! as List<Object?>)
      (s! as Map<String, Object?>)['id']! as String,
  ];
  hymn['audio'] = [
    {
      'id': '00000000-0000-4000-8000-0000000a0001',
      'mediaType': 'melody',
      'storageKey': 'cantiques/0002/melodie.mp3',
      'durationSeconds': 60,
      'segments': [
        {'sectionId': ids[0], 'startMs': 0, 'endMs': 20000, 'order': 0},
        {'sectionId': ids[1], 'startMs': 20000, 'endMs': 35000, 'order': 1},
        {'sectionId': ids[2], 'startMs': 35000, 'endMs': 50000, 'order': 2},
        {'sectionId': ids[1], 'startMs': 50000, 'endMs': 60000, 'order': 3},
      ],
    },
    {
      'id': '00000000-0000-4000-8000-0000000a0002',
      'mediaType': 'choir',
      'storageKey': 'cantiques/0002/chorale.m4a',
      'durationSeconds': null,
      'segments': const <Object?>[],
    },
  ];
  return hymns;
}

Future<void> openHymn(WidgetTester tester, String query, String title) async {
  await search(tester, query);
  await tester.tap(find.text(title).first);
  await idle(tester);
}

void main() {
  late FakePlayer player;
  setUp(() => player = FakePlayer());

  testApp('pas d’hébergement configuré : aucun bouton « Écouter »', (
    tester,
    _,
  ) async {
    await openHymn(tester, '2', 'L’Éternel est mon berger');
    expect(find.text('Écouter'), findsNothing);
  }, hymns: hymnsWithAudio());

  testApp(
    'cantique sans enregistrement : aucun bouton « Écouter »',
    (tester, _) async {
      await openHymn(tester, '37', 'Au matin');
      expect(find.text('Écouter'), findsNothing);
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
  );

  testApp(
    'écoute : lecture, pause, ±10 s, paroles qui suivent, choix de version',
    (tester, _) async {
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      await tester.tap(find.text('Écouter'));
      await idle(tester);

      // Mélodie préparée depuis l'hébergement, sans lecture automatique.
      expect(
        player.opened.single.toString(),
        '$_base/cantiques/0002/melodie.mp3',
      );
      expect(player.state.value.playing, isFalse);
      expect(find.text('Mélodie'), findsWidgets);
      expect(find.text('1:00'), findsOneWidget);
      expect(
        find.text('L’écoute demande une connexion Internet.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Lecture'));
      await idle(tester);
      expect(player.state.value.playing, isTrue);
      expect(find.byTooltip('Pause'), findsOneWidget);

      await tester.tap(find.byTooltip('Avancer de 10 secondes'));
      await idle(tester);
      expect(player.seeks.last, const Duration(seconds: 10));

      // Paroles dans l'ordre de l'enregistrement : le refrain deux fois.
      expect(find.text('Alléluia, gloire à Dieu,'), findsNWidgets(2));

      // Toucher le second couplet : la lecture y va.
      await tester.ensureVisible(find.text('Il me fait reposer'));
      await idle(tester);
      await tester.tap(find.text('Il me fait reposer'));
      await idle(tester);
      expect(player.seeks.last, const Duration(seconds: 35));
      final tile = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('Il me fait reposer'),
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.selected != null,
              ),
            )
            .first,
      );
      expect(tile.properties.selected, isTrue);

      // Autre version : la chorale est préparée à son tour.
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Chorale'));
      await idle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Chorale'));
      await idle(tester);
      expect(
        player.opened.last.toString(),
        '$_base/cantiques/0002/chorale.m4a',
      );

      // En quittant l'écran, le lecteur est libéré (la lecture s'arrête).
      await tester.tap(find.byType(BackButton));
      await idle(tester);
      expect(player.disposed, isTrue);
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
    overrides: [audioPlayerFactoryProvider.overrideWithValue(() => player)],
  );

  testApp(
    'écoute : échec de chargement, message puis nouvel essai',
    (tester, _) async {
      player.failNextOpen = true;
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      await tester.tap(find.text('Écouter'));
      await idle(tester);
      expect(find.text('Lecture impossible'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await idle(tester);
      expect(player.opened, hasLength(2));
      expect(find.text('Lecture impossible'), findsNothing);
      expect(find.byTooltip('Lecture'), findsOneWidget);
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
    overrides: [audioPlayerFactoryProvider.overrideWithValue(() => player)],
  );
}
