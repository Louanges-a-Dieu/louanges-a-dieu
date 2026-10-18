import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/design_system/components.dart';
import '../../core/search/normalize.dart';
import '../../l10n/generated/app_localizations.dart';

/// Recueil (F-REC-001/002) : par numéro et par ordre alphabétique, hors connexion.
class HymnalScreen extends ConsumerWidget {
  const HymnalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navHymnal),
          actions: [
            IconButton(
              tooltip: l10n.goToNumber,
              icon: const Icon(Icons.dialpad),
              onPressed: () => _goToNumber(context, ref),
            ),
            IconButton(
              tooltip: l10n.searchAction,
              icon: const Icon(Icons.search),
              onPressed: () => context.push('/recherche'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.byNumber),
              Tab(text: l10n.alphabetical),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HymnList(provider: hymnsByNumberProvider, grouped: false),
            _HymnList(provider: hymnsAlphabeticalProvider, grouped: true),
          ],
        ),
      ),
    );
  }

  Future<void> _goToNumber(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _GoToNumberDialog(),
    );
    if (label == null || !context.mounted) return;
    final hymn = await ref.read(hymnByLabelProvider(label).future);
    if (!context.mounted) return;
    if (hymn == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.numberNotFound(label))));
    } else {
      await context.push('/cantique/${hymn.id}');
    }
  }
}

class _HymnList extends ConsumerWidget {
  const _HymnList({required this.provider, required this.grouped});

  final StreamProvider<List<HymnSummary>> provider;
  final bool grouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(provider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MessageState(title: '$e'),
          data: (hymns) {
            final items = <Object>[];
            String? letter;
            for (final h in hymns) {
              if (grouped) {
                final first = fold(h.title).isEmpty
                    ? '#'
                    : fold(h.title)[0].toUpperCase();
                if (first != letter) items.add(letter = first);
              }
              items.add(h);
            }
            return Scrollbar(
              interactive: true,
              thumbVisibility: true,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) => switch (items[i]) {
                  final String header => ListSectionHeader(header),
                  final HymnSummary h => HymnListTile(
                    hymn: h,
                    onTap: () => context.push('/cantique/${h.id}'),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            );
          },
        );
  }
}

/// Saisie d'un numéro : « 37 », « 37bis », « 37 bis ».
class _GoToNumberDialog extends StatefulWidget {
  const _GoToNumberDialog();

  @override
  State<_GoToNumberDialog> createState() => _GoToNumberDialogState();
}

class _GoToNumberDialogState extends State<_GoToNumberDialog> {
  final _controller = TextEditingController();
  static final _valid = RegExp(
    r'^(\d{1,4})\s*(bis|ter)?$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final m = _valid.firstMatch(_controller.text.trim());
    if (m == null) return;
    Navigator.of(context)
        .pop('${int.parse(m[1]!)}${m[2]?.toLowerCase() ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.goToNumber),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.go,
        decoration: InputDecoration(hintText: l10n.goToNumberHint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.go)),
      ],
    );
  }
}
