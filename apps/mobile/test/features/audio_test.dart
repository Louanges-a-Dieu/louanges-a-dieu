import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';
import 'package:louanges_a_dieu/core/preferences/preferences.dart';
import 'package:louanges_a_dieu/features/audio/audio_downloads.dart';
import 'package:louanges_a_dieu/features/audio/audio_player.dart';

import '../support/app_harness.dart';
import '../support/catalog_fixtures.dart';
import 'faithful_journey_test.dart' show idle, search;

/// Lecteur factice : enregistre les ordres reçus, sans réseau ni greffon.
final class FakePlayer implements HymnAudioPlayer {
  final opened = <Uri>[];
  final titles = <String>[];
  final seeks = <Duration>[];
  var stopped = false;
  Object? owner;
  var failNextOpen = false;
  final _state = ValueNotifier(const PlaybackState());

  @override
  ValueListenable<PlaybackState> get state => _state;

  void emit(PlaybackState s) => _state.value = s;

  @override
  Future<void> open(AudioSourceSpec source, {required Object owner}) async {
    this.owner = owner;
    opened.add(source.uri);
    titles.add('${source.title} · ${source.version}');
    _state.value = failNextOpen
        ? const PlaybackState(status: PlaybackStatus.error)
        : const PlaybackState(
            status: PlaybackStatus.ready,
            duration: Duration(seconds: 60),
          );
    failNextOpen = false;
  }

  double speed = 1;
  bool loop = false;

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> setLoop(bool loop) async => this.loop = loop;

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
  Future<void> release(Object owner) async {
    if (!identical(owner, this.owner)) return;
    this.owner = null;
    stopped = true;
    _state.value = const PlaybackState();
  }
}

/// Téléchargements factices : « fichiers » tenus en mémoire.
final class FakeDownloads implements AudioDownloads {
  final files = <String, File>{};
  final _states = <String, ValueNotifier<DownloadState>>{};

  @override
  bool get supported => true;

  @override
  Future<Directory> Function() get root => throw UnimplementedError();

  @override
  Future<File?> file(AudioTrack track) async => files[track.id];

  @override
  ValueListenable<DownloadState> watch(AudioTrack track) => _states.putIfAbsent(
    track.id,
    () => ValueNotifier(
      DownloadState(
        files.containsKey(track.id)
            ? DownloadStatus.ready
            : DownloadStatus.absent,
      ),
    ),
  );

  void _set(AudioTrack track, DownloadStatus status) =>
      (watch(track) as ValueNotifier<DownloadState>).value = DownloadState(
        status,
      );

  @override
  Future<void> download(AudioTrack track, Uri url) async {
    files[track.id] = File('/appareil/${track.id}.mp3');
    _set(track, DownloadStatus.ready);
  }

  @override
  Future<void> delete(AudioTrack track) async {
    files.remove(track.id);
    _set(track, DownloadStatus.absent);
  }

  @override
  Future<({int count, int bytes})> usage() async =>
      (count: files.length, bytes: files.length * 3 * 1024 * 1024);

  @override
  Future<void> deleteAll() async {
    files.clear();
    for (final s in _states.values) {
      s.value = const DownloadState(DownloadStatus.absent);
    }
  }
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

/// Comme [hymnsWithAudio], plus un accompagnement synchronisé vers par vers
/// (karaoké) : couplet 1, refrain, couplet 2 (deux vers chacun).
List<Map<String, Object?>> hymnsWithKaraoke() {
  final hymns = hymnsWithAudio();
  final hymn = hymns.firstWhere((h) => h['numberLabel'] == '2');
  final ids = [
    for (final s in hymn['sections']! as List<Object?>)
      (s! as Map<String, Object?>)['id']! as String,
  ];
  var t = 2000;
  final cues = <Map<String, Object?>>[];
  for (final (section, line) in [
    (ids[0], 0),
    (ids[0], 1),
    (ids[1], 0),
    (ids[1], 1),
    (ids[2], 0),
    (ids[2], 1),
  ]) {
    // Pause instrumentale de 10 s avant le couplet 2.
    if (section == ids[2] && line == 0) t += 10000;
    cues.add({
      'sectionId': section,
      'lineIndex': line,
      'startMs': t,
      'endMs': t + 4000,
      'order': cues.length,
    });
    t += 4000;
  }
  (hymn['audio']! as List<Object?>).add({
    'id': '00000000-0000-4000-8000-0000000a0003',
    'mediaType': 'accompaniment',
    'storageKey': 'cantiques/0002/accompagnement.mp3',
    'durationSeconds': 40,
    'segments': cues,
  });
  return hymns;
}

Future<void> openHymn(WidgetTester tester, String query, String title) async {
  await search(tester, query);
  await tester.tap(find.text(title).first);
  await idle(tester);
}

void main() {
  late FakePlayer player;
  late FakeDownloads downloads;
  setUp(() {
    player = FakePlayer();
    downloads = FakeDownloads();
  });
  final fakes = [
    audioPlayerProvider.overrideWith((ref) => player),
    audioDownloadsProvider.overrideWith((ref) => downloads),
  ];

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
      await tester.pump();
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
      await tester.pump();
      await idle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Chorale'));
      await idle(tester);
      expect(
        player.opened.last.toString(),
        '$_base/cantiques/0002/chorale.m4a',
      );

      // Notification et écran verrouillé : numéro, titre et version.
      expect(player.titles.first, '2 — L’Éternel est mon berger · Mélodie');

      // En quittant l'écran, la lecture s'arrête.
      await tester.tap(find.byType(BackButton));
      await idle(tester);
      expect(player.stopped, isTrue);
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
    overrides: fakes,
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
    overrides: fakes,
  );

