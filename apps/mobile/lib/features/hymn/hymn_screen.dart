import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/catalog/sung_order.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorite_button.dart';
import '../lists/lists.dart';

/// Fiche cantique (F-HYM-001/002, T-010). Aucune information absente n'est
/// affichée : pas d'auteur « inconnu », pas de référence vide.
class HymnScreen extends ConsumerWidget {
  const HymnScreen({super.key, required this.hymnId});

  final String hymnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hymn = ref.watch(hymnProvider(hymnId));
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (hymn.value != null) ...[
            FavoriteButton(hymnId: hymnId),
            IconButton(
              tooltip: l10n.addToList,
              icon: const Icon(Icons.playlist_add),
              onPressed: () => showAddToList(context, ref, hymnId),
            ),
            IconButton(
              tooltip: l10n.readingMode,
              icon: const Icon(Icons.chrome_reader_mode_outlined),
              onPressed: () => context.push('/lecture/$hymnId'),
            ),
            IconButton(
              tooltip: l10n.project,
              icon: const Icon(Icons.cast),
              onPressed: () => context.push('/projection?cantique=$hymnId'),
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
    );
  }
}

/// Contenu d'un cantique, partagé par la fiche et le mode lecture.
class HymnContent extends ConsumerWidget {
  const HymnContent({
    super.key,
    required this.hymn,
    required this.fontSize,
    required this.sungOrderEnabled,
  });

  final PublishedHymn hymn;
  final double fontSize;
  final bool sungOrderEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.lad;
    final sections = sungOrderEnabled
        ? sungOrder(hymn.sections)
        : hymn.sections;
    final bisOf = hymn.relations
        .where((r) => r.type == RelationType.bisOf)
        .toList();

    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          LadSpace.xl,
          LadSpace.md,
          LadSpace.xl,
          LadSpace.huge,
        ),
        children: [
          HymnHeader(hymn: hymn),
          const SizedBox(height: LadSpace.xxl),
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: LadSpace.xl),
            SectionBlock(section: sections[i], fontSize: fontSize),
          ],
          if (hymn.bibleReferences.isNotEmpty) ...[
            const SizedBox(height: LadSpace.xl),
            for (final r in hymn.bibleReferences)
              Text(
                '— ${r.displayText}',
                textAlign: TextAlign.right,
                style: LadTheme.textStyle(LadTypeScale.marker, p.textSecondary),
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
                children: [for (final t in hymn.themes) Chip(label: Text(t))],
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
      padding: const EdgeInsets.only(top: LadSpace.xl),
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
