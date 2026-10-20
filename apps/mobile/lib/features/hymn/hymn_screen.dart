import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/env.dart';
import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/catalog/sung_order.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../core/sharing/hymn_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../audio/audio_screen.dart';
import '../favorites/favorite_button.dart';
import '../lists/lists.dart';

/// Fiche cantique (F-HYM-001/002, T-010). Aucune information absente n'est
/// affichée : pas d'auteur « inconnu », pas de référence vide.
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

    return Scaffold(
      appBar: AppBar(),
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
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Banner(hymn: h),
                    const SizedBox(height: LadSpace.lg),
                    _Actions(hymn: h),
                  ],
                ),
              ),
      ),
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
    final firstLine = hymn.sections.firstOrNull?.lines.firstOrNull?.text;
    final opening = firstLine != null && !firstLine.startsWith(hymn.title)
        ? firstLine
        : null;
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

/// Actions réellement disponibles : « Écouter » seulement si le cantique a un
/// enregistrement publié et que l'hébergement des médias est configuré.
class _Actions extends ConsumerWidget {
  const _Actions({required this.hymn});

  final PublishedHymn hymn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget action(String tooltip, Widget button) =>
        Tooltip(message: tooltip, child: button);
    return Wrap(
      spacing: LadSpace.sm,
      runSpacing: LadSpace.sm,
      children: [
        action(
          l10n.readingMode,
          FilledButton.icon(
            icon: const Icon(Icons.chrome_reader_mode_outlined),
            label: Text(l10n.read),
            onPressed: () => context.push('/lecture/${hymn.id}'),
          ),
        ),
        if (canListen(ref.watch(envProvider), hymn))
          action(
            l10n.listenTooltip,
            OutlinedButton.icon(
              icon: const Icon(Icons.headphones_outlined),
              label: Text(l10n.listen),
              onPressed: () => context.push('/ecoute/${hymn.id}'),
            ),
          ),
        action(
          l10n.project,
          OutlinedButton.icon(
            icon: const Icon(Icons.cast),
            label: Text(l10n.project),
            onPressed: () => context.push('/projection?cantique=${hymn.id}'),
          ),
        ),
        action(
          l10n.shareHymn,
          OutlinedButton.icon(
            icon: const Icon(Icons.ios_share),
            label: Text(l10n.share),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: hymnShareText(hymn),
                subject: '${hymn.numberLabel} — ${hymn.title}',
              ),
            ),
          ),
        ),
        action(
          l10n.addToList,
          OutlinedButton.icon(
            icon: const Icon(Icons.playlist_add),
            label: Text(l10n.addToListShort),
            onPressed: () => showAddToList(context, ref, hymn.id),
          ),
        ),
      ],
    );
  }
}

/// Contenu d'un cantique, partagé par la fiche et le mode lecture : en-tête
/// ([header], par défaut numéro et titre), paroles sur une surface ivoire,
/// puis références, mélodie, auteurs et thèmes s'ils sont connus.
class HymnContent extends ConsumerWidget {
  const HymnContent({
    super.key,
    required this.hymn,
    required this.fontSize,
    required this.sungOrderEnabled,
    this.header,
    this.maxWidth = 760,
    this.bottomPadding = LadSpace.huge,
  });

  final PublishedHymn hymn;
  final double fontSize;
  final bool sungOrderEnabled;
  final Widget? header;
  final double maxWidth;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.lad;
    final sections = sungOrderEnabled
        ? sungOrder(hymn.sections)
        : hymn.sections;
    final bisOf = hymn.relations
        .where((r) => r.type == RelationType.bisOf)
        .toList();
    final compact = MediaQuery.sizeOf(context).width < 600;

    return SelectionArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          compact ? LadSpace.lg : LadSpace.xl,
          LadSpace.sm,
          compact ? LadSpace.lg : LadSpace.xl,
          bottomPadding,
        ),
        children: [
          ReadableWidth(
            maxWidth: maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header ?? HymnHeader(hymn: hymn),
                const SizedBox(height: LadSpace.lg),
                Container(
                  padding: EdgeInsets.all(
                    compact ? LadSpace.lg + 4 : LadSpace.xl,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(LadRadius.lg),
                    border: Border.all(
                      color: p.hairline,
                      width: LadStroke.hairline,
                    ),
                  ),
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
                if (hymn.bibleReferences.isNotEmpty) ...[
                  const SizedBox(height: LadSpace.lg),
                  for (final r in hymn.bibleReferences)
                    Text(
                      '— ${r.displayText}',
                      textAlign: TextAlign.right,
                      style: LadTheme.textStyle(
                        LadTypeScale.marker,
                        p.textSecondary,
                      ),
                    ),
                ],
                for (final relation in bisOf)
                  _SameMelody(relatedId: relation.relatedHymnId),
                if (hymn.people.isNotEmpty) ...[
                  const WheatDivider(),
                  for (final person in hymn.people)
                    Text(
                      person.fullName,
                      style: LadTheme.textStyle(
                        LadTypeScale.caption,
                        p.textSecondary,
                      ),
                    ),
                ],
                if (hymn.themes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: LadSpace.md),
                    child: Wrap(
                      spacing: LadSpace.sm,
                      children: [
                        for (final t in hymn.themes) Chip(label: Text(t)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
