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
            const Align(
              alignment: Alignment.centerLeft,
              child: WheatEar(size: 32),
            ),
            const SizedBox(height: LadSpace.lg),
            Text(
              l10n.appTitle,
              style: LadTheme.textStyle(LadTypeScale.display, p.text),
            ),
            const SizedBox(height: LadSpace.xs),
            Text(
              l10n.homeSubtitle,
              style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
            ),
            const SizedBox(height: LadSpace.xxl),
            _SearchEntry(
              label: l10n.searchHint,
              onTap: () => context.push('/recherche'),
            ),
            if (daily != null) ...[
              const SizedBox(height: LadSpace.xxl),
              Overline(l10n.hymnOfTheDay),
              const SizedBox(height: LadSpace.sm),
              Semantics(
                button: true,
                label:
                    '${l10n.hymnOfTheDay} : ${spokenNumber(daily.numberLabel)}, ${daily.title}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(LadRadius.md),
                  onTap: () => context.push('/cantique/${daily.id}'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(LadSpace.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(LadRadius.md),
                      border: Border.all(
                        color: p.hairline,
                        width: LadStroke.hairline,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                daily.numberLabel,
                                style: LadTheme.textStyle(
                                  LadTypeScale.hymnNumber,
                                  p.goldText,
                                ),
                              ),
                              const SizedBox(height: LadSpace.sm),
                              Text(
                                daily.title,
                                style: LadTheme.textStyle(
                                  LadTypeScale.title,
                                  p.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_outward, color: p.textSecondary),
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
              icon: Icons.event_note_outlined,
              label: l10n.openWorship,
              onTap: () => context.go('/culte'),
            ),
            _Shortcut(
              icon: Icons.favorite_border,
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
        borderRadius: BorderRadius.circular(LadRadius.sm),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: LadTouchTarget.min + LadSpace.sm,
          ),
          padding: const EdgeInsets.symmetric(horizontal: LadSpace.lg),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(LadRadius.sm),
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
      contentPadding: EdgeInsets.zero,
      minTileHeight: LadTouchTarget.min + LadSpace.sm,
      leading: Icon(icon, color: p.gold),
      title: Text(label, style: LadTheme.textStyle(LadTypeScale.body, p.text)),
      trailing: Icon(Icons.arrow_forward, color: p.textSecondary),
      onTap: onTap,
    );
  }
}
