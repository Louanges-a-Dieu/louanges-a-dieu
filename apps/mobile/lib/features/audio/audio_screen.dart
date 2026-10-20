import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/env.dart';
import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/catalog/sung_order.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorite_button.dart';
import 'audio_downloads.dart';
import 'audio_player.dart';

/// Source d'une piste : le fichier téléchargé s'il existe (écoute sans
/// Internet), sinon l'enregistrement en ligne.
Future<AudioSourceSpec> audioSourceFor(
  WidgetRef ref,
  PublishedHymn hymn,
  AudioTrack track,
) async {
  File? file;
  try {
    file = await ref.read(audioDownloadsProvider).file(track);
  } on Object {
    file =
        null; // stockage illisible : l'enregistrement en ligne reste possible
  }
  return AudioSourceSpec(
    id: track.id,
    uri: file?.uri ?? ref.read(envProvider).audioUrl(track.storageKey),
    title: '${hymn.numberLabel} — ${hymn.title}',
    version: mediaTypeName(track.mediaType),
  );
}

/// Vrai si le karaoké de [hymn] est possible : une piste synchronisée ligne
/// par ligne.
bool canKaraoke(Env env, PublishedHymn hymn) =>
    canListen(env, hymn) && hymn.audio.any((t) => t.hasLineCues);

/// Vrai si l'écoute de [hymn] est possible : au moins un enregistrement
/// publié et un hébergement configuré. Sinon, aucun bouton « Écouter ».
bool canListen(Env env, PublishedHymn hymn) =>
    env.hasAudio && hymn.audio.isNotEmpty;

/// Écoute d'un cantique (ADR-016) : enregistrement lu en flux depuis
/// l'hébergement des médias, choix de la version, paroles qui suivent
/// l'enregistrement quand ses passages sont repérés. Demande Internet ; la
/// lecture s'arrête en quittant l'écran.
class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key, required this.hymnId});

  final String hymnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final env = ref.watch(envProvider);
    final hymn = ref.watch(hymnProvider(hymnId));
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (hymn.value case final h? when canKaraoke(env, h))
            IconButton(
              tooltip: l10n.karaokeTooltip,
              icon: const Icon(Icons.mic_none),
              onPressed: () => context.pushReplacement('/karaoke/$hymnId'),
            ),
          FavoriteButton(hymnId: hymnId),
        ],
      ),
      body: hymn.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => MessageState(title: '$e'),
        data: (h) => switch (h) {
          null => MessageState(
            title: l10n.hymnRemovedTitle,
            message: l10n.hymnRemovedMessage,
          ),
          final h when !canListen(env, h) => MessageState(
            title: l10n.noRecordingTitle,
            message: l10n.noRecordingMessage,
          ),
          final h => _Listening(hymn: h),
        },
      ),
    );
  }
}

class _Listening extends ConsumerStatefulWidget {
  const _Listening({required this.hymn});

  final PublishedHymn hymn;

  @override
  ConsumerState<_Listening> createState() => _ListeningState();
}

class _ListeningState extends ConsumerState<_Listening> {
  late final HymnAudioPlayer _player = ref.read(audioPlayerProvider);
  late AudioTrack _track = widget.hymn.audio.first;

  /// Position pendant que l'on fait glisser le curseur.
  Duration? _dragging;

  final _segmentKeys = <int, GlobalKey>{};
  int? _followed;

  @override
  void initState() {
    super.initState();
    _open();
    _player.state.addListener(_follow);
  }

  @override
  void dispose() {
    _player.state.removeListener(_follow);
    // La lecture continue écran verrouillé, mais pas après avoir quitté l'écran.
    _player.release(this);
    super.dispose();
  }

  /// Prépare la piste choisie : le fichier téléchargé s'il existe (écoute
  /// sans Internet), sinon l'enregistrement en ligne.
  Future<void> _open() async {
    final track = _track;
    final source = await audioSourceFor(ref, widget.hymn, track);
    if (!mounted || track.id != _track.id) return;
    await _player.open(source, owner: this);
  }

  void _choose(AudioTrack track) {
    if (track.id == _track.id) return;
    setState(() {
      _track = track;
      _followed = null;
    });
    _open();
  }

  /// Passage en cours (index dans [AudioTrack.segments]), s'il est repéré.
  int? _current(Duration position) {
    final segments = _track.segments;
    for (var i = 0; i < segments.length; i++) {
      if (position >= segments[i].start && position < segments[i].end) {
        return i;
      }
    }
    return null;
  }

