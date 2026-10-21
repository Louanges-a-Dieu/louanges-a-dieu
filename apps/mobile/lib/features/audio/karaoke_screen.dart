import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/env.dart';
import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../projection/projection_screen.dart';
import 'audio_player.dart';
import 'audio_screen.dart';
import 'karaoke_projection.dart';

/// Karaoké (en plus de l'écoute) : sur une piste synchronisée ligne par
/// ligne, le vers chanté s'affiche en grand et se remplit au rythme du chant ;
/// le précédent et les suivants restent visibles, plus discrets. Fond sombre,
/// comme l'écran projeté. La version « Accompagnement » est choisie d'abord
/// quand elle est synchronisée.
class KaraokeScreen extends ConsumerWidget {
  const KaraokeScreen({super.key, required this.hymnId});

  final String hymnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final env = ref.watch(envProvider);
    final hymn = ref.watch(hymnProvider(hymnId));
    return Theme(
      data: LadTheme.projection,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.lad.background,
          appBar: AppBar(
            backgroundColor: context.lad.background,
            actions: [
              if (hymn.value case final h? when canListen(env, h))
                IconButton(
                  tooltip: l10n.listenNormally,
                  icon: const Icon(Icons.headphones_outlined),
                  onPressed: () => context.pushReplacement('/ecoute/$hymnId'),
                ),
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
              final h when !canKaraoke(env, h) => MessageState(
                title: l10n.karaokeUnavailableTitle,
                message: l10n.karaokeUnavailableMessage,
              ),
              final h => _Karaoke(hymn: h),
            },
          ),
        ),
      ),
    );
  }
}

/// Vers d'une piste synchronisée, dans l'ordre de l'enregistrement.
@immutable
final class KaraokeLine {
  const KaraokeLine({
    required this.text,
    required this.section,
    required this.start,
    required this.end,
  });

  final String text;
  final HymnSection section;
  final Duration start;
  final Duration end;
}

/// Vers chantés d'une piste (passages ligne par ligne seulement).
List<KaraokeLine> karaokeLines(PublishedHymn hymn, AudioTrack track) {
  final sections = {for (final s in hymn.sections) s.id: s};
  return [
    for (final segment in [
      ...track.segments,
    ]..sort((a, b) => a.order.compareTo(b.order)))
      if ((sections[segment.sectionId], segment.lineIndex) case (
        final section?,
        final line?,
      ))
        KaraokeLine(
          text: section.lines[line].text,
          section: section,
          start: segment.start,
          end: segment.end,
        ),
  ];
}

/// Vers en cours à [position], ou `null` (introduction, interlude, fin).
int? currentLine(List<KaraokeLine> lines, Duration position) {
  for (var i = 0; i < lines.length; i++) {
    if (position >= lines[i].start && position < lines[i].end) return i;
  }
  return null;
}

class _Karaoke extends ConsumerStatefulWidget {
  const _Karaoke({required this.hymn});

  final PublishedHymn hymn;

  @override
  ConsumerState<_Karaoke> createState() => _KaraokeState();
}

class _KaraokeState extends ConsumerState<_Karaoke> {
  late final HymnAudioPlayer _player = ref.read(audioPlayerProvider);
  late final List<AudioTrack> _tracks = [
    for (final t in widget.hymn.audio)
      if (t.hasLineCues) t,
  ];
  late AudioTrack _track = _tracks.firstWhere(
    (t) => t.mediaType == MediaType.accompaniment,
    orElse: () => _tracks.first,
  );
  late List<KaraokeLine> _lines = karaokeLines(widget.hymn, _track);
  Duration? _dragging;

