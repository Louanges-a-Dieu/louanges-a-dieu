import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/account.dart';
import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/database/app_database.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/dialogs.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Icônes proposées pour une liste (planche 4) ; le nom est enregistré.
const listIcons = <String, IconData>{
  'heart': Icons.favorite_border,
  'prayer': Icons.volunteer_activism_outlined,
  'church': Icons.church_outlined,
  'book': Icons.menu_book_outlined,
  'music': Icons.music_note_outlined,
  'star': Icons.star_outline,
  'celebration': Icons.celebration_outlined,
};

String listColorName(AppLocalizations l10n, String color) => switch (color) {
  'red' => l10n.colorRed,
  'ochre' => l10n.colorOchre,
  'green' => l10n.colorGreen,
  'teal' => l10n.colorTeal,
  'blue' => l10n.colorBlue,
  'violet' => l10n.colorViolet,
  _ => l10n.colorGold,
};

/// Pastille d'une liste : icône blanche sur sa couleur (or par défaut).
class ListBadge extends StatelessWidget {
  const ListBadge({super.key, this.icon, this.color, this.size = 44});

  final String? icon;
  final String? color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: LadListColors.all[color] ?? LadListColors.all['gold'],
      borderRadius: BorderRadius.circular(LadRadius.md),
    ),
    child: Icon(
      listIcons[icon] ?? Icons.queue_music,
      color: Colors.white,
      size: size * 0.55,
    ),
  );
}

