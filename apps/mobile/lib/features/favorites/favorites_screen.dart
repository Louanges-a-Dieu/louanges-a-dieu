import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../lists/lists.dart';
import 'favorite_button.dart';

/// Onglet « Favoris » : favoris (sans compte, hors connexion) et listes (compte).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final count = ref.watch(favoriteIdsProvider).value?.length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: kToolbarHeight + LadSpace.md,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.favoritesTitle),
              if (count != null && count > 0)
                Text(
                  l10n.favoriteCount(count),
                  style: LadTheme.textStyle(
                    LadTypeScale.caption,
                    context.lad.textSecondary,
                  ),
                ),
            ],
          ),
          bottom: PillTabBar(tabs: [l10n.myFavorites, l10n.myLists]),
        ),
        body: const TabBarView(children: [_FavoriteList(), ListsTab()]),
      ),
    );
  }
}

class _FavoriteList extends ConsumerWidget {
  const _FavoriteList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ids = ref.watch(favoriteIdsProvider).value ?? const <String>{};
    final hymns = ref.watch(hymnsByNumberProvider).value ?? const [];
    final favorites = hymns.where((h) => ids.contains(h.id)).toList();
    if (favorites.isEmpty) {
      return MessageState(
        title: l10n.favoritesEmptyTitle,
        message: l10n.favoritesEmptyMessage,
        actionLabel: l10n.openHymnal,
        onAction: () => context.go('/recueil'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: LadSpace.xl),
      itemCount: favorites.length,
      itemBuilder: (context, i) => ReadableWidth(
        child: HymnListTile(
          hymn: favorites[i],
          onTap: () => context.push('/cantique/${favorites[i].id}'),
          trailing: FavoriteButton(hymnId: favorites[i].id),
        ),
      ),
    );
  }
}
