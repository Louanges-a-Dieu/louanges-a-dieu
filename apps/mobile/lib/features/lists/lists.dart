import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/account.dart';
import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/dialogs.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Onglet « Listes » (F-LST-001). Les listes sont liées au compte (Q-05).
class ListsTab extends ConsumerWidget {
  const ListsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(currentUserProvider).value == null) {
      return MessageState(
        title: l10n.listsNeedAccountTitle,
        message: l10n.listsNeedAccountMessage,
        actionLabel: l10n.signIn,
        onAction: () => context.push('/compte'),
      );
    }
    final lists = ref.watch(playlistsProvider).value ?? const [];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newList),
        onPressed: () => createListDialog(context, ref),
      ),
      body: lists.isEmpty
          ? MessageState(
              title: l10n.listsEmptyTitle,
              message: l10n.listsEmptyMessage,
            )
          : ListView(
              children: [
                for (final list in lists)
                  ListTile(
                    minTileHeight: LadTouchTarget.min + LadSpace.sm,
                    leading: Icon(Icons.queue_music, color: context.lad.gold),
                    title: Text(list.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/listes/${list.id}'),
                  ),
              ],
            ),
    );
  }
}

/// Demande un nom ; renvoie la liste créée (ou null si annulé).
Future<({String id, String name})?> createListDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final name = await _nameDialog(
    context,
    title: l10n.newList,
    action: l10n.create,
  );
  if (name == null) return null;
  final id = await ref.read(userDataRepositoryProvider).createPlaylist(name);
  return (id: id, name: name);
}

Future<String?> _nameDialog(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) => textInputDialog(
  context,
  title: title,
  label: AppLocalizations.of(context).listName,
  action: action,
  initial: initial,
);

/// Détail d'une liste : réordonnancement par glisser-déposer, ou par les
/// commandes « monter / descendre » (accessibilité).
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(userDataRepositoryProvider);
    final list = (ref.watch(playlistsProvider).value ?? const [])
        .where((p) => p.id == playlistId)
        .firstOrNull;
    final ids =
        ref.watch(playlistHymnIdsProvider(playlistId)).value ??
        const <String>[];
    final byId = {
      for (final h
          in ref.watch(hymnsByNumberProvider).value ?? const <HymnSummary>[])
        h.id: h,
    };
    final hymns = [for (final id in ids) ?byId[id]];

    if (list == null) return const Scaffold();

    Future<void> reorder(List<String> order) =>
        repo.setPlaylistHymns(playlistId, order);

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            tooltip: l10n.rename,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final name = await _nameDialog(
                context,
                title: l10n.rename,
                action: l10n.save,
                initial: list.name,
              );
              if (name != null) await repo.renamePlaylist(playlistId, name);
            },
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.deleteListTitle),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );
              if (ok ?? false) {
                await repo.deletePlaylist(playlistId);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: hymns.isEmpty
          ? MessageState(
              title: l10n.listEmptyTitle,
              message: l10n.listEmptyMessage,
            )
          : ReorderableListView.builder(
              itemCount: hymns.length,
              onReorderItem: (from, to) {
                final order = [...ids];
                order.insert(to, order.removeAt(from));
                reorder(order);
              },
              itemBuilder: (context, i) {
                final h = hymns[i];
                return Row(
                  key: ValueKey('${h.id}-$i'),
                  children: [
                    Expanded(
                      child: HymnListTile(
                        hymn: h,
                        onTap: () => context.push('/cantique/${h.id}'),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        final order = [...ids];
                        switch (action) {
                          case 'up' when i > 0:
                            order.insert(i - 1, order.removeAt(i));
                          case 'down' when i < order.length - 1:
                            order.insert(i + 1, order.removeAt(i));
                          case 'remove':
                            order.removeAt(i);
                        }
                        reorder(order);
                      },
                      itemBuilder: (_) => [
                        if (i > 0)
                          PopupMenuItem(value: 'up', child: Text(l10n.moveUp)),
                        if (i < hymns.length - 1)
                          PopupMenuItem(
                            value: 'down',
                            child: Text(l10n.moveDown),
                          ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(l10n.removeFromList),
                        ),
                      ],
                    ),
                    const SizedBox(width: LadSpace.xxl),
                  ],
                );
              },
            ),
    );
  }
}

/// Feuille « Ajouter à une liste » depuis la fiche d'un cantique.
Future<void> showAddToList(
  BuildContext context,
  WidgetRef ref,
  String hymnId,
) async {
  final l10n = AppLocalizations.of(context);
  if (ref.read(currentUserProvider).value == null) {
    await context.push('/compte');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final lists = ref.watch(playlistsProvider).value ?? const [];
        final repo = ref.read(userDataRepositoryProvider);
        // Récupérée avant la fermeture de la feuille (son contexte disparaît ensuite).
        final messenger = ScaffoldMessenger.of(context);
        Future<void> add(String id, String name) async {
          final current = await repo.playlistHymnIds(id);
          final already = current.contains(hymnId);
          if (!already) await repo.setPlaylistHymns(id, [...current, hymnId]);
          if (!sheetContext.mounted) return;
          Navigator.pop(sheetContext);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                already ? l10n.alreadyInList(name) : l10n.addedToList(name),
              ),
            ),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListSectionHeader(l10n.addToList),
              for (final list in lists)
                ListTile(
                  title: Text(list.name),
                  onTap: () => add(list.id, list.name),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.newList),
                onTap: () async {
                  final created = await createListDialog(context, ref);
                  if (created != null) await add(created.id, created.name);
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