  testApp(
    'hors connexion : télécharger, écouter le fichier, supprimer',
    (tester, _) async {
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      await tester.tap(find.text('Écouter'));
      await idle(tester);
      expect(player.opened.last.scheme, 'https');

      await tester.tap(find.text('Télécharger pour écouter sans Internet'));
      await idle(tester);
      expect(downloads.files, contains('00000000-0000-4000-8000-0000000a0001'));
      expect(
        find.text('Sur cet appareil : écoute sans Internet.'),
        findsOneWidget,
      );
      expect(
        find.text('L’écoute demande une connexion Internet.'),
        findsNothing,
      );

      // Écoute suivante : le fichier de l'appareil, sans réseau.
      await tester.tap(find.byType(BackButton));
      await idle(tester);
      await tester.tap(find.text('Écouter'));
      await idle(tester);
      expect(
        player.opened.last.toString(),
        'file:///appareil/00000000-0000-4000-8000-0000000a0001.mp3',
      );

      // Supprimer : retour à l'enregistrement en ligne.
      await tester.tap(find.text('Supprimer'));
      await idle(tester);
      expect(downloads.files, isEmpty);
      expect(player.opened.last.scheme, 'https');
      expect(
        find.text('Télécharger pour écouter sans Internet'),
        findsOneWidget,
      );
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
    overrides: fakes,
  );

  testApp(
    'Plus → Hors connexion : enregistrements sur l’appareil, place occupée',
    (tester, _) async {
      const track = AudioTrack(
        id: '00000000-0000-4000-8000-0000000a0001',
        mediaType: MediaType.melody,
        storageKey: 'cantiques/0002/melodie.mp3',
        duration: null,
        segments: [],
      );
      await downloads.download(track, Uri.parse('$_base/x.mp3'));
      await tester.tap(find.text('Plus').last);
      await idle(tester);
      await tester.tap(find.text('Hors connexion'));
      await idle(tester);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('3,0 Mo'), findsOneWidget);
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
    overrides: fakes,
  );

  testApp(
    'pas de piste synchronisée : aucun bouton « Karaoké »',
    (tester, _) async {
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      expect(find.text('Écouter'), findsOneWidget);
      expect(find.text('Karaoké'), findsNothing);
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
    overrides: fakes,
  );

  testApp(
    'karaoké : introduction, vers chanté, vers suivants, toucher pour y aller',
    (tester, _) async {
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      await tester.tap(find.text('Chanter'));
      await idle(tester);

      // L'accompagnement synchronisé est choisi d'abord.
      expect(
        player.opened.single.toString(),
        '$_base/cantiques/0002/accompagnement.mp3',
      );
      // Introduction : titre, compte à rebours, premier vers annoncé.
      expect(find.text('Début dans 2 s'), findsOneWidget);
      expect(find.text('L’Éternel est mon berger,'), findsOneWidget);

      // Pendant le 2ᵉ vers : le précédent et les deux suivants restent visibles.
      await player.seek(const Duration(seconds: 7));
      await idle(tester);
      final sung = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('Je ne manquerai de rien.'),
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.selected == true,
              ),
            )
            .first,
      );
      expect(sung.properties.selected, isTrue);
      expect(find.text('L’Éternel est mon berger,'), findsOneWidget);
      expect(find.text('REFRAIN'), findsNothing); // annoncé avec son 1er vers
      expect(find.text('Alléluia, gloire à Dieu,'), findsOneWidget);
      expect(find.text('Chantons Son Nom.'), findsOneWidget);
      expect(find.text('Il me fait reposer'), findsNothing);

      // Toucher un vers suivant : la lecture y va.
      await tester.tap(find.text('Chantons Son Nom.'));
      await idle(tester);
      expect(player.seeks.last, const Duration(seconds: 14));

      // Pause instrumentale (18 s → 28 s) : le dernier vers s'éteint, compte à
      // rebours jusqu'au couplet 2.
      await player.seek(const Duration(seconds: 21));
      await idle(tester);
      expect(find.text('Reprise dans 7 s'), findsOneWidget);
      expect(find.text('Il me fait reposer'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.selected == true,
        ),
        findsNothing,
      );

      // Écoute normale : le nouvel écran garde le lecteur.
      await tester.tap(find.byTooltip('Écoute normale'));
      await idle(tester);
      expect(player.stopped, isFalse);
      expect(
        player.opened.last.toString(),
        '$_base/cantiques/0002/melodie.mp3',
      );
      expect(find.text('Les paroles'), findsOneWidget);
    },
    hymns: hymnsWithKaraoke(),
    env: _audioEnv,
    overrides: fakes,
  );

  testApp(
    'écoute d’une piste synchronisée vers par vers : chaque strophe une fois',
    (tester, _) async {
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      await tester.tap(find.text('Écouter'));
      await idle(tester);
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Accompagnement'),
      );
      await tester.pump();
      await idle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Accompagnement'));
      await idle(tester);

      // 6 vers synchronisés → 3 strophes (couplet 1, refrain, couplet 2).
      expect(find.text('L’Éternel est mon berger,'), findsOneWidget);
      expect(find.text('Alléluia, gloire à Dieu,'), findsOneWidget);
      expect(find.text('Il me fait reposer'), findsOneWidget);

      // Pendant le 2ᵉ vers du refrain, le refrain entier est mis en avant ;
      // le toucher ramène au début du refrain.
      await player.seek(const Duration(seconds: 15));
      await idle(tester);
      await tester.ensureVisible(find.text('Chantons Son Nom.'));
      await tester.pump();
      await idle(tester);
      await tester.tap(find.text('Chantons Son Nom.'));
      await idle(tester);
      expect(player.seeks.last, const Duration(seconds: 10));
    },
    hymns: hymnsWithKaraoke(),
    env: _audioEnv,
    overrides: fakes,
  );

  testApp(
    'écoute : vitesse et boucle appliquées au lecteur et conservées',
    (tester, db) async {
      await openHymn(tester, '2', 'L’Éternel est mon berger');
      await tester.tap(find.text('Écouter'));
      await idle(tester);
      expect(player.speed, 1);
      await tester.ensureVisible(find.text('1,25'));
      await tester.pump();
      await tester.tap(find.text('1,25'));
      await idle(tester);
      expect(player.speed, 1.25);
      await tester.tap(find.text('Écouter en boucle'));
      await idle(tester);
      expect(player.loop, isTrue);
      final prefs = await settle(tester, PreferencesRepository(db).load());
      expect(prefs.audioSpeed, 1.25);
      expect(prefs.audioLoop, isTrue);
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
    overrides: fakes,
  );

  testApp(
    'hors connexion : choisir, télécharger puis libérer l’espace',
    (tester, _) async {
      await tester.tap(find.text('Plus').last);
      await idle(tester);
      await tester.tap(find.text('Hors connexion'));
      await idle(tester);
      expect(find.text('Sans Internet, vous pouvez'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);
      await tester.ensureVisible(find.text('Gérer les téléchargements'));
      await idle(tester);
      await tester.tap(find.text('Gérer les téléchargements'));
      await idle(tester);

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.tap(find.byType(CheckboxListTile).last);
      await idle(tester);
      await tester.tap(find.text('Télécharger (2)'));
      await idle(tester);
      expect(downloads.files, hasLength(2));
      expect(find.textContaining('sur l’appareil'), findsNWidgets(2));

      await tester.tap(find.text('Libérer de l’espace'));
      await idle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await idle(tester);
      expect(downloads.files, isEmpty);
    },
    hymns: hymnsWithAudio(),
    env: _audioEnv,
    overrides: fakes,
  );
}