  /// Fait défiler les paroles jusqu'au passage chanté.
  void _follow() {
    final current = _current(_player.state.value.position);
    if (current == null || current == _followed) return;
    _followed = current;
    final target = _segmentKeys[current]?.currentContext;
    if (target == null || !_player.state.value.playing) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.15,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : LadDurations.base,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final hymn = widget.hymn;
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final compact = MediaQuery.sizeOf(context).width < 600;
    final sectionsById = {for (final s in hymn.sections) s.id: s};

    return ValueListenableBuilder(
      valueListenable: _player.state,
      builder: (context, state, _) {
        final current = _current(_dragging ?? state.position);
        final list = ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? LadSpace.lg : LadSpace.xl,
            LadSpace.sm,
            compact ? LadSpace.lg : LadSpace.xl,
            LadSpace.huge,
          ),
          children: [
            ReadableWidth(
              maxWidth: 680,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Banner(hymn: hymn, track: _track),
                  const SizedBox(height: LadSpace.md),
                  _Offline(
                    key: ValueKey(_track.id),
                    track: _track,
                    onDeleted: _open,
                  ),
                  if (hymn.audio.length > 1) ...[
                    const SizedBox(height: LadSpace.lg),
                    TrackChoice(
                      tracks: hymn.audio,
                      selected: _track,
                      onSelected: _choose,
                    ),
                  ],
                  const SizedBox(height: LadSpace.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.lyricsHeading,
                      style: LadTheme.textStyle(
                        LadTypeScale.sectionTitle,
                        p.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: LadSpace.md),
                  if (_track.segments.any((s) => s.sectionId != null))
                    for (final (i, segment) in _track.segments.indexed)
                      if (sectionsById[segment.sectionId] case final section?)
                        _SegmentTile(
                          key: _segmentKeys.putIfAbsent(i, GlobalKey.new),
                          section: section,
                          fontSize: prefs.lyricsSize,
                          current: i == current,
                          onTap: () => _player.seek(segment.start),
                        )
                      else
                        const SizedBox.shrink()
                  else
                    // Passages non repérés : paroles dans l'ordre chanté.
                    for (final section in sungOrder(hymn.sections))
                      _SegmentTile(
                        section: section,
                        fontSize: prefs.lyricsSize,
                        current: false,
                      ),
                ],
              ),
            ),
          ],
        );
        // Les paroles défilent (et suivent le chant) ; le lecteur reste en bas.
        return Column(
          children: [
            Expanded(child: list),
            PlayerBar(
              state: state,
              track: _track,
              dragging: _dragging,
              onDrag: (d) => setState(() => _dragging = d),
              onSeek: (d) {
                setState(() => _dragging = null);
                _player.seek(d);
              },
              onPlay: _player.play,
              onPause: _player.pause,
              onRetry: _open,
              onSkip: (delta) {
                final total = state.duration ?? _track.duration;
                var target = state.position + delta;
                if (target < Duration.zero) target = Duration.zero;
                if (total != null && target > total) target = total;
                _player.seek(target);
              },
            ),
          ],
        );
      },
    );
  }
}

/// Écoute hors connexion de la version choisie : téléchargement (avec son
/// avancement), puis « sur cet appareil » et suppression. Dans un navigateur,
/// seule la mention « demande une connexion Internet » reste.
class _Offline extends ConsumerWidget {
  const _Offline({super.key, required this.track, required this.onDeleted});

  final AudioTrack track;

