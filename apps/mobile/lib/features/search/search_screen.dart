import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/search/search_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorite_button.dart';

/// Recherche locale (F-SEA-001) : numéro, titre, premier vers, paroles — hors connexion.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  /// Derniers résultats affichés : conservés pendant le calcul des suivants,
  /// pour éviter un clignotement à chaque lettre.
  SearchResults? _shown;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      Duration(milliseconds: LadDurations.fast.inMilliseconds),
      () {
        if (mounted) setState(() => _query = value.trim());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = _query.isEmpty
        ? null
        : ref.watch(searchResultsProvider(_query));
    if (results?.value case final value?) _shown = value;

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          ReadableWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.lg,
                0,
                LadSpace.lg,
                LadSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    title: l10n.searchTitle,
                    subtitle: l10n.searchLead,
                  ),
                  const SizedBox(height: LadSpace.lg),
                  SearchField(
                    hint: l10n.searchFieldHint,
                    controller: _controller,
                    autofocus: true,
                    onChanged: _onChanged,
                    onSubmitted: (v) => setState(() => _query = v.trim()),
                    onClear: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: switch (results) {
              null => MessageState(
                title: l10n.searchEmptyTitle,
                message: l10n.searchEmptyMessage,
              ),
              AsyncError() => MessageState(
                title: l10n.searchErrorTitle,
                message: l10n.searchErrorMessage,
              ),
              AsyncValue(:final value) when value == null && _shown == null =>
                LoadingState(label: l10n.searching),
              _ when (results.value ?? _shown)!.isEmpty => MessageState(
                title: l10n.noResultTitle,
                message: l10n.noResultMessage,
              ),
              _ => _Results(results: results.value ?? _shown!),
            },
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void open(String id) => context.push('/cantique/$id');
    final numbers = [?results.exactNumber, ...results.numberMatches];
    return ListView(
      children: [
        for (final row in [
          if (numbers.isNotEmpty) ...[
            ListSectionHeader(l10n.resultsNumber),
            for (final h in numbers)
              HymnListTile(
                hymn: h,
                onTap: () => open(h.id),
                trailing: FavoriteButton(hymnId: h.id),
              ),
          ],
          if (results.titleMatches.isNotEmpty) ...[
            ListSectionHeader(l10n.resultsTitles),
            for (final h in results.titleMatches)
              HymnListTile(
                hymn: h,
                onTap: () => open(h.id),
                trailing: FavoriteButton(hymnId: h.id),
              ),
          ],
          if (results.lyricMatches.isNotEmpty) ...[
            ListSectionHeader(l10n.resultsLyrics),
            for (final m in results.lyricMatches)
              HymnListTile(
                hymn: m.hymn,
                excerpt: m.excerpt,
                onTap: () => open(m.hymn.id),
                trailing: FavoriteButton(hymnId: m.hymn.id),
              ),
          ],
        ])
          ReadableWidth(child: row),
        const SizedBox(height: LadSpace.xxl),
      ],
    );
  }
}
