import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Accueil (F-ACC-001) : identité, recherche, cantique du jour, raccourcis.
/// Utilisable sans compte.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final daily = ref.watch(hymnOfTheDayProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: LadSpace.xl,
            vertical: LadSpace.xxl,
          ),
          children: [
            const Center(child: WheatEar(size: 44)),
            const SizedBox(height: LadSpace.lg),
            Text(
              l10n.appTitle,
              textAlign: TextAlign.center,
              style: LadTheme.textStyle(LadTypeScale.display, p.text),
            ),
            const SizedBox(height: LadSpace.xs),
            Text(
              l10n.homeSubtitle,
              textAlign: TextAlign.center,
              style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
            ),
            const SizedBox(height: LadSpace.xxl),
            _SearchEntry(
              label: l10n.searchHint,
              onTap: () => context.push('/recherche'),
            ),
            if (daily != null) ...[
              const WheatDivider(),
              Text(
                l10n.hymnOfTheDay.toUpperCase(),
                textAlign: TextAlign.center,
                style: LadTheme.textStyle(
                  LadTypeScale.caption,
                  p.textSecondary,
                ).copyWith(letterSpacing: 1.2),
              ),
              const SizedBox(height: LadSpace.sm),
              Semantics(
                button: true,
                label:
                    '${l10n.hymnOfTheDay} : ${spokenNumber(daily.numberLabel)}, ${daily.title}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(LadRadius.md),
                  onTap: () => context.push('/cantique/${daily.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(LadSpace.md),
                    child: Column(
                      children: [
                        Text(
                          daily.numberLabel,
                          style: LadTheme.textStyle(
                            LadTypeScale.hymnNumber,
                            p.goldText,
                          ),
                        ),
                        const SizedBox(height: LadSpace.xs),
                        Text(
                          daily.title,
                          textAlign: TextAlign.center,
                          style: LadTheme.textStyle(LadTypeScale.title, p.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const WheatDivider(),
            _Shortcut(
              icon: Icons.menu_book_outlined,
              label: l10n.openHymnal,
              onTap: () => context.go('/recueil'),
            ),
            _Shortcut(
              icon: Icons.star_outline,
              label: l10n.openFavorites,
              onTap: () => context.go('/favoris'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LadRadius.pill),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LadTouchTarget.min + LadSpace.sm,
          ),
          padding: const EdgeInsets.symmetric(horizontal: LadSpace.lg),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(LadRadius.pill),
            border: Border.all(color: p.hairline, width: LadStroke.hairline),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: p.textSecondary),
              const SizedBox(width: LadSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return ListTile(
      minTileHeight: LadTouchTarget.min + LadSpace.sm,
      leading: Icon(icon, color: p.gold),
      title: Text(label, style: LadTheme.textStyle(LadTypeScale.body, p.text)),
      trailing: Icon(Icons.chevron_right, color: p.textSecondary),
      onTap: onTap,
    );
  }
}
