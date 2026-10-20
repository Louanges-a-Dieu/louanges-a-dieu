import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/account.dart';
import '../../app/env.dart';
import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/database/app_database.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/dialogs.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/sync/user_sync.dart';
import '../../core/user_data/user_data_models.dart';
import '../../l10n/generated/app_localizations.dart';

/// Programmes de culte (F-WOR-001/002) : liés au compte (Q-05, Q-06).
class WorshipTab extends ConsumerWidget {
  const WorshipTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(currentUserProvider).value != null;
    final services =
        ref.watch(worshipServicesProvider).value ?? const <WorshipServiceRow>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navWorship)),
      floatingActionButton: signedIn
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(l10n.newProgram),
              onPressed: () async {
                final title = await textInputDialog(
                  context,
                  title: l10n.newProgram,
                  label: l10n.programTitle,
                  action: l10n.create,
                );
                if (title == null) return;
                final id = await ref
                    .read(userDataRepositoryProvider)
                    .createWorshipService(title);
                if (context.mounted) await context.push('/culte/$id');
              },
            )
          : null,
      body: !signedIn
          ? MessageState(
              title: l10n.worshipNeedAccountTitle,
              message: l10n.worshipNeedAccountMessage,
              actionLabel: l10n.signIn,
              onAction: () => context.push('/compte'),
            )
          : services.isEmpty
          ? MessageState(
              title: l10n.worshipEmptyTitle,
              message: l10n.worshipEmptyMessage,
            )
          : ListView(
              children: [
                for (final s in services.where((s) => s.status != 'archived'))
                  _ServiceTile(service: s),
                if (services.any((s) => s.status == 'archived')) ...[
                  ListSectionHeader(l10n.archivedSection),
                  for (final s in services.where((s) => s.status == 'archived'))
                    _ServiceTile(service: s),
                ],
              ],
            ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final WorshipServiceRow service;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: LadTouchTarget.min + LadSpace.md,
    leading: Icon(Icons.event_note_outlined, color: context.lad.gold),
    title: Text(service.title),
    subtitle: Text(
      '${formatServiceDate(context, service.serviceDate)} · '
      '${statusLabel(AppLocalizations.of(context), service.status)}',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push('/culte/${service.id}'),
  );
}

String statusLabel(AppLocalizations l10n, String status) => switch (status) {
  'published' => l10n.statusPublished,
  'archived' => l10n.statusArchived,
  _ => l10n.statusDraft,
};

String formatServiceDate(BuildContext context, String? isoDate) {
  final date = isoDate == null ? null : DateTime.tryParse(isoDate);
  return date == null
      ? AppLocalizations.of(context).noDate
      : MaterialLocalizations.of(context).formatFullDate(date);
}

/// Éditeur d'un programme : date, statut, éléments ordonnés, partage.
class WorshipEditorScreen extends ConsumerWidget {
  const WorshipEditorScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final repo = ref.read(userDataRepositoryProvider);
    final service =
        (ref.watch(worshipServicesProvider).value ??
                const <WorshipServiceRow>[])
            .where((s) => s.id == serviceId)
            .firstOrNull;
    final items =
        ref.watch(worshipItemsProvider(serviceId)).value ??
        const <WorshipServiceItemRow>[];
    final hymns = {
      for (final h
          in ref.watch(hymnsByNumberProvider).value ?? const <HymnSummary>[])
        h.id: h,
    };
    if (service == null) return const Scaffold();

    List<WorshipItemDto> dtos() => [
      for (final i in items)
        WorshipItemDto(
          id: i.id,
          hymnId: i.hymnId,
          label: i.label,
          notes: i.notes,
        ),
    ];
    Future<void> save(List<WorshipItemDto> next) =>
        repo.setWorshipServiceItems(serviceId, next);

