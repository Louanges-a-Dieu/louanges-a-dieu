import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/catalog/sung_order.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorite_button.dart';

/// Vrai si [hymn] a au moins une vidéo publiée. Sinon, aucun bouton
/// « Regarder ».
bool canWatch(PublishedHymn hymn) => hymn.videos.isNotEmpty;

/// Vérifie l'accès à Internet avant d'ouvrir le lecteur YouTube : sans
/// réseau, un message clair plutôt qu'une page d'erreur du lecteur.
final internetCheckProvider = Provider<Future<bool> Function()>(
  (_) => () async {
    try {
      final found = await InternetAddress.lookup('www.youtube-nocookie.com')
          .timeout(const Duration(seconds: 5));
      return found.isNotEmpty;
    } on Object {
      return false;
    }
  },
);

/// Nom d'une vidéo dans le choix de version : la version, numérotée si le
/// cantique en a plusieurs du même type (« Chorale », « Chorale 2 »).
String videoName(List<HymnVideo> videos, HymnVideo video) {
  final same = videos.where((v) => v.mediaType == video.mediaType).toList();
  final name = mediaTypeName(video.mediaType);
  return same.length < 2 ? name : '$name ${same.indexOf(video) + 1}';
}

/// Vidéo d'un cantique (migration 0026) : lecteur YouTube intégré en haut
/// (vidéo non répertoriée, mode confidentialité renforcée), paroles en
/// dessous, une strophe à la fois. Demande Internet ; la lecture s'arrête en
/// quittant l'écran (règles de YouTube : pas de lecture en arrière-plan).
class VideoScreen extends ConsumerWidget {
  const VideoScreen({super.key, required this.hymnId});

  final String hymnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hymn = ref.watch(hymnProvider(hymnId));
    return Scaffold(
      appBar: AppBar(actions: [FavoriteButton(hymnId: hymnId)]),
      body: hymn.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => MessageState(title: '$e'),
        data: (h) => switch (h) {
          null => MessageState(
            title: l10n.hymnRemovedTitle,
            message: l10n.hymnRemovedMessage,
          ),
          final h when !canWatch(h) => MessageState(
            title: l10n.noVideoTitle,
            message: l10n.noVideoMessage,
          ),
          final h => _Watching(hymn: h),
        },
      ),
    );
  }
}

class _Watching extends ConsumerStatefulWidget {
  const _Watching({required this.hymn});

  final PublishedHymn hymn;

  @override
  ConsumerState<_Watching> createState() => _WatchingState();
}

class _WatchingState extends ConsumerState<_Watching> {
  late HymnVideo _video = widget.hymn.videos.first;
  late final List<HymnSection> _sections = sungOrder(widget.hymn.sections);

  /// `null` pendant la vérification de la connexion.
  bool? _online;
  YoutubePlayerController? _controller;
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _online = null);
    final online = await ref.read(internetCheckProvider)();
    if (!mounted) return;
    setState(() {
      _online = online;
      if (online) {
        _controller ??= YoutubePlayerController.fromVideoId(
          videoId: _video.youtubeId,
          params: const YoutubePlayerParams(
            interfaceLanguage: 'fr',
            captionLanguage: 'fr',
            strictRelatedVideos: true,
          ),
        );
      }
    });
  }

  void _choose(HymnVideo video) {
    if (video.id == _video.id) return;
    setState(() => _video = video);
    _controller?.loadVideoById(videoId: video.youtubeId);
  }

  void _move(int delta) {
    final next = _section + delta;
    if (next < 0 || next >= _sections.length) return;
    setState(() => _section = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final hymn = widget.hymn;
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final compact = MediaQuery.sizeOf(context).width < 600;
    final controller = _controller;

    final Widget player = switch (_online) {
      null => const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      ),
      false => MessageState(
        title: l10n.videoOfflineTitle,
        message: l10n.videoOfflineMessage,
        actionLabel: l10n.retry,
        onAction: _connect,
      ),
      true => YoutubeValueBuilder(
        controller: controller!,
        builder: (context, value) => value.hasError
            ? _PlayerError(
                error: value.error,
                onRetry: () =>
                    controller.loadVideoById(videoId: _video.youtubeId),
              )
            : YoutubePlayer(controller: controller, backgroundColor: p.text),
      ),
    };

    final section = _sections[_section];
    return ListView(
      padding: const EdgeInsets.only(bottom: LadSpace.huge),
      children: [
        ReadableWidth(maxWidth: 960, child: player),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? LadSpace.lg : LadSpace.xl,
            LadSpace.lg,
            compact ? LadSpace.lg : LadSpace.xl,
            0,
          ),
          child: ReadableWidth(
            maxWidth: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${hymn.numberLabel} — ${hymn.title}',
                  style: LadTheme.textStyle(LadTypeScale.sectionTitle, p.text),
                ),
                if (_video.title case final title?) ...[
                  const SizedBox(height: LadSpace.xxs),
                  Text(
                    title,
                    style: LadTheme.textStyle(
                      LadTypeScale.caption,
                      p.textSecondary,
                    ),
                  ),
                ],
                if (hymn.videos.length > 1) ...[
                  const SizedBox(height: LadSpace.lg),
                  Text(
                    l10n.videoVersion,
                    style: LadTheme.textStyle(
                      LadTypeScale.label,
                      p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: LadSpace.sm),
                  Wrap(
                    spacing: LadSpace.sm,
                    runSpacing: LadSpace.sm,
                    children: [
                      for (final video in hymn.videos)
                        ChoiceChip(
                          label: Text(videoName(hymn.videos, video)),
                          selected: video.id == _video.id,
                          onSelected: (_) => _choose(video),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: LadSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.lyricsHeading,
                          style: LadTheme.textStyle(
                            LadTypeScale.sectionTitle,
                            p.text,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.previousSection,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _section > 0 ? () => _move(-1) : null,
                    ),
                    Text(
                      l10n.sectionProgress(_section + 1, _sections.length),
                      style: LadTheme.textStyle(
                        LadTypeScale.caption,
                        p.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.nextSection,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _section < _sections.length - 1
                          ? () => _move(1)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: LadSpace.sm),
                // Glisser vers la gauche ou la droite change de strophe.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    final speed = details.primaryVelocity ?? 0;
                    if (speed < -200) _move(1);
                    if (speed > 200) _move(-1);
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(LadRadius.md),
                      border: Border.all(
                        color: p.hairline,
                        width: LadStroke.hairline,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(LadSpace.lg),
                      child: SectionBlock(
                        key: ValueKey(_section),
                        section: section,
                        fontSize: prefs.lyricsSize,
                        showName: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Erreur du lecteur YouTube, expliquée en français.
class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.error, required this.onRetry});

  final YoutubeError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (message, retry) = switch (error) {
      YoutubeError.notEmbeddable ||
      YoutubeError.sameAsNotEmbeddable ||
      YoutubeError.sameAsNotEmbeddable2 => (l10n.videoNotEmbeddable, false),
      YoutubeError.videoNotFound ||
      YoutubeError.cannotFindVideo => (l10n.videoNotFound, false),
      _ => (l10n.videoError, true),
    };
    return MessageState(
      title: l10n.videoUnavailableTitle,
      message: message,
      actionLabel: retry ? l10n.retry : null,
      onAction: retry ? onRetry : null,
    );
  }
}