  /// Après suppression du fichier : revenir à l'enregistrement en ligne.
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final downloads = ref.watch(audioDownloadsProvider);
    final caption = LadTheme.textStyle(LadTypeScale.caption, p.textSecondary);
    if (!downloads.supported) {
      return Text(l10n.audioNeedsNetwork, style: caption);
    }
    return ValueListenableBuilder(
      valueListenable: downloads.watch(track),
      builder: (context, state, _) => switch (state.status) {
        DownloadStatus.unknown => const SizedBox(height: LadSpace.xxl),
        DownloadStatus.ready => Row(
          children: [
            Icon(Icons.offline_pin_outlined, color: p.gold, size: 20),
            const SizedBox(width: LadSpace.sm),
            Expanded(child: Text(l10n.audioOnDevice, style: caption)),
            TextButton(
              onPressed: () async {
                await downloads.delete(track);
                onDeleted();
              },
              child: Text(l10n.audioRemoveDownload),
            ),
          ],
        ),
        DownloadStatus.downloading => Semantics(
          liveRegion: true,
          label: l10n.audioDownloading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.progress == null
                    ? l10n.audioDownloading
                    : l10n.audioDownloadingPercent(
                        (state.progress! * 100).floor(),
                      ),
                style: caption,
              ),
              const SizedBox(height: LadSpace.xs),
              LinearProgressIndicator(value: state.progress),
            ],
          ),
        ),
        DownloadStatus.absent || DownloadStatus.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.status == DownloadStatus.failed
                  ? l10n.audioDownloadFailed
                  : l10n.audioNeedsNetwork,
              style: caption,
            ),
            const SizedBox(height: LadSpace.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.audioDownload),
              onPressed: () => downloads.download(
                track,
                ref.read(envProvider).audioUrl(track.storageKey),
              ),
            ),
          ],
        ),
      },
    );
  }
}

/// Bandeau brun-or : numéro, titre, version écoutée.
class _Banner extends StatelessWidget {
  const _Banner({required this.hymn, required this.track});

