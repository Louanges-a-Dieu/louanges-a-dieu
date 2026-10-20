import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Accueil (F-ACC-001) : héro, recherche immédiatement visible, cantique du
/// jour, raccourcis, reprise de lecture. Utilisable sans compte.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Largeur maximale du contenu sur tablette.
  static const maxWidth = 960.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final daily = ref.watch(hymnOfTheDayProvider);
    final recent = ref.watch(recentHymnsProvider).value ?? const [];
    final compact = MediaQuery.sizeOf(context).width < 600;
    final gutter = compact ? LadSpace.lg : LadSpace.xl;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: gutter,
            vertical: LadSpace.xl,
          ),
          children: [
            _Centered(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Téléphone : pas d'en-tête séparé, le héro porte le nom du
                  // recueil, pour que la recherche reste visible sans défiler.
                  if (!compact) ...[
                    PageHeader(eyebrow: l10n.homeEyebrow, title: l10n.appTitle),
                    const SizedBox(height: LadSpace.lg),
                  ],
                  _Hero(compact: compact),
                  const SizedBox(height: LadSpace.lg),
                  SearchField(
                    hint: l10n.searchHint,
                    onTap: () => context.push('/recherche'),
                  ),
                  if (daily != null) ...[
                    const SizedBox(height: LadSpace.xl),
                    _SectionHeading(
                      title: l10n.hymnOfTheDayTitle,
                      lead: l10n.hymnOfTheDayLead,
                    ),
                    const SizedBox(height: LadSpace.md),
                    _DailyCard(hymn: daily),
                  ],
                  const SizedBox(height: LadSpace.xl),
                  const _Shortcuts(),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: LadSpace.xl),
                    _SectionHeading(
                      title: l10n.recentTitle,
                      lead: l10n.recentLead,
                      trailing: Tooltip(
                        message: l10n.clearHistoryTooltip,
                        child: TextButton(
                          onPressed: () => ref
                              .read(readingHistoryRepositoryProvider)
                              .clear(),
                          child: Text(l10n.clearHistory),
                        ),
                      ),
                    ),
                    const SizedBox(height: LadSpace.sm),
                    for (final h in recent)
                      HymnListTile(
                        hymn: h,
                        onTap: () => context.push('/cantique/${h.id}'),
                      ),
                  ],
                  const SizedBox(height: LadSpace.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: HomeScreen.maxWidth),
      child: child,
    ),
  );
}

/// Carte héroïque : photo de blé au couchant, message éditorial. Courte sur
/// téléphone (nom du recueil en surtitre, sans texte d'accompagnement) pour
/// laisser la recherche visible sans défiler.
class _Hero extends StatelessWidget {
  const _Hero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const ink = HeroCard.ink;
    final display = LadTheme.textStyle(LadTypeScale.display, ink.text);
    return HeroCard(
      image: 'assets/images/hero_wheat_sunset.jpg',
      imageAlignment: Alignment.centerRight,
      minHeight: compact ? 0 : 260,
      padding: EdgeInsets.all(compact ? LadSpace.xl : LadSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Overline(
            compact ? l10n.appTitle : l10n.homeSubtitle,
            color: ink.goldText,
          ),
          const SizedBox(height: LadSpace.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              l10n.heroTitle,
              style: compact
                  ? display.copyWith(fontSize: LadTypeScale.display.size - 6)
                  : display,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: LadSpace.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                l10n.heroLead,
                style: LadTheme.textStyle(LadTypeScale.body, ink.text).copyWith(
                  fontFamily: LadFonts.lyrics,
                  fontStyle: FontStyle.italic,
                  color: ink.text.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.lead, this.trailing});

  final String title;
  final String? lead;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: LadTheme.textStyle(LadTypeScale.sectionTitle, p.text),
                ),
              ),
              if (lead != null)
                Text(
                  lead!,
                  style: LadTheme.textStyle(
                    LadTypeScale.caption,
                    p.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Cantique du jour : carte or pâle mise en avant, numéro en grand.
class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.hymn});

  final HymnSummary hymn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final opening =
        hymn.openingLine != null && !hymn.openingLine!.startsWith(hymn.title)
        ? hymn.openingLine
        : null;
    void open() => context.push('/cantique/${hymn.id}');
    return Semantics(
      button: true,
      label:
          '${l10n.hymnOfTheDay} : ${spokenNumber(hymn.numberLabel)}, ${hymn.title}',
      excludeSemantics: true,
      child: Material(
        color: p.goldPale,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LadRadius.lg),
          side: BorderSide(color: p.goldLight, width: LadStroke.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(LadSpace.lg + 2),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: LadSpace.huge),
                  child: Text(
                    hymn.numberLabel,
                    style: LadTheme.textStyle(LadTypeScale.display, p.goldText),
                  ),
                ),
                const SizedBox(width: LadSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hymn.title,
                        style: LadTheme.textStyle(
                          LadTypeScale.cardTitle,
                          p.text,
                        ),
                      ),
                      if (opening != null) ...[
                        const SizedBox(height: LadSpace.xs),
                        Text(
                          '« $opening »',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: LadTheme.textStyle(LadTypeScale.label, p.text)
                              .copyWith(
                                fontFamily: LadFonts.lyrics,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: LadSpace.md),
                IconButton.filled(
                  tooltip: l10n.openHymn,
                  onPressed: open,
                  style: IconButton.styleFrom(
                    backgroundColor: p.goldText,
                    foregroundColor: p.surface,
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quatre raccourcis vers des fonctions réelles.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      _Shortcut(
        icon: Icons.menu_book_outlined,
        label: l10n.openHymnal,
        hint: l10n.shortcutHymnalHint,
        onTap: () => context.go('/recueil'),
      ),
      _Shortcut(
        icon: Icons.favorite_border,
        label: l10n.openFavorites,
        hint: l10n.shortcutFavoritesHint,
        onTap: () => context.go('/favoris'),
      ),
      _Shortcut(
        icon: Icons.event_note_outlined,
        label: l10n.openWorship,
        hint: l10n.shortcutWorshipHint,
        onTap: () => context.go('/culte'),
      ),
      _Shortcut(
        icon: Icons.cast,
        label: l10n.projectLyrics,
        hint: l10n.shortcutProjectHint,
        onTap: () async {
          final hymnId = await context.push<String>('/choisir-cantique');
          if (hymnId != null && context.mounted) {
            await context.push('/projection?cantique=$hymnId');
          }
        },
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        const gap = LadSpace.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items) SizedBox(width: width, child: item),
          ],
        );
      },
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Semantics(
      button: true,
      label: '$label. $hint',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LadRadius.md),
          side: BorderSide(color: p.hairline, width: LadStroke.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(LadSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: p.gold),
                const SizedBox(height: LadSpace.md),
                Text(
                  label,
                  style: LadTheme.textStyle(LadTypeScale.listTitle, p.text),
                ),
                const SizedBox(height: LadSpace.xxs),
                Text(
                  hint,
                  style: LadTheme.textStyle(
                    LadTypeScale.caption,
                    p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