  /// Affichage sur la TV (ou un autre écran) ; null s'il est arrêté.
  KaraokeCaster? _caster;
  StreamSubscription<int>? _screensSub;
  int _screens = 0;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    unawaited(_screensSub?.cancel());
    unawaited(_caster?.stop());
    _player.release(this);
    super.dispose();
  }

  /// Démarre le serveur local et montre l'adresse à ouvrir sur la TV.
  Future<void> _startTv() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    try {
      final host = await ref.read(projectionHostFactoryProvider)();
      if (!mounted) {
        await host.stop();
        return;
      }
      _screensSub = host.screenCountChanges.listen((count) {
        if (mounted) setState(() => _screens = count);
      });
      setState(() {
        _caster = KaraokeCaster(
          host: host,
          player: _player,
          hymn: widget.hymn,
          lines: _lines,
        );
        _screens = host.screens;
      });
      await _showAddress();
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.karaokeTvUnavailable)),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _showAddress() async {
    final caster = _caster;
    if (caster == null) return;
    final urls = await caster.host.screenUrls();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ScreenConnectSheet(urls: urls, tv: true),
    );
  }

  Future<void> _stopTv() async {
    final caster = _caster;
    final screens = _screensSub;
    setState(() {
      _caster = null;
      _screensSub = null;
      _screens = 0;
    });
    unawaited(screens?.cancel());
    await caster?.stop();
  }

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
      _lines = karaokeLines(widget.hymn, track);
    });
    _caster?.setLines(widget.hymn, _lines);
    _open();
  }

  @override
  Widget build(BuildContext context) {
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    return ValueListenableBuilder(
      valueListenable: _player.state,
      builder: (context, state, _) {
        final position = _dragging ?? state.position;
        return Column(
          children: [
            _TvBar(
              casting: _caster != null,
              starting: _starting,
              screens: _screens,
              onStart: _startTv,
              onAddress: _showAddress,
              onStop: _stopTv,
            ),
            if (_tracks.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: LadSpace.lg),
                child: TrackChoice(
                  tracks: _tracks,
                  selected: _track,
                  onSelected: _choose,
                ),
              ),
            Expanded(
              child: _Lyrics(
                hymn: widget.hymn,
                lines: _lines,
                position: position,
                fontSize: prefs.lyricsSize,
                onSeek: _player.seek,
              ),
            ),
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

/// Karaoké sur la TV : démarrer, adresse à ouvrir, écrans connectés, arrêt.
/// Le son reste sur le téléphone (ou une enceinte qui lui est reliée).
class _TvBar extends StatelessWidget {
  const _TvBar({
    required this.casting,
    required this.starting,
    required this.screens,
    required this.onStart,
    required this.onAddress,
    required this.onStop,
  });

  final bool casting;
  final bool starting;
  final int screens;
  final VoidCallback onStart;
  final VoidCallback onAddress;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LadSpace.lg,
        0,
        LadSpace.lg,
        LadSpace.sm,
      ),
      child: casting
          ? Row(
              children: [
                Icon(
                  screens > 0 ? Icons.cast_connected : Icons.cast,
                  color: screens > 0 ? p.success : p.goldText,
                ),
                const SizedBox(width: LadSpace.sm),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      screens > 0
                          ? l10n.screensConnected(screens)
                          : l10n.karaokeTvWaiting,
                      style: LadTheme.textStyle(LadTypeScale.label, p.text),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onAddress,
                  child: Text(l10n.karaokeTvAddress),
                ),
                TextButton(onPressed: onStop, child: Text(l10n.karaokeTvStop)),
              ],
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.tv),
                label: Text(l10n.karaokeOnTv),
                onPressed: starting ? null : onStart,
              ),
            ),
    );
  }
}

/// Le vers précédent, le vers chanté (en grand, rempli au rythme du chant)
/// et les deux suivants. Avant le premier vers : le titre et un compte à
/// rebours.
class _Lyrics extends StatelessWidget {
  const _Lyrics({
    required this.hymn,
    required this.lines,
    required this.position,
    required this.fontSize,
    required this.onSeek,
  });

  final PublishedHymn hymn;
  final List<KaraokeLine> lines;
  final Duration position;
  final double fontSize;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final current = currentLine(lines, position);
    // Entre deux vers (ou avant le premier) : le prochain vers à chanter.
    final upcoming = current ?? lines.indexWhere((l) => l.start > position);
    final big = (fontSize * 1.5).clamp(26.0, 48.0);
    final small = (fontSize * 1.05).clamp(18.0, 32.0);
    final dim = p.text.withValues(alpha: 0.45);

