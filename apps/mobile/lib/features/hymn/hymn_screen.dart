import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/env.dart';
import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/catalog/sung_order.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../audio/audio_screen.dart';
import '../favorites/favorite_button.dart';
import 'hymn_actions.dart';
import 'share_hymn.dart';

/// Fiche cantique (F-HYM-001/002, T-010) : bandeau, onglets Paroles /
/// Détails / Médias / Similaires, actions principales en bas et les autres
/// dans la feuille « Actions ». Aucune information absente n'est affichée :
/// pas d'auteur « inconnu », pas d'onglet vide.
class HymnScreen extends ConsumerStatefulWidget {
  const HymnScreen({super.key, required this.hymnId});

  final String hymnId;

  @override
  ConsumerState<HymnScreen> createState() => _HymnScreenState();
}

class _HymnScreenState extends ConsumerState<HymnScreen> {
  String get hymnId => widget.hymnId;

  @override
  void initState() {
    super.initState();
    // « Reprendre votre lecture » (accueil) : sur l'appareil seulement.
    ref.read(readingHistoryRepositoryProvider).record(hymnId).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hymn = ref.watch(hymnProvider(hymnId));
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final loaded = hymn.value;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (loaded != null) ...[
            IconButton(
              tooltip: l10n.shareHymn,
              icon: const Icon(Icons.ios_share),
              onPressed: () => showShareHymn(context, loaded),
            ),
            IconButton(
              tooltip: l10n.hymnActions,
              icon: const Icon(Icons.more_vert),
              onPressed: () => showHymnActions(context, ref, loaded),
            ),
          ],
        ],
      ),
      body: hymn.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => MessageState(title: '$e'),
        data: (h) => h == null
            ? MessageState(
                title: l10n.hymnRemovedTitle,
                message: l10n.hymnRemovedMessage,
              )
            : HymnContent(
                hymn: h,
                fontSize: prefs.lyricsSize,
                sungOrderEnabled: prefs.sungOrder,
              ),
      ),
      bottomNavigationBar: loaded == null ? null : _ActionBar(hymn: loaded),
    );
  }
}

/// Bandeau brun-or : numéro, titre, premier vers, favori.
class _Banner extends StatelessWidget {
  const _Banner({required this.hymn});