  final PublishedHymn hymn;
  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const ink = HeroCard.ink;
    return HeroCard(
      image: 'assets/images/banner_wheat_ears.jpg',
      minHeight: 0,
      padding: const EdgeInsets.all(LadSpace.xl),
      child: Semantics(
        container: true,
        header: true,
        label:
            'Cantique ${spokenNumber(hymn.numberLabel)}, ${hymn.title}. '
            '${mediaTypeName(track.mediaType)}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Overline(l10n.listening, color: ink.goldText),
            const SizedBox(height: LadSpace.sm),
            Text(
              hymn.numberLabel,
              style: LadTheme.textStyle(LadTypeScale.display, ink.goldText),
            ),
            const SizedBox(height: LadSpace.xs),
            Text(
              hymn.title,
              style: LadTheme.textStyle(LadTypeScale.title, ink.text),
            ),
            const SizedBox(height: LadSpace.sm),
            Text(
              mediaTypeName(track.mediaType),
              style: LadTheme.textStyle(
                LadTypeScale.label,
                ink.text.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// En bas, dans la zone de sécurité : curseur de position, durées, ±10 s et
/// lecture / pause.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.state,
    required this.track,
    required this.dragging,
    required this.onDrag,
    required this.onSeek,
    required this.onPlay,
    required this.onPause,
    required this.onRetry,
    required this.onSkip,
  });

  final PlaybackState state;
  final AudioTrack track;
  final Duration? dragging;
  final ValueChanged<Duration> onDrag;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onRetry;
  final ValueChanged<Duration> onSkip;

  static const _skip = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final total = state.duration ?? track.duration;
    final position = dragging ?? state.position;
    final ready =
        state.status != PlaybackStatus.loading &&
        state.status != PlaybackStatus.idle &&
        state.status != PlaybackStatus.error;
    final times = LadTheme.textStyle(
      LadTypeScale.caption,
      p.textSecondary,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(
          top: BorderSide(color: p.hairline, width: LadStroke.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LadSpace.lg,
            LadSpace.xs,
            LadSpace.lg,
            LadSpace.sm,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: state.status == PlaybackStatus.error
                  ? _PlaybackError(onRetry: onRetry)
                  : Column(
                      children: [
                        Slider(
                          semanticFormatterCallback: (v) =>
                              _spoken(Duration(milliseconds: v.round())),
                          value: total == null
                              ? 0
                              : position.inMilliseconds
                                    .clamp(0, total.inMilliseconds)
                                    .toDouble(),
                          max: total == null || total == Duration.zero
                              ? 1
                              : total.inMilliseconds.toDouble(),
                          onChanged: ready && total != null
                              ? (v) => onDrag(Duration(milliseconds: v.round()))
                              : null,
                          onChangeEnd: ready && total != null
                              ? (v) => onSeek(Duration(milliseconds: v.round()))
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LadSpace.lg,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ExcludeSemantics(
                                child: Text(_clock(position), style: times),
                              ),
                              ExcludeSemantics(
                                child: Text(
                                  total == null ? '–:––' : _clock(total),
                                  style: times,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: LadSpace.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: l10n.rewind10,
                              iconSize: 30,
                              color: p.text,
                              icon: const Icon(Icons.replay_10),
                              onPressed: ready ? () => onSkip(-_skip) : null,
                            ),
                            const SizedBox(width: LadSpace.lg),
                            _PlayButton(
                              playing: state.playing,
                              loading: !ready,
                              onPlay: onPlay,
                              onPause: onPause,
                            ),
                            const SizedBox(width: LadSpace.lg),
                            IconButton(
                              tooltip: l10n.forward10,
                              iconSize: 30,
                              color: p.text,
                              icon: const Icon(Icons.forward_10),
                              onPressed: ready ? () => onSkip(_skip) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// « 3:07 », ou « 1:02:07 » au-delà d'une heure.
  static String _clock(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60 % 60).toString();
    final ss = (s % 60).toString().padLeft(2, '0');
    return s >= 3600 ? '${s ~/ 3600}:${mm.padLeft(2, '0')}:$ss' : '$mm:$ss';
  }

  static String _spoken(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return [
      if (m > 0) '$m minute${m > 1 ? 's' : ''}',
      '$s seconde${s > 1 ? 's' : ''}',
    ].join(' ');
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.loading,
    required this.onPlay,
    required this.onPause,
  });

  final bool playing;
  final bool loading;
  final VoidCallback onPlay;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    return IconButton.filled(
      tooltip: loading
          ? l10n.audioLoading
          : playing
          ? l10n.pause
          : l10n.play,
      iconSize: 36,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(72),
        backgroundColor: p.goldText,
        foregroundColor: p.surface,
        disabledBackgroundColor: p.goldText,
        shape: const CircleBorder(),
      ),
      onPressed: loading ? null : (playing ? onPause : onPlay),
      icon: loading
          ? SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: LadStroke.accent,
                color: p.surface,
              ),
            )
          : Icon(playing ? Icons.pause : Icons.play_arrow),
    );
  }
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          const SizedBox(height: LadSpace.sm),
          Text(
            l10n.audioErrorTitle,
            textAlign: TextAlign.center,
            style: LadTheme.textStyle(LadTypeScale.listTitle, p.text),
          ),
          const SizedBox(height: LadSpace.xs),
          Text(
            l10n.audioErrorMessage,
            textAlign: TextAlign.center,
            style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
          ),
          const SizedBox(height: LadSpace.lg),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

/// Versions disponibles (mélodie, chorale, voix…), seulement s'il y en a
/// plusieurs.
class TrackChoice extends StatelessWidget {
  const TrackChoice({
    super.key,
    required this.tracks,
    required this.selected,
    required this.onSelected,
  });

  final List<AudioTrack> tracks;
  final AudioTrack selected;
  final ValueChanged<AudioTrack> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.audioVersion,
          style: LadTheme.textStyle(LadTypeScale.label, p.textSecondary),
        ),
        const SizedBox(height: LadSpace.sm),
        Wrap(
          spacing: LadSpace.sm,
          runSpacing: LadSpace.sm,
          children: [
            for (final track in tracks)
              ChoiceChip(
                label: Text(mediaTypeName(track.mediaType)),
                selected: track.id == selected.id,
                onSelected: (_) => onSelected(track),
              ),
          ],
        ),
      ],
    );
  }
}

/// Une section des paroles ; mise en avant quand elle est chantée, et
/// touchable pour y aller quand l'enregistrement la repère.
class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    super.key,
    required this.section,
    required this.fontSize,
    required this.current,
    this.onTap,
  });

  final HymnSection section;
  final double fontSize;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final block = Padding(
      padding: const EdgeInsets.all(LadSpace.lg),
      child: SectionBlock(section: section, fontSize: fontSize, showName: true),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: LadSpace.sm),
      child: Semantics(
        selected: current,
        button: onTap != null,
        hint: onTap == null
            ? null
            : l10n.goToSection(sectionName(section.type, section.number)),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : LadDurations.base,
          decoration: BoxDecoration(
            color: current ? p.goldPale : p.surface,
            borderRadius: BorderRadius.circular(LadRadius.md),
            border: Border.all(
              color: current ? p.goldLight : p.hairline,
              width: LadStroke.hairline,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: onTap == null
                ? block
                : InkWell(
                    borderRadius: BorderRadius.circular(LadRadius.md),
                    onTap: onTap,
                    child: block,
                  ),
          ),
        ),
      ),
    );
  }
}
