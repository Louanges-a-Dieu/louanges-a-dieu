import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/env.dart';
import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/dialogs.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import 'audio_downloads.dart';

/// Cantiques qui ont un enregistrement publié.
final hymnsWithAudioProvider = FutureProvider<List<PublishedHymn>>((ref) {
  ref.watch(hymnsByNumberProvider);
  return ref.watch(catalogRepositoryProvider).hymnsWithAudio();
});

/// Avancement d'un téléchargement groupé.
@immutable
final class BatchState {
  const BatchState({this.total = 0, this.done = 0, this.failed = 0});

  final int total;
  final int done;
  final int failed;

  bool get running => done + failed < total;
}

/// Téléchargements groupés (planche 7, écrans 3 et 5) : un enregistrement
/// après l'autre, annulables ; continuent si l'on quitte l'écran.
class AudioBatch extends Notifier<BatchState> {
  bool _cancelled = false;

  @override
  BatchState build() => const BatchState();

  Future<void> start(List<(AudioTrack, Uri)> tracks) async {
    if (state.running || tracks.isEmpty) return;
    _cancelled = false;
    state = BatchState(total: tracks.length);
    final downloads = ref.read(audioDownloadsProvider);
    for (final (track, url) in tracks) {
      if (_cancelled) break;
      await downloads.download(track, url);
      final ok = downloads.watch(track).value.status == DownloadStatus.ready;
      state = BatchState(
        total: state.total,
        done: state.done + (ok ? 1 : 0),
        failed: state.failed + (ok ? 0 : 1),
      );
    }
    if (_cancelled) state = const BatchState();
    ref.invalidate(audioDownloadsUsageProvider);
  }

  /// Arrête après l'enregistrement en cours (il est conservé s'il aboutit).
  void cancel() => _cancelled = true;
}

final audioBatchProvider = NotifierProvider<AudioBatch, BatchState>(
  AudioBatch.new,
);

/// Écoute hors connexion (planche 7, écrans 2 à 5) : choisir les
/// enregistrements à télécharger (tous, favoris), suivre l'avancement,
/// supprimer ceux qui sont sur l'appareil.
class AudioLibraryScreen extends ConsumerStatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  ConsumerState<AudioLibraryScreen> createState() => _AudioLibraryState();
}

class _AudioLibraryState extends ConsumerState<AudioLibraryScreen> {
  final _selected = <String>{};
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final env = ref.watch(envProvider);
    final downloads = ref.watch(audioDownloadsProvider);
    final batch = ref.watch(audioBatchProvider);
    final favorites = ref.watch(favoriteIdsProvider).value ?? const {};
    final all = ref.watch(hymnsWithAudioProvider).value;
    final usage = ref.watch(audioDownloadsUsageProvider).value;
    final hymns = [
      for (final h in all ?? const <PublishedHymn>[])
        if (!_favoritesOnly || favorites.contains(h.id)) h,
    ];
    final megabytes = NumberFormat(
      '0.0',
      'fr',
    ).format((usage?.bytes ?? 0) / (1024 * 1024));