  final PublishedHymn hymn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const ink = HeroCard.ink;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final opening = _openingLine(hymn);
    return HeroCard(
      image: 'assets/images/banner_wheat_ears.jpg',
      minHeight: 0,
      padding: EdgeInsets.fromLTRB(
        compact ? LadSpace.lg + 4 : LadSpace.xxl,
        LadSpace.sm,
        LadSpace.sm,
        compact ? LadSpace.lg + 4 : LadSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Overline(l10n.appTitle, color: ink.goldText)),
              FavoriteButton(hymnId: hymn.id, color: ink.text),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: LadSpace.md),
            child: Semantics(
              container: true,
              header: true,
              label:
                  'Cantique ${spokenNumber(hymn.numberLabel)}, ${hymn.title}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hymn.numberLabel,
                    style: LadTheme.textStyle(
                      LadTypeScale.display,
                      ink.goldText,
                    ),
                  ),
                  const SizedBox(height: LadSpace.xs),
                  Text(
                    hymn.title,
                    style: LadTheme.textStyle(LadTypeScale.title, ink.text),
                  ),
                ],
              ),
            ),
          ),
          if (opening != null) ...[
            const SizedBox(height: LadSpace.sm),
            Padding(
              padding: const EdgeInsets.only(right: LadSpace.md),
              child: ExcludeSemantics(
                child: Text(
                  '« $opening »',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LadTheme.textStyle(LadTypeScale.label, ink.text)
                      .copyWith(
                        fontFamily: LadFonts.lyrics,
                        fontStyle: FontStyle.italic,
                        color: ink.text.withValues(alpha: 0.88),
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Premier vers s'il ne répète pas le titre.
String? _openingLine(PublishedHymn hymn) {
  final first = hymn.sections.firstOrNull?.lines.firstOrNull?.text;
  return first != null && !first.startsWith(hymn.title) ? first : null;
}

/// Actions principales en bas de la fiche, comme une barre d'outils :
/// « Écouter » et « Chanter » seulement si un enregistrement le permet.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.hymn});

  final PublishedHymn hymn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final env = ref.watch(envProvider);
    Widget action(IconData icon, String label, String tooltip, String route) =>
        Expanded(
          child: Tooltip(
            message: tooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(LadRadius.md),
              onTap: () => context.push(route),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: LadTouchTarget.min + LadSpace.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: p.goldText),
                    const SizedBox(height: LadSpace.xxs),
                    Text(
                      label,
                      style: LadTheme.textStyle(LadTypeScale.caption, p.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(
          top: BorderSide(color: p.hairline, width: LadStroke.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LadSpace.sm,
            vertical: LadSpace.xs,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Row(
                children: [
                  action(
                    Icons.chrome_reader_mode_outlined,
                    l10n.read,
                    l10n.readingMode,
                    '/lecture/${hymn.id}',
                  ),
                  if (canListen(env, hymn))
                    action(
                      Icons.headphones_outlined,
                      l10n.listen,
                      l10n.listenTooltip,
                      '/ecoute/${hymn.id}',
                    ),
                  if (canKaraoke(env, hymn))
                    action(
                      Icons.mic_none,
                      l10n.sing,
                      l10n.karaokeTooltip,
                      '/karaoke/${hymn.id}',
                    ),
                  action(
                    Icons.cast,
                    l10n.project,
                    l10n.project,
                    '/projection?cantique=${hymn.id}',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Tab { lyrics, details, media, similar }

/// Contenu de la fiche : bandeau, onglets, puis l'onglet choisi. Les onglets
/// Médias et Similaires n'existent que s'ils ont un contenu.
class HymnContent extends ConsumerWidget {
  const HymnContent({
    super.key,
    required this.hymn,
    required this.fontSize,
    required this.sungOrderEnabled,
    this.maxWidth = 760,
  });

  final PublishedHymn hymn;
  final double fontSize;
  final bool sungOrderEnabled;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final tabs = [
      _Tab.lyrics,
      _Tab.details,
      if (canListen(ref.watch(envProvider), hymn)) _Tab.media,
      if (hymn.relations.isNotEmpty) _Tab.similar,
    ];
    String name(_Tab tab) => switch (tab) {
      _Tab.lyrics => l10n.tabLyrics,
      _Tab.details => l10n.tabDetails,
      _Tab.media => l10n.tabMedia,
      _Tab.similar => l10n.tabSimilar,
    };

    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return SelectionArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? LadSpace.lg : LadSpace.xl,
                LadSpace.sm,
                compact ? LadSpace.lg : LadSpace.xl,
                LadSpace.huge,
              ),
              children: [
                ReadableWidth(
                  maxWidth: maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Banner(hymn: hymn),
                      const SizedBox(height: LadSpace.lg),
                      PillTabBar(
                        padding: const EdgeInsets.only(bottom: LadSpace.md),
                        tabs: [for (final t in tabs) name(t)],
                      ),
                      ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) =>
                            switch (tabs[controller.index]) {
                              _Tab.lyrics => _Lyrics(
                                hymn: hymn,
                                fontSize: fontSize,
                                sungOrderEnabled: sungOrderEnabled,
                              ),
                              _Tab.details => _Details(hymn: hymn),
                              _Tab.media => _Media(hymn: hymn),
                              _Tab.similar => _Similar(hymn: hymn),
                            },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Carte ivoire commune aux onglets.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding:
          padding ?? EdgeInsets.all(compact ? LadSpace.lg + 4 : LadSpace.xl),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(LadRadius.lg),
        border: Border.all(color: p.hairline, width: LadStroke.hairline),
      ),
      child: child,
    );
  }
}

class _Lyrics extends StatelessWidget {
  const _Lyrics({
    required this.hymn,
    required this.fontSize,
    required this.sungOrderEnabled,
  });

  final PublishedHymn hymn;
  final double fontSize;
  final bool sungOrderEnabled;

  @override
  Widget build(BuildContext context) {
    final sections = sungOrderEnabled
        ? sungOrder(hymn.sections)
        : hymn.sections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: LadSpace.xl),
                SectionBlock(
                  section: sections[i],
                  fontSize: fontSize,
                  showName: sections.length > 1,
                ),
              ],
            ],
          ),
        ),
        for (final relation in hymn.relations)
          if (relation.type == RelationType.bisOf)
            _SameMelody(relatedId: relation.relatedHymnId),
      ],
    );
  }
}

/// Lien vers le cantique dont celui-ci reprend la mélodie (« bis »).
class _SameMelody extends ConsumerWidget {
  const _SameMelody({required this.relatedId});

  final String relatedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(hymnProvider(relatedId)).value;
    if (related == null) {
      return const SizedBox.shrink(); // cantique principal non publié
    }
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: LadSpace.lg),
      child: Center(
        child: TextButton.icon(
          icon: const Icon(Icons.music_note_outlined),
          label: Text(l10n.sameMelody(related.numberLabel)),
          onPressed: () => context.push('/cantique/${related.id}'),
        ),
      ),
    );
  }
}

/// Métadonnées connues : numéro, titre, structure, auteurs, références,
/// thèmes. Une ligne n'apparaît que si l'information existe.
class _Details extends StatelessWidget {
  const _Details({required this.hymn});

