import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/catalog/published_hymn.dart';
import '../../core/projection/projection_server.dart';
import 'audio_player.dart';
import 'karaoke_screen.dart';

/// Message du karaoké pour les écrans (TV, ordinateur) : tous les vers avec
/// leurs instants, et l'horloge de lecture (position, lecture en cours).
/// L'écran fait avancer l'horloge lui-même entre deux messages : le
/// remplissage du vers reste fluide sans envoyer un message par image.
/// Contrat lu par assets/projection/screen.js (`type: "karaoke"`).
Map<String, Object?> karaokeMessage({
  required PublishedHymn hymn,
  required List<KaraokeLine> lines,
  required Duration position,
  required bool playing,
}) => {
  'type': 'karaoke',
  'v': 1,
  'numberLabel': hymn.numberLabel,
  'title': hymn.title,
  'position': position.inMilliseconds,
  'playing': playing,
  'lines': [
    for (final line in lines)
      {
        'text': line.text,
        'start': line.start.inMilliseconds,
        'end': line.end.inMilliseconds,
        'section': line.section.id,
        'sectionName': sectionName(line.section.type, line.section.number),
      },
  ],
};

/// Affichage du karaoké sur des écrans : serveur local de la projection
/// (sans Internet, ADR-013) ; le son reste sur le téléphone. Envoie
/// l'horloge à chaque lecture, pause ou saut, et au moins chaque seconde.
class KaraokeCaster {
  KaraokeCaster({
    required this.host,
    required this.player,
    required this.hymn,
    required this.lines,
  }) {
    player.state.addListener(_onState);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => publish());
    publish();
  }

  final ProjectionHost host;
  final HymnAudioPlayer player;
  PublishedHymn hymn;
  List<KaraokeLine> lines;
  late final Timer _timer;

  PlaybackState? _last;
  final _sinceLast = Stopwatch();

  /// Autre version de l'enregistrement : autres instants.
  void setLines(PublishedHymn hymn, List<KaraokeLine> lines) {
    this.hymn = hymn;
    this.lines = lines;
    publish();
  }

  void _onState() {
    final state = player.state.value;
    final last = _last;
    if (last == null) return publish();
    // Lecture / pause, ou saut : la position diffère de celle attendue.
    final expected =
        last.position + (last.playing ? _sinceLast.elapsed : Duration.zero);
    final drift = (state.position - expected).abs();
    if (state.playing != last.playing ||
        drift > const Duration(milliseconds: 400)) {
      publish();
    }
  }

  void publish() {
    final state = player.state.value;
    _last = state;
    _sinceLast
      ..reset()
      ..start();
    host.publish(
      karaokeMessage(
        hymn: hymn,
        lines: lines,
        position: state.position,
        playing: state.playing,
      ),
    );
  }

  Future<void> stop() async {
    _timer.cancel();
    player.state.removeListener(_onState);
    await host.stop();
  }

  @visibleForTesting
  bool get running => _timer.isActive;
}