    Future<void> download() {
      final tracks = [
        for (final h in hymns)
          for (final t in h.audio)
            if (_selected.contains(t.id)) (t, env.audioUrl(t.storageKey)),
      ];
      setState(_selected.clear);
      return ref.read(audioBatchProvider.notifier).start(tracks);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.audioLibraryTitle)),
      body: Column(
        children: [
          ReadableWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.lg,
                LadSpace.sm,
                LadSpace.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    usage == null
                        ? '—'
                        : l10n.audioDownloadsUsage(usage.count, megabytes),
                    style: LadTheme.textStyle(
                      LadTypeScale.body,
                      p.textSecondary,
                    ),
                  ),
                  if (batch.running) ...[
                    const SizedBox(height: LadSpace.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.batchProgress(
                          batch.done + batch.failed + 1,
                          batch.total,
                        ),
                        style: LadTheme.textStyle(LadTypeScale.label, p.text),
                      ),
                    ),
                    const SizedBox(height: LadSpace.xs),
                    LinearProgressIndicator(
                      value: (batch.done + batch.failed) / batch.total,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: ref.read(audioBatchProvider.notifier).cancel,
                        child: Text(l10n.cancel),
                      ),
                    ),
                  ] else if (batch.failed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: LadSpace.sm),
                      child: Text(
                        l10n.batchFailed(batch.failed),
                        style: LadTheme.textStyle(LadTypeScale.label, p.error),
                      ),
                    ),
                  const SizedBox(height: LadSpace.sm),
                  Text(
                    l10n.wifiRecommended,
                    style: LadTheme.textStyle(
                      LadTypeScale.caption,
                      p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: LadSpace.sm),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(l10n.filterAll)),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.navFavorites),
                      ),
                    ],
                    selected: {_favoritesOnly},
                    onSelectionChanged: (s) =>
                        setState(() => _favoritesOnly = s.first),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: all == null
                ? const Center(child: CircularProgressIndicator())
                : hymns.isEmpty
                ? MessageState(title: l10n.audioLibraryEmpty)
                : ListView(
                    children: [
                      for (final hymn in hymns)
                        for (final track in hymn.audio)
                          ReadableWidth(
                            child: _TrackRow(
                              hymn: hymn,
                              track: track,
                              state: downloads.watch(track),
                              selected: _selected.contains(track.id),
                              onSelected: (v) => setState(
                                () => v
                                    ? _selected.add(track.id)
                                    : _selected.remove(track.id),
                              ),
                            ),
                          ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: ReadableWidth(
              child: Padding(
                padding: const EdgeInsets.all(LadSpace.md),
                child: Row(
                  children: [
                    if ((usage?.count ?? 0) > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: batch.running
                              ? null
                              : () async {
                                  if (!await confirmDialog(
                                    context,
                                    title: l10n.audioDownloadsDeleteAll,
                                    message: l10n.audioDownloadsDeleteConfirm,
                                    action: l10n.audioRemoveDownload,
                                    destructive: true,
                                  )) {
                                    return;
                                  }
                                  await downloads.deleteAll();
                                  ref.invalidate(audioDownloadsUsageProvider);
                                },
                          child: Text(l10n.freeSpace),
                        ),
                      ),
                      const SizedBox(width: LadSpace.sm),
                    ],
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _selected.isEmpty || batch.running
                            ? null
                            : download,
                        child: Text(l10n.downloadCount(_selected.length)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un enregistrement : case à cocher s'il n'est pas sur l'appareil, sinon
/// « Sur l'appareil » et suppression ; avancement pendant le téléchargement.
class _TrackRow extends ConsumerWidget {
  const _TrackRow({
    required this.hymn,
    required this.track,
    required this.state,
    required this.selected,
    required this.onSelected,
  });

  final PublishedHymn hymn;
  final AudioTrack track;
  final ValueListenable<DownloadState> state;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final subtitle = [
      mediaTypeName(track.mediaType),
      if (track.duration case final d?)
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}',
    ].join(' · ');
    return ValueListenableBuilder(
      valueListenable: state,
      builder: (context, download, _) => switch (download.status) {
        DownloadStatus.ready => ListTile(
          leading: HymnNumberBadge(hymn.numberLabel),
          title: Text(hymn.title),
          subtitle: Text('$subtitle · ${l10n.onDevice}'),
          trailing: IconButton(
            tooltip: l10n.audioRemoveDownload,
            icon: Icon(Icons.delete_outline, color: p.textSecondary),
            onPressed: () async {
              await ref.read(audioDownloadsProvider).delete(track);
              ref.invalidate(audioDownloadsUsageProvider);
            },
          ),
        ),
        DownloadStatus.downloading => ListTile(
          leading: HymnNumberBadge(hymn.numberLabel),
          title: Text(hymn.title),
          subtitle: LinearProgressIndicator(value: download.progress),
        ),
        _ => CheckboxListTile(
          value: selected,
          onChanged: (v) => onSelected(v!),
          secondary: HymnNumberBadge(hymn.numberLabel),
          title: Text(hymn.title),
          subtitle: Text(
            download.status == DownloadStatus.failed
                ? '$subtitle · ${l10n.downloadFailed}'
                : subtitle,
          ),
        ),
      },
    );
  }
}
