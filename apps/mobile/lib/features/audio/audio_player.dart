import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Étape du lecteur, telle que l'écran la présente.
enum PlaybackStatus { idle, loading, ready, completed, error }

/// État observable du lecteur d'enregistrements.
@immutable
final class PlaybackState {
  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
  });

  final PlaybackStatus status;
  final bool playing;
  final Duration position;

  /// Durée lue sur le fichier ; `null` tant qu'elle n'est pas connue.
  final Duration? duration;

  PlaybackState copyWith({
    PlaybackStatus? status,
    bool? playing,
    Duration? position,
    Duration? duration,
  }) => PlaybackState(
    status: status ?? this.status,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

/// Enregistrement à lire : adresse web, ou fichier téléchargé sur l'appareil
/// (`file://`), et ce qu'affichent la notification et l'écran verrouillé.
@immutable
final class AudioSourceSpec {
  const AudioSourceSpec({
    required this.id,
    required this.uri,
    required this.title,
    required this.version,
  });

  final String id;
  final Uri uri;

  /// « 6 — Oui, certains chantent ».
  final String title;

  /// « Mélodie », « Chorale »…
  final String version;
}

/// Lecteur des enregistrements de cantiques. Un seul pour toute l'app : la
/// lecture continue app en arrière-plan ou écran verrouillé, avec les
/// commandes du système (notification, écran verrouillé, casque). Abstrait
/// pour que les tests d'écran n'aient besoin ni de réseau ni de greffon.
abstract interface class HymnAudioPlayer {
  ValueListenable<PlaybackState> get state;

  /// Prépare [source] sans lancer la lecture, pour l'écran [owner].
  Future<void> open(AudioSourceSpec source, {required Object owner});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// Arrête la lecture en quittant l'écran [owner] ; sans effet si un autre
  /// écran (karaoké ↔ écoute) a déjà pris le lecteur.
  Future<void> release(Object owner);
}

/// Lecteur unique de l'app.
final audioPlayerProvider = Provider<HymnAudioPlayer>((ref) {
  final player = JustAudioHymnPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// À appeler une fois au démarrage, avant tout lecteur : service de lecture
/// en arrière-plan et canal de notification Android.
Future<void> initBackgroundAudio() => JustAudioBackground.init(
  androidNotificationChannelId: 'org.louangesadieu.app.audio',
  androidNotificationChannelName: 'Écoute des cantiques',
  androidNotificationOngoing: true,
);

/// Implémentation `just_audio` (+ `just_audio_background`) : iOS, Android et
/// navigateur.
final class JustAudioHymnPlayer implements HymnAudioPlayer {
  JustAudioHymnPlayer() {
    _subscriptions = [
      _player.playerStateStream.listen(_onPlayerState, onError: _onError),
      _player.positionStream.listen(
        (p) => _state.value = _state.value.copyWith(position: p),
      ),
      _player.durationStream.listen((d) {
        if (d != null) _state.value = _state.value.copyWith(duration: d);
      }),
      _player.playbackEventStream.listen((_) {}, onError: _onError),
    ];
  }

  final _player = AudioPlayer();
  final _state = ValueNotifier(const PlaybackState());
  late final List<StreamSubscription<Object?>> _subscriptions;
  Future<void>? _session;
  Object? _owner;

  @override
  ValueListenable<PlaybackState> get state => _state;

  @override
  Future<void> open(AudioSourceSpec source, {required Object owner}) async {
    _owner = owner;
    // Catégorie « musique » : l'écoute reste audible quand le téléphone est
    // en mode silencieux, comme pour toute app de musique.
    await (_session ??= AudioSession.instance.then(
      (s) => s.configure(const AudioSessionConfiguration.music()),
    ));
    _state.value = const PlaybackState(status: PlaybackStatus.loading);
    try {
      final duration = await _player.setAudioSource(
        AudioSource.uri(
          source.uri,
          tag: MediaItem(
            id: source.id,
            title: source.title,
            artist: source.version,
            album: 'Louanges à Dieu',
          ),
        ),
      );
      _state.value = _state.value.copyWith(
        status: PlaybackStatus.ready,
        duration: duration,
      );
    } on Exception catch (e) {
      _onError(e);
    }
  }

  void _onPlayerState(PlayerState s) {
    if (_state.value.status == PlaybackStatus.error) return;
    _state.value = _state.value.copyWith(
      playing: s.playing && s.processingState != ProcessingState.completed,
      status: switch (s.processingState) {
        ProcessingState.idle => _state.value.status,
        ProcessingState.loading ||
        ProcessingState.buffering => PlaybackStatus.loading,
        ProcessingState.ready => PlaybackStatus.ready,
        ProcessingState.completed => PlaybackStatus.completed,
      },
    );
  }

  void _onError(Object error) => _state.value = _state.value.copyWith(
    status: PlaybackStatus.error,
    playing: false,
  );

  @override
  Future<void> play() async {
    if (_state.value.status == PlaybackStatus.completed) {
      await _player.seek(Duration.zero);
    }
    // play() ne se termine qu'à la pause : ne pas l'attendre.
    unawaited(_player.play().catchError(_onError));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> release(Object owner) async {
    if (!identical(owner, _owner)) return;
    _owner = null;
    await _player.stop();
    _state.value = const PlaybackState();
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    _state.dispose();
  }
}