  final PublishedHymn hymn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final opening = _openingLine(hymn);
    final verses = hymn.sections
        .where((s) => s.type == SectionType.verse)
        .length;
    final hasRefrain = hymn.sections.any((s) => s.type == SectionType.refrain);
    final structure = [
      if (verses > 0) l10n.verseCount(verses),
      if (hasRefrain) l10n.withRefrain,
    ].join(' · ');
    String roleName(PersonRole role) => switch (role) {
      PersonRole.author => l10n.roleAuthor,
      PersonRole.composer => l10n.roleComposer,
      PersonRole.translator => l10n.roleTranslator,
      PersonRole.arranger => l10n.roleArranger,
    };
    final rows = <(String, String)>[
      (l10n.detailsNumber, hymn.numberLabel),
      (l10n.detailsTitle, hymn.title),
      if (opening != null) (l10n.detailsOpening, opening),
      if (structure.isNotEmpty) (l10n.detailsStructure, structure),
      for (final role in PersonRole.values)
        if (hymn.people.where((x) => x.role == role).toList() case final people
            when people.isNotEmpty)
          (roleName(role), people.map((x) => x.fullName).join(', ')),
      if (hymn.bibleReferences.isNotEmpty)
        (
          l10n.detailsReferences,
          hymn.bibleReferences.map((r) => r.displayText).join('\n'),
        ),
    ];
    return _Panel(
      padding: const EdgeInsets.symmetric(
        horizontal: LadSpace.lg,
        vertical: LadSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: LadSpace.md),
              decoration: i == 0
                  ? null
                  : BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: p.hairline,
                          width: LadStroke.hairline,
                        ),
                      ),
                    ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      rows[i].$1,
                      style: LadTheme.textStyle(
                        LadTypeScale.caption,
                        p.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: LadTheme.textStyle(LadTypeScale.label, p.text),
                    ),
                  ),
                ],
              ),
            ),
          if (hymn.themes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.only(top: LadSpace.md),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: p.hairline, width: LadStroke.hairline),
                ),
              ),
              child: Overline(l10n.detailsThemes),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: LadSpace.sm),
              child: Wrap(
                spacing: LadSpace.sm,
                runSpacing: LadSpace.sm,
                children: [for (final t in hymn.themes) Chip(label: Text(t))],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Enregistrements publiés : chaque version ouvre l'écoute ; karaoké si une
/// piste est synchronisée.
class _Media extends ConsumerWidget {
  const _Media({required this.hymn});

  final PublishedHymn hymn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    String? duration(Duration? d) => d == null
        ? null
        : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return _Panel(
      padding: const EdgeInsets.symmetric(vertical: LadSpace.sm),
      child: Column(
        children: [
          for (final track in hymn.audio)
            ListTile(
              leading: Icon(Icons.headphones_outlined, color: p.goldText),
              title: Text(mediaTypeName(track.mediaType)),
              subtitle: duration(track.duration) == null
                  ? null
                  : Text(duration(track.duration)!),
              trailing: Icon(Icons.play_circle_outline, color: p.goldText),
              onTap: () => context.push('/ecoute/${hymn.id}'),
            ),
          if (canKaraoke(ref.watch(envProvider), hymn))
            ListTile(
              leading: Icon(Icons.mic_none, color: p.goldText),
              title: Text(l10n.sing),
              subtitle: Text(l10n.singSubtitle),
              trailing: Icon(Icons.chevron_right, color: p.textSecondary),
              onTap: () => context.push('/karaoke/${hymn.id}'),
            ),
        ],
      ),
    );
  }
}

/// Cantiques liés (même mélodie, variante, « bis »…), publiés seulement.
class _Similar extends ConsumerWidget {
  const _Similar({required this.hymn});

  final PublishedHymn hymn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final byId = {
      for (final h
          in ref.watch(hymnsByNumberProvider).value ?? const <HymnSummary>[])
        h.id: h,
    };
    String reason(RelationType type) => switch (type) {
      RelationType.sameMelody => l10n.relationSameMelody,
      RelationType.variant => l10n.relationVariant,
      RelationType.bisOf => l10n.relationBisOf,
      RelationType.related => l10n.relationRelated,
    };
    final related = [
      for (final r in hymn.relations)
        if (byId[r.relatedHymnId] case final h?) (h, reason(r.type)),
    ];
    if (related.isEmpty) {
      return MessageState(title: l10n.noSimilarTitle);
    }
    return Column(
      children: [
        for (final (h, why) in related)
          Padding(
            padding: const EdgeInsets.only(bottom: LadSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: LadSpace.xs,
                    bottom: LadSpace.xs,
                  ),
                  child: Overline(why),
                ),
                HymnListTile(
                  hymn: h,
                  margin: EdgeInsets.zero,
                  onTap: () => context.push('/cantique/${h.id}'),
                  trailing: FavoriteButton(hymnId: h.id),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