/// Onglet « Listes » (F-LST-001, planche 4) : favoris, puis les listes avec
/// leur pastille et leur nombre de cantiques. Liées au compte (Q-05).
class ListsTab extends ConsumerWidget {
  const ListsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    if (ref.watch(currentUserProvider).value == null) {
      return MessageState(
        title: l10n.listsNeedAccountTitle,
        message: l10n.listsNeedAccountMessage,
        actionLabel: l10n.signIn,
        onAction: () => context.push('/compte'),
      );
    }
    final lists = ref.watch(playlistsProvider).value ?? const [];
    final counts = ref.watch(playlistCountsProvider).value ?? const {};
    final favorites = ref.watch(favoriteIdsProvider).value?.length ?? 0;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newList),
        onPressed: () => createListDialog(context, ref),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: LadSpace.huge + LadSpace.xl),
        children: [
          ReadableWidth(
            child: Column(
              children: [
                ListTile(
                  minTileHeight: LadTouchTarget.min + LadSpace.md,
                  leading: const ListBadge(icon: 'heart', color: 'red'),
                  title: Text(l10n.myFavorites),
                  subtitle: Text(l10n.hymnCount(favorites)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      DefaultTabController.maybeOf(context)?.animateTo(0),
                ),
                if (lists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(LadSpace.xl),
                    child: Column(
                      children: [
                        Text(
                          l10n.listsEmptyTitle,
                          style: LadTheme.textStyle(
                            LadTypeScale.cardTitle,
                            p.text,
                          ),
                        ),
                        const SizedBox(height: LadSpace.sm),
                        Text(
                          l10n.listsEmptyMessage,
                          textAlign: TextAlign.center,
                          style: LadTheme.textStyle(
                            LadTypeScale.body,
                            p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final list in lists)
                  ListTile(
                    minTileHeight: LadTouchTarget.min + LadSpace.md,
                    leading: ListBadge(icon: list.icon, color: list.color),
                    title: Text(list.name),
                    subtitle: Text(l10n.hymnCount(counts[list.id] ?? 0)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/listes/${list.id}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Création d'une liste (nom, description, icône, couleur) ; renvoie la
/// liste créée (ou null si annulé).
Future<({String id, String name})?> createListDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final values = await showListEditor(context);
  if (values == null) return null;
  final id = await ref
      .read(userDataRepositoryProvider)
      .createPlaylist(
        values.name,
        description: values.description,
        icon: values.icon,
        color: values.color,
      );
  return (id: id, name: values.name);
}

typedef ListValues = ({
  String name,
  String? description,
  String? icon,
  String? color,
});

/// Formulaire d'une liste (planche 4, écran 4), en feuille.
Future<ListValues?> showListEditor(
  BuildContext context, {
  PlaylistRow? initial,
}) => showModalBottomSheet<ListValues>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _ListEditor(initial: initial),
);

class _ListEditor extends StatefulWidget {
  const _ListEditor({this.initial});

  final PlaylistRow? initial;

  @override
  State<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<_ListEditor> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late String? _icon = widget.initial?.icon;
  late String? _color = widget.initial?.color;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final description = _description.text.trim();
    Navigator.pop<ListValues>(context, (
      name: name,
      description: description.isEmpty ? null : description,
      icon: _icon,
      color: _color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final label = LadTheme.textStyle(LadTypeScale.label, p.textSecondary);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            LadSpace.xl,
            0,
            LadSpace.xl,
            LadSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null ? l10n.newList : l10n.editList,
                style: LadTheme.textStyle(LadTypeScale.headline, p.text),
              ),
              const SizedBox(height: LadSpace.lg),
              Center(
                child: ListBadge(icon: _icon, color: _color, size: 64),
              ),
              const SizedBox(height: LadSpace.lg),
              TextField(
                controller: _name,
                autofocus: widget.initial == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.listName),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: LadSpace.md),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.descriptionOptional,
                ),
              ),
              const SizedBox(height: LadSpace.lg),
              Text(l10n.icon, style: label),
              const SizedBox(height: LadSpace.sm),
              Wrap(
                spacing: LadSpace.sm,
                runSpacing: LadSpace.sm,
                children: [
                  for (final MapEntry(key: name, value: icon)
                      in listIcons.entries)
                    IconButton.outlined(
                      tooltip: listIconName(l10n, name),
                      isSelected: _icon == name,
                      icon: Icon(icon),
                      selectedIcon: Icon(icon, color: p.surface),
                      style: IconButton.styleFrom(
                        backgroundColor: _icon == name ? p.goldText : null,
                      ),
                      onPressed: () => setState(() => _icon = name),
                    ),
                ],
              ),
              const SizedBox(height: LadSpace.lg),
              Text(l10n.color, style: label),
              const SizedBox(height: LadSpace.sm),
              Wrap(
                spacing: LadSpace.md,
                runSpacing: LadSpace.sm,
                children: [
                  for (final MapEntry(key: name, value: color)
                      in LadListColors.all.entries)
                    Semantics(
                      button: true,
                      selected: (_color ?? 'gold') == name,
                      label: listColorName(l10n, name),
                      excludeSemantics: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = name),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (_color ?? 'gold') == name
                                  ? p.text
                                  : Colors.transparent,
                              width: LadStroke.accent + 1,
                            ),
                          ),
                          child: (_color ?? 'gold') == name
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: LadSpace.xl),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.initial == null ? l10n.create : l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String listIconName(AppLocalizations l10n, String icon) => switch (icon) {
  'heart' => l10n.iconHeart,
  'prayer' => l10n.iconPrayer,
  'church' => l10n.iconChurch,
  'book' => l10n.iconBook,
  'music' => l10n.iconMusic,
  'star' => l10n.iconStar,
  _ => l10n.iconCelebration,
};

/// Texte d'une liste à partager : nom, description, cantiques numérotés.
String listShareText(
  PlaylistRow list,
  List<HymnSummary> hymns,
  AppLocalizations l10n,
) => [
  list.name,
  if (list.description != null) list.description!,
  '',
  for (var i = 0; i < hymns.length; i++)
    '${i + 1}. ${hymns[i].numberLabel} — ${hymns[i].title}',
  '',
  l10n.sharedFrom,
].join('\n');

/// Détail d'une liste (planche 4, écran 6) : en-tête, cantiques numérotés
/// (glisser-déposer, ou « monter / descendre » pour l'accessibilité), lecture
/// à la suite, ajout de plusieurs cantiques, modification, partage.
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
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
            tooltip: l10n.addHymns,
            icon: const Icon(Icons.playlist_add),
            onPressed: () => context.push('/listes/$playlistId/ajouter'),
          ),
          IconButton(
            tooltip: l10n.editList,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final values = await showListEditor(context, initial: list);
              if (values == null) return;
              await repo.updatePlaylist(
                playlistId,
                name: values.name,
                description: Value(values.description),
                icon: Value(values.icon),
                color: Value(values.color),
              );
            },
          ),
          IconButton(
            tooltip: l10n.share,
            icon: const Icon(Icons.ios_share),
            onPressed: hymns.isEmpty
                ? null
                : () => SharePlus.instance.share(
                    ShareParams(
                      text: listShareText(list, hymns, l10n),
                      subject: list.name,
                    ),
                  ),
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDialog(
                context,
                title: l10n.deleteListTitle,
                action: l10n.delete,
                destructive: true,
              )) {
                await repo.deletePlaylist(playlistId);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ReadableWidth(
            child: ListTile(
              minTileHeight: LadTouchTarget.min + LadSpace.lg,
              leading: ListBadge(icon: list.icon, color: list.color),
              title: Text(
                l10n.hymnCount(hymns.length),
                style: LadTheme.textStyle(LadTypeScale.label, p.textSecondary),
              ),
              subtitle: list.description == null
                  ? null
                  : Text(list.description!),
            ),
          ),
          Expanded(
            child: hymns.isEmpty
                ? MessageState(
                    title: l10n.listEmptyTitle,
                    message: l10n.listEmptyMessage,
                    actionLabel: l10n.addHymns,
                    onAction: () => context.push('/listes/$playlistId/ajouter'),
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
                      return HymnListTile(
                        key: ValueKey('${h.id}-$i'),
                        hymn: h,
                        onTap: () => context.push('/cantique/${h.id}'),
                        // Espace à droite : poignée de déplacement (grands écrans).
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                  PopupMenuItem(
                                    value: 'up',
                                    child: Text(l10n.moveUp),
                                  ),
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
                        ),
                      );
                    },
                  ),
          ),
          if (hymns.isNotEmpty)
            SafeArea(
              top: false,
              child: ReadableWidth(
                child: Padding(
                  padding: const EdgeInsets.all(LadSpace.md),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.chrome_reader_mode_outlined),
                    label: Text(l10n.readList),
                    onPressed: () => context.push(
                      '/lecture/${hymns.first.id}?liste=$playlistId',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ajout de plusieurs cantiques à une liste (planche 4, écran 5) :
/// recherche, Tous / Favoris / Récents, cases à cocher.
class AddHymnsScreen extends ConsumerStatefulWidget {
  const AddHymnsScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  ConsumerState<AddHymnsScreen> createState() => _AddHymnsScreenState();
}

enum _Source { all, favorites, recent }

class _AddHymnsScreenState extends ConsumerState<AddHymnsScreen> {
  String _query = '';
  _Source _source = _Source.all;
  final _selected = <String>[];

  Future<void> _add() async {
    final repo = ref.read(userDataRepositoryProvider);
    final current = await repo.playlistHymnIds(widget.playlistId);
    await repo.setPlaylistHymns(widget.playlistId, [
      ...current,
      for (final id in _selected)
        if (!current.contains(id)) id,
    ]);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(hymnsByNumberProvider).value ?? const <HymnSummary>[];
    final inList = ref.watch(playlistHymnIdsProvider(widget.playlistId)).value;
    final favorites = ref.watch(favoriteIdsProvider).value ?? const {};
    final recent = ref.watch(recentHymnsProvider).value ?? const [];
    final results = _query.isEmpty
        ? null
        : ref.watch(searchResultsProvider(_query)).value;

    final List<HymnSummary> hymns;
    if (results != null) {
      final seen = <String>{};
      hymns = [
        for (final h in <HymnSummary>[
          ?results.exactNumber,
          ...results.numberMatches,
          ...results.titleMatches,
          ...results.lyricMatches.map((m) => m.hymn),
        ])
          if (seen.add(h.id)) h,
      ];
    } else {
      hymns = switch (_source) {
        _Source.all => all,
        _Source.favorites => [
          for (final h in all)
            if (favorites.contains(h.id)) h,
        ],
        _Source.recent => recent,
      };
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addHymns)),
      body: Column(
        children: [
          ReadableWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.md,
                LadSpace.sm,
                LadSpace.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: l10n.hymnalSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                  if (_query.isEmpty) ...[
                    const SizedBox(height: LadSpace.sm),
                    SegmentedButton<_Source>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: _Source.all,
                          label: Text(l10n.filterAll),
                        ),
                        ButtonSegment(
                          value: _Source.favorites,
                          label: Text(l10n.navFavorites),
                        ),
                        ButtonSegment(
                          value: _Source.recent,
                          label: Text(l10n.recent),
                        ),
                      ],
                      selected: {_source},
                      onSelectionChanged: (s) =>
                          setState(() => _source = s.first),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: hymns.isEmpty
                ? MessageState(title: l10n.noResultTitle)
                : ListView.builder(
                    itemCount: hymns.length,
                    itemBuilder: (context, i) {
                      final h = hymns[i];
                      final already = inList?.contains(h.id) ?? false;
                      return ReadableWidth(
                        child: CheckboxListTile(
                          value: already || _selected.contains(h.id),
                          onChanged: already
                              ? null
                              : (v) => setState(
                                  () => v!
                                      ? _selected.add(h.id)
                                      : _selected.remove(h.id),
                                ),
                          secondary: HymnNumberBadge(h.numberLabel),
                          title: Text(h.title),
                          subtitle: already
                              ? Text(l10n.alreadyInThisList)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: ReadableWidth(
              child: Padding(
                padding: const EdgeInsets.all(LadSpace.md),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _selected.isEmpty ? null : _add,
                  child: Text(l10n.addCount(_selected.length)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille « Ajouter à une liste » depuis la fiche d'un cantique (planche 3,
/// écran 12) : une case par liste (cochée si le cantique y est déjà),
/// nouvelle liste, puis validation.
Future<void> showAddToList(
  BuildContext context,
  WidgetRef ref,
  String hymnId,
) async {
  if (ref.read(currentUserProvider).value == null) {
    await context.push('/compte');
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final message = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AddToListSheet(hymnId: hymnId),
  );
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AddToListSheet extends ConsumerStatefulWidget {
  const _AddToListSheet({required this.hymnId});

  final String hymnId;

  @override
  ConsumerState<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends ConsumerState<_AddToListSheet> {
  /// Choix modifiés (liste → contient le cantique).
  final _changes = <String, bool>{};

  Future<void> _apply(List<PlaylistRow> lists) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(userDataRepositoryProvider);
    final names = {for (final l in lists) l.id: l.name};
    final added = <String>[];
    for (final MapEntry(key: id, value: include) in _changes.entries) {
      final current = await repo.playlistHymnIds(id);
      if (include == current.contains(widget.hymnId)) continue;
      await repo.setPlaylistHymns(
        id,
        include
            ? [...current, widget.hymnId]
            : [
                for (final h in current)
                  if (h != widget.hymnId) h,
              ],
      );
      if (include) added.add(names[id] ?? '');
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      added.length == 1
          ? l10n.addedToList(added.single)
          : added.length > 1
          ? l10n.addedToLists(added.length)
          : _changes.isEmpty
          ? null
          : l10n.listsUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final lists = ref.watch(playlistsProvider).value ?? const <PlaylistRow>[];
    final containing =
        ref.watch(playlistsContainingProvider(widget.hymnId)).value ??
        const <String>{};
    final hymn = ref.watch(hymnProvider(widget.hymnId)).value;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LadSpace.lg),
              child: Text(
                l10n.addToList,
                style: LadTheme.textStyle(LadTypeScale.sectionTitle, p.text),
              ),
            ),
            if (hymn != null)
              ListTile(
                leading: HymnNumberBadge(hymn.numberLabel),
                title: Text(hymn.title),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final list in lists)
                    CheckboxListTile(
                      secondary: ListBadge(
                        icon: list.icon,
                        color: list.color,
                        size: 36,
                      ),
                      title: Text(list.name),
                      value: _changes[list.id] ?? containing.contains(list.id),
                      onChanged: (v) => setState(() => _changes[list.id] = v!),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(l10n.newList),
                    onTap: () async {
                      final created = await createListDialog(context, ref);
                      if (created != null) {
                        setState(() => _changes[created.id] = true);
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(LadSpace.lg),
              child: FilledButton(
                onPressed: () => _apply(lists),
                child: Text(l10n.validate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
