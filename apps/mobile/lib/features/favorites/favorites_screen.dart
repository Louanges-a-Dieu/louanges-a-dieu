import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../l10n/generated/app_localizations.dart';
import '../lists/lists.dart';

/// Onglet « Favoris » : favoris (sans compte, hors connexion) et listes (compte).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navFavorites),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.myFavorites),
              Tab(text: l10n.myLists),
            ],
          ),
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
      );
    }
    return ListView.builder(
      itemCount: favorites.length,
      itemBuilder: (context, i) => HymnListTile(
        hymn: favorites[i],
        onTap: () => context.push('/cantique/${favorites[i].id}'),
      ),
    );
  }
}