    return Scaffold(
      appBar: AppBar(
        title: Text(service.title),
        actions: [
          IconButton(
            tooltip: l10n.project,
            icon: const Icon(Icons.cast),
            onPressed: () => context.push('/projection?programme=$serviceId'),
          ),
          IconButton(
            tooltip: l10n.share,
            icon: const Icon(Icons.ios_share),
            onPressed: () => shareProgram(context, ref, service),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'rename':
                  final title = await textInputDialog(
                    context,
                    title: l10n.rename,
                    label: l10n.programTitle,
                    action: l10n.save,
                    initial: service.title,
                  );
                  if (title != null) {
                    await repo.updateWorshipService(serviceId, title: title);
                  }
                case 'duplicate':
                  final id = await repo.duplicateWorshipService(
                    serviceId,
                    title: l10n.copyOf(service.title),
                  );
                  if (context.mounted) context.pushReplacement('/culte/$id');
                case 'archive':
                  await repo.updateWorshipService(
                    serviceId,
                    status: 'archived',
                  );
                case 'unarchive':
                  await repo.updateWorshipService(serviceId, status: 'draft');
                case 'delete':
                  if (await confirmDialog(
                    context,
                    title: l10n.deleteProgramTitle,
                    action: l10n.delete,
                    destructive: true,
                  )) {
                    await repo.deleteWorshipService(serviceId);
                    if (context.mounted) context.pop();
                  }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
              PopupMenuItem(value: 'duplicate', child: Text(l10n.duplicate)),
              if (service.status == 'archived')
                PopupMenuItem(value: 'unarchive', child: Text(l10n.unarchive))
              else
                PopupMenuItem(value: 'archive', child: Text(l10n.archive)),
              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: Icon(Icons.calendar_today_outlined, color: p.gold),
            title: Text(l10n.programDate),
            subtitle: Text(formatServiceDate(context, service.serviceDate)),
            onTap: () async {
              final initial =
                  DateTime.tryParse(service.serviceDate ?? '') ??
                  DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                await repo.updateWorshipService(
                  serviceId,
                  serviceDate: date.toIso8601String().substring(0, 10),
                );
              }
            },
          ),
          if (service.status == 'archived')
            ListTile(
              leading: Icon(Icons.archive_outlined, color: p.textSecondary),
              title: Text(l10n.archivedInfo),
            )
          else
            SwitchListTile(
              secondary: Icon(Icons.visibility_outlined, color: p.gold),
              title: Text(l10n.published),
              value: service.status == 'published',
              onChanged: (v) => repo.updateWorshipService(
                serviceId,
                status: v ? 'published' : 'draft',
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? MessageState(
                    title: l10n.programEmptyTitle,
                    message: l10n.programEmptyMessage,
                  )
                : ReorderableListView.builder(
                    itemCount: items.length,
                    onReorderItem: (from, to) {
                      final next = dtos();
                      next.insert(to, next.removeAt(from));
                      unawaited(save(next));
                    },
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final hymn = item.hymnId == null
                          ? null
                          : hymns[item.hymnId];
                      return _ItemRow(
                        key: ValueKey(item.id),
                        index: i,
                        count: items.length,
                        item: item,
                        hymn: hymn,
                        onAction: (action) async {
                          final next = dtos();
                          switch (action) {
                            case 'up':
                              next.insert(i - 1, next.removeAt(i));
                            case 'down':
                              next.insert(i + 1, next.removeAt(i));
                            case 'remove':
                              next.removeAt(i);
                            case 'note':
                              final note = await textInputDialog(
                                context,
                                title: l10n.editNote,
                                label: l10n.sectionNotes,
                                action: l10n.save,
                                initial: item.notes ?? '',
                                optional: true,
                              );
                              if (note == null) return;
                              next[i] = WorshipItemDto(
                                id: item.id,
                                hymnId: item.hymnId,
                                label: item.label,
                                notes: note.isEmpty ? null : note,
                              );
                          }
                          await save(next);
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(LadSpace.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.music_note_outlined),
                      label: Text(l10n.addHymn),
                      onPressed: () async {
                        final hymnId = await context.push<String>(
                          '/choisir-cantique',
                        );
                        if (hymnId == null) return;
                        await save([
                          ...dtos(),
                          WorshipItemDto(
                            id: repo.newItemId(),
                            hymnId: hymnId,
                            label: null,
                            notes: null,
                          ),
                        ]);
                      },
                    ),
                  ),
                  const SizedBox(width: LadSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.notes),
                      label: Text(l10n.addSection),
                      onPressed: () async {
                        final label = await textInputDialog(
                          context,
                          title: l10n.addSection,
                          label: l10n.sectionLabel,
                          action: l10n.create,
                        );
                        if (label == null) return;
                        await save([
                          ...dtos(),
                          WorshipItemDto(
                            id: repo.newItemId(),
                            hymnId: null,
                            label: label,
                            notes: null,
                          ),
                        ]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.index,
    required this.count,
    required this.item,
    required this.hymn,
    required this.onAction,
  });

  final int index;
  final int count;
  final WorshipServiceItemRow item;
  final HymnSummary? hymn;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final title = hymn?.title ?? item.label ?? l10n.hymnRemovedTitle;
    return ListTile(
      minTileHeight: LadTouchTarget.min + LadSpace.md,
      leading: SizedBox(
        width: LadSpace.huge,
        child: hymn == null
            ? Icon(Icons.notes, color: p.textSecondary)
            : Text(
                hymn!.numberLabel,
                style: LadTheme.textStyle(LadTypeScale.listNumber, p.goldText),
              ),
      ),
      title: Text(title),
      subtitle: item.notes == null ? null : Text(item.notes!),
      onTap: hymn == null ? null : () => context.push('/cantique/${hymn!.id}'),
      trailing: PopupMenuButton<String>(
        onSelected: onAction,
        itemBuilder: (_) => [
          if (index > 0) PopupMenuItem(value: 'up', child: Text(l10n.moveUp)),
          if (index < count - 1)
            PopupMenuItem(value: 'down', child: Text(l10n.moveDown)),
          PopupMenuItem(value: 'note', child: Text(l10n.editNote)),
          PopupMenuItem(value: 'remove', child: Text(l10n.removeFromList)),
        ],
      ),
    );
  }
}

/// Choix d'un cantique par la recherche ; renvoie son identifiant.
class HymnPickerScreen extends ConsumerStatefulWidget {
  const HymnPickerScreen({super.key});

  @override
  ConsumerState<HymnPickerScreen> createState() => _HymnPickerScreenState();
}

class _HymnPickerScreenState extends ConsumerState<HymnPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = _query.isEmpty
        ? null
        : ref.watch(searchResultsProvider(_query)).value;
    final hymns = <HymnSummary>[
      ?results?.exactNumber,
      ...?results?.numberMatches,
      ...?results?.titleMatches,
      ...?results?.lyricMatches.map((m) => m.hymn),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
      ),
      body: _query.isEmpty
          ? MessageState(
              title: l10n.chooseHymn,
              message: l10n.searchEmptyMessage,
            )
          : hymns.isEmpty && results != null
          ? MessageState(title: l10n.noResultTitle)
          : ListView(
              children: [
                for (final h in hymns)
                  HymnListTile(hymn: h, onTap: () => context.pop(h.id)),
              ],
            ),
    );
  }
}

/// Partage (F-WOR-002, T-007) : publie le programme, l'envoie au serveur, puis
/// obtient son lien public (toujours le même tant qu'il n'est pas désactivé).
Future<void> shareProgram(
  BuildContext context,
  WidgetRef ref,
  WorshipServiceRow service,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final links = ref.read(shareLinksProvider);
  if (links == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareUnavailable)));
    return;
  }
  final repo = ref.read(userDataRepositoryProvider);
  if (service.status != 'published') {
    await repo.updateWorshipService(service.id, status: 'published');
  }
  final outcome = await ref.read(syncRunnerProvider.notifier).syncNow();
  String? token;
  if (outcome is UserSyncDone) {
    try {
      token = await links.ensure(service.id);
    } on Object {
      token = null;
    }
  }
  if (token == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareNeedsNetwork)));
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Hauteur adaptée au contenu et défilement sur les petits écrans.
    isScrollControlled: true,
    builder: (_) => _ShareSheet(service: service, initialToken: token!),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.service, required this.initialToken});

  final WorshipServiceRow service;
  final String initialToken;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  late String? _token = widget.initialToken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final env = ref.read(envProvider);
    final links = ref.read(shareLinksProvider)!;
    final messenger = ScaffoldMessenger.of(context);
    final url = _token == null ? null : env.sharedProgramUrl(_token!);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LadSpace.xl,
          0,
          LadSpace.xl,
          LadSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.shareLinkTitle,
              style: LadTheme.textStyle(LadTypeScale.headline, p.text),
            ),
            const SizedBox(height: LadSpace.sm),
            Text(
              l10n.shareLinkInfo,
              style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
            ),
            const SizedBox(height: LadSpace.lg),
            if (url != null) ...[
              SelectableText(
                url,
                style: LadTheme.textStyle(LadTypeScale.label, p.goldText),
              ),
              const SizedBox(height: LadSpace.lg),
              FilledButton.icon(
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.share),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: '${widget.service.title}\n$url',
                    subject: widget.service.title,
                  ),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(l10n.copyLink),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.linkCopied)),
                  );
                },
              ),
              TextButton(
                onPressed: () async {
                  await links.revoke(widget.service.id);
                  setState(() => _token = null);
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.linkRevoked)),
                  );
                },
                child: Text(l10n.revokeLink),
              ),
            ] else
              FilledButton(
                onPressed: () async {
                  final token = await links.regenerate(widget.service.id);
                  setState(() => _token = token);
                },
                child: Text(l10n.regenerateLink),
              ),
          ],
        ),
      ),
    );
  }
}