    Widget line(int i, {required double size, required Color color}) =>
        Semantics(
          button: true,
          hint: l10n.karaokeGoToLine,
          child: InkWell(
            borderRadius: BorderRadius.circular(LadRadius.md),
            onTap: () => onSeek(lines[i].start),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LadSpace.md,
                vertical: LadSpace.sm,
              ),
              child: Text(
                lines[i].text,
                textAlign: TextAlign.center,
                style: LadTheme.textStyle(
                  LadTypeScale.lyrics,
                  color,
                ).copyWith(fontSize: size),
              ),
            ),
          ),
        );

    final children = <Widget>[];
    if (current == null && upcoming == 0 || lines.isEmpty) {
      // Introduction : titre, puis le premier vers annoncé.
      final wait = lines.isEmpty ? null : lines.first.start - position;
      children.addAll([
        Text(
          hymn.numberLabel,
          style: LadTheme.textStyle(LadTypeScale.display, p.goldText),
        ),
        Text(
          hymn.title,
          textAlign: TextAlign.center,
          style: LadTheme.textStyle(LadTypeScale.title, p.text),
        ),
        const SizedBox(height: LadSpace.xl),
        if (wait != null && wait > Duration.zero)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.karaokeStartsIn((wait.inMilliseconds / 1000).ceil()),
              style: LadTheme.textStyle(LadTypeScale.label, p.textSecondary),
            ),
          ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: LadSpace.md),
          line(0, size: small, color: dim),
        ],
      ]);
    } else if (upcoming < 0) {
      // Après le dernier vers.
      children.addAll([
        const WheatEar(size: 36),
        const SizedBox(height: LadSpace.lg),
        line(lines.length - 1, size: small, color: dim),
      ]);
    } else {
      final i = upcoming;
      final section = lines[i].section;
      final previousSection = i > 0 ? lines[i - 1].section : null;
      // Pause instrumentale : compte à rebours jusqu'à la reprise du chant.
      final rest = current == null ? lines[i].start - position : Duration.zero;
      children.addAll([
        if (i > 0) line(i - 1, size: small, color: dim),
        const SizedBox(height: LadSpace.md),
        if (rest >= const Duration(seconds: 1)) ...[
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_note, color: p.goldText, size: 20),
                const SizedBox(width: LadSpace.xs),
                Text(
                  l10n.karaokeResumesIn((rest.inMilliseconds / 1000).ceil()),
                  style: LadTheme.textStyle(
                    LadTypeScale.label,
                    p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: LadSpace.md),
        ],
        if (section.id != previousSection?.id || i == 0)
          Overline(
            sectionName(section.type, section.number),
            color: p.goldText,
          ),
        _SungLine(
          text: lines[i].text,
          size: big,
          sung: current != null,
          // Entre deux vers : le prochain s'affiche, pas encore rempli.
          progress: current == null
              ? 0
              : (position - lines[i].start).inMilliseconds /
                    (lines[i].end - lines[i].start).inMilliseconds,
          onTap: () => onSeek(lines[i].start),
        ),
        const SizedBox(height: LadSpace.md),
        for (final next in [i + 1, i + 2])
          if (next < lines.length) line(next, size: small, color: dim),
      ]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LadSpace.lg),
      child: ReadableWidth(
        maxWidth: 760,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Vers chanté : or pour la partie déjà chantée, clair pour le reste. Un vers
/// qui tient sur plusieurs lignes se remplit ligne après ligne. Sans
/// remplissage progressif si l'utilisateur limite les animations.
class _SungLine extends StatelessWidget {
  const _SungLine({
    required this.text,
    required this.size,
    required this.sung,
    required this.progress,
    required this.onTap,
  });

  final String text;
  final double size;

  /// Faux pendant une pause : le vers est annoncé, pas encore chanté.
  final bool sung;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final style = LadTheme.textStyle(
      LadTypeScale.lyrics,
      p.text,
    ).copyWith(fontSize: size, fontWeight: FontWeight.w600);
    final still = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      selected: sung,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: LadSpace.sm),
          child: still
              ? Text(
                  text,
                  textAlign: TextAlign.center,
                  style: style.copyWith(color: sung ? p.goldLight : p.text),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final rows = _rows(
                      text,
                      style,
                      scaler,
                      constraints.maxWidth,
                    );
                    final total = rows.fold<double>(0, (t, r) => t + r.width);
                    var filled = progress.clamp(0.0, 1.0) * total;
                    return Column(
                      children: [
                        for (final row in rows)
                          _row(row, style, p, () {
                            final f = row.width == 0
                                ? 1.0
                                : (filled / row.width).clamp(0.0, 1.0);
                            filled -= row.width;
                            return f;
                          }()),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  static Widget _row(
    ({String text, double width}) row,
    TextStyle style,
    LadPalette p,
    double f,
  ) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (rect) => LinearGradient(
      colors: [p.goldLight, p.goldLight, p.text, p.text],
      stops: [0, f, f, 1],
    ).createShader(rect),
    child: Text(row.text, textAlign: TextAlign.center, style: style),
  );

  /// Découpe [text] en lignes telles qu'elles s'affichent sur [width].
  static List<({String text, double width})> _rows(
    String text,
    TextStyle style,
    TextScaler scaler,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final metrics = painter.computeLineMetrics();
    final rows = <({String text, double width})>[];
    var offset = 0;
    for (final line in metrics) {
      final range = painter.getLineBoundary(TextPosition(offset: offset));
      final end = range.end <= offset ? text.length : range.end;
      rows.add((text: text.substring(offset, end).trim(), width: line.width));
      offset = end;
      if (offset >= text.length) break;
    }
    painter.dispose();
    return rows.isEmpty ? [(text: text, width: 0)] : rows;
  }
}
