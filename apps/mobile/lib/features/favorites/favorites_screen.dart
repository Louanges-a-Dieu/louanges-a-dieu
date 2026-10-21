import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
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

/// Favoris par numéro (« Tous ») ou du plus récent au plus ancien
/// (planche 4, écran 1).
class _FavoriteList extends ConsumerStatefulWidget {
  const _FavoriteList();

  @override
  ConsumerState<_FavoriteList> createState() => _FavoriteListState();
}

class _FavoriteListState extends ConsumerState<_FavoriteList> {
  bool _recent = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hymns = ref.watch(hymnsByNumberProvider).value ?? const [];
    final byId = {for (final h in hymns) h.id: h};
    final List<HymnSummary> favorites;
    if (_recent) {
      final ids = ref.watch(recentFavoriteIdsProvider).value ?? const [];
      favorites = [for (final id in ids) ?byId[id]];
    } else {
      final ids = ref.watch(favoriteIdsProvider).value ?? const <String>{};
      favorites = hymns.where((h) => ids.contains(h.id)).toList();
    }
    if (favorites.isEmpty && !_recent) {
      return MessageState(
        title: l10n.favoritesEmptyTitle,
        message: l10n.favoritesEmptyMessage,
        actionLabel: l10n.openHymnal,
        onAction: () => context.go('/recueil'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: LadSpace.xl),
      itemCount: favorites.length + 1,
      itemBuilder: (context, i) => i == 0
          ? ReadableWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  LadSpace.lg,
                  LadSpace.sm,
                  LadSpace.lg,
                  LadSpace.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(l10n.byNumber)),
                      ButtonSegment(value: true, label: Text(l10n.recent)),
                    ],
                    selected: {_recent},
                    onSelectionChanged: (s) =>
                        setState(() => _recent = s.first),
                  ),
                ),
              ),
            )
          : ReadableWidth(
              child: HymnListTile(
                hymn: favorites[i - 1],
                onTap: () => context.push('/cantique/${favorites[i - 1].id}'),
                trailing: FavoriteButton(hymnId: favorites[i - 1].id),
              ),
            ),
    );
  }
}
