import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Navigation principale : cinq destinations dont chacune conserve son état.
/// Barre inférieure sur téléphone ; navigation latérale sur tablette large
/// (mêmes destinations, mêmes routes).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Largeur à partir de laquelle la navigation passe sur le côté.
  static const railBreakpoint = 840.0;

  /// Largeur à partir de laquelle la navigation latérale affiche ses libellés
  /// à côté des icônes.
  static const extendedBreakpoint = 1200.0;

  void _select(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  List<({IconData icon, IconData selected, String label})> _destinations(
    AppLocalizations l10n,
  ) => [
    (icon: Icons.home_outlined, selected: Icons.home, label: l10n.navHome),
    (
      icon: Icons.menu_book_outlined,
      selected: Icons.menu_book,
      label: l10n.navHymnal,
    ),
    (
      icon: Icons.favorite_border,
      selected: Icons.favorite,
      label: l10n.navFavorites,
    ),
    (
      icon: Icons.event_note_outlined,
      selected: Icons.event_note,
      label: l10n.navWorship,
    ),
    (icon: Icons.more_horiz, selected: Icons.more_horiz, label: l10n.navMore),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final destinations = _destinations(l10n);
    final width = MediaQuery.sizeOf(context).width;
    final hairline = BorderSide(color: p.hairline, width: LadStroke.hairline);

    if (width >= railBreakpoint) {
      final extended = width >= extendedBreakpoint;
      return Scaffold(
        body: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(border: Border(right: hairline)),
              child: NavigationRail(
                extended: extended,
                minWidth: LadSpace.huge + LadSpace.xxl,
                minExtendedWidth: 232,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _select,
                leading: _Brand(extended: extended, title: l10n.appTitle),
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: hairline)),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selected),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Marque en tête de la navigation latérale : épi et nom du recueil, séparés
/// des destinations par un filet fin.
class _Brand extends StatelessWidget {
  const _Brand({required this.extended, required this.title});

  final bool extended;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LadSpace.md,
        LadSpace.xl,
        LadSpace.md,
        LadSpace.lg,
      ),
      child: Column(
        children: [
          WheatEar(size: extended ? 36 : 28),
          if (extended) ...[
            const SizedBox(height: LadSpace.sm),
            Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: LadTheme.textStyle(
                  LadTypeScale.cardTitle,
                  p.text,
                ).copyWith(letterSpacing: LadTypeScale.cardTitle.size * 0.1),
              ),
            ),
          ],
          const SizedBox(height: LadSpace.lg),
          SizedBox(
            width: extended ? 184 : LadSpace.xxxl,
            child: Divider(height: 1, color: p.hairline),
          ),
        ],
      ),
    );
  }
}
