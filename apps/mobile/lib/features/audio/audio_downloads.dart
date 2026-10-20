import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/catalog/published_hymn.dart';

enum DownloadStatus { unknown, absent, downloading, ready, failed }

/// Disponibilité hors connexion d'un enregistrement.
@immutable
final class DownloadState {
  const DownloadState(this.status, {this.progress});

  final DownloadStatus status;

  /// Avancement entre 0 et 1, s'il est connu (taille annoncée).
  final double? progress;
}

/// Enregistrements téléchargés pour l'écoute hors connexion.
///
/// Un fichier par piste, `<racine>/<id de piste>/<clé aplatie>` : si la clé
/// change (fichier remplacé sur l'hébergement), l'ancien fichier n'est plus
/// utilisé et disparaît au prochain téléchargement. Le fichier n'apparaît
/// qu'une fois complet (écrit à part, puis renommé).
class AudioDownloads {
  AudioDownloads({required this.root, http.Client? client})
    : _client = client ?? http.Client();

  /// Dossier des enregistrements téléchargés.
  final Future<Directory> Function() root;
  final http.Client _client;
  final _states = <String, ValueNotifier<DownloadState>>{};

  /// Faux dans un navigateur : pas de stockage de fichiers.
  bool get supported => !kIsWeb;

  Future<Directory> _trackDir(AudioTrack track) async =>
      Directory('${(await root()).path}/${track.id}');

  Future<File> _target(AudioTrack track) async => File(
    '${(await _trackDir(track)).path}/${track.storageKey.replaceAll('/', '_')}',
  );

  /// Fichier complet de [track] sur l'appareil, ou `null`.
  Future<File?> file(AudioTrack track) async {
    if (!supported) return null;
    final file = await _target(track);
    return file.existsSync() ? file : null;
  }

  /// État de [track], vérifié sur le disque au premier appel.
  ValueListenable<DownloadState> watch(AudioTrack track) {
    final existing = _states[track.id];
    if (existing != null) return existing;
    final notifier = _states[track.id] = ValueNotifier(
      const DownloadState(DownloadStatus.unknown),
    );
    unawaited(
      file(track).then((f) {
        if (notifier.value.status == DownloadStatus.unknown) {
          notifier.value = DownloadState(
            f == null ? DownloadStatus.absent : DownloadStatus.ready,
          );
        }
      }),
    );
    return notifier;
  }

  /// Télécharge [track] depuis [url] ; sans effet s'il est déjà présent ou en
  /// cours de téléchargement.
  Future<void> download(AudioTrack track, Uri url) async {
    final state = watch(track) as ValueNotifier<DownloadState>;
    if (state.value.status == DownloadStatus.downloading) return;
    final target = await _target(track);
    if (target.existsSync()) {
      state.value = const DownloadState(DownloadStatus.ready);
      return;
    }
    state.value = const DownloadState(DownloadStatus.downloading, progress: 0);
    final partial = File('${target.path}.part');
    try {
      await partial.parent.create(recursive: true);
      final response = await _client.send(http.Request('GET', url));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }
      final total = response.contentLength;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          state.value = DownloadState(
            DownloadStatus.downloading,
            progress: total == null || total == 0 ? null : received / total,
          );
        }
      } finally {
        await sink.close();
      }
      if (total != null && received != total) {
        throw const HttpException('Téléchargement incomplet');
      }
      await partial.rename(target.path);
      // Versions précédentes de la piste (clé changée).
      for (final old in target.parent.listSync()) {
        if (old.path != target.path) await old.delete(recursive: true);
      }
      state.value = const DownloadState(DownloadStatus.ready);
    } on Object {
      if (partial.existsSync()) await partial.delete();
      state.value = const DownloadState(DownloadStatus.failed);
    }
  }

  /// Retire [track] de l'appareil.
  Future<void> delete(AudioTrack track) async {
    final dir = await _trackDir(track);
    if (dir.existsSync()) await dir.delete(recursive: true);
    (watch(track) as ValueNotifier<DownloadState>).value = const DownloadState(
      DownloadStatus.absent,
    );
  }

  /// Nombre d'enregistrements téléchargés et place occupée (octets).
  Future<({int count, int bytes})> usage() async {
    if (!supported) return (count: 0, bytes: 0);
    final dir = await root();
    if (!dir.existsSync()) return (count: 0, bytes: 0);
    var count = 0;
    var bytes = 0;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && !entity.path.endsWith('.part')) {
        count++;
        bytes += entity.lengthSync();
      }
    }
    return (count: count, bytes: bytes);
  }

  /// Retire tous les enregistrements téléchargés.
  Future<void> deleteAll() async {
    if (!supported) return;
    final dir = await root();
    if (dir.existsSync()) await dir.delete(recursive: true);
    for (final state in _states.values) {
      if (state.value.status != DownloadStatus.downloading) {
        state.value = const DownloadState(DownloadStatus.absent);
      }
    }
  }
}

final audioDownloadsProvider = Provider<AudioDownloads>(
  (ref) => AudioDownloads(
    root: () async =>
        Directory('${(await getApplicationSupportDirectory()).path}/audio'),
  ),
);

/// Place occupée par les enregistrements téléchargés (Plus → Hors connexion).
final audioDownloadsUsageProvider =
    FutureProvider.autoDispose<({int count, int bytes})>(
      (ref) => ref.watch(audioDownloadsProvider).usage(),
    );
