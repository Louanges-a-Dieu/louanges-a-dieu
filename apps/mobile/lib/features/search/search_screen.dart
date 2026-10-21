import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/search/normalize.dart';
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

enum _Filter { all, titles, lyrics }

enum _Sort { relevance, number, title }

/// Résultats : nombre, filtres Tous / Titres / Paroles (avec leur nombre),
/// tri par pertinence, numéro ou titre. Une recherche par numéro n'a ni
/// filtre ni tri.
class _Results extends StatefulWidget {
  const _Results({required this.results});

  final SearchResults results;

  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results> {
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.relevance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final results = widget.results;
    void open(String id) => context.push('/cantique/$id');
    Widget tile(HymnSummary h, [String? excerpt]) => HymnListTile(
      hymn: h,
      excerpt: excerpt,
      onTap: () => open(h.id),
      trailing: FavoriteButton(hymnId: h.id),
    );

    final numbers = [?results.exactNumber, ...results.numberMatches];
    final byText = numbers.isEmpty;
    final titles = results.titleMatches;
    final lyrics = results.lyricMatches;
    // Un filtre devenu vide (nouvelle saisie) revient à « Tous ».
    final filter = switch (_filter) {
      _Filter.titles when titles.isEmpty => _Filter.all,
      _Filter.lyrics when lyrics.isEmpty => _Filter.all,
      final f => f,
    };
    final showTitles = filter != _Filter.lyrics;
    final showLyrics = filter != _Filter.titles;
    final total = byText
        ? (showTitles ? titles.length : 0) + (showLyrics ? lyrics.length : 0)
        : numbers.length;

    final List<Widget> rows;
    if (!byText) {
      rows = [
        ListSectionHeader(l10n.resultsNumber),
        for (final h in numbers) tile(h),
      ];
    } else if (_sort == _Sort.relevance) {
      rows = [
        if (showTitles && titles.isNotEmpty) ...[
          if (filter == _Filter.all) ListSectionHeader(l10n.resultsTitles),
          for (final h in titles) tile(h),
        ],
        if (showLyrics && lyrics.isNotEmpty) ...[
          if (filter == _Filter.all) ListSectionHeader(l10n.resultsLyrics),
          for (final m in lyrics) tile(m.hymn, m.excerpt),
        ],
      ];
    } else {
      final flat = [
        if (showTitles)
          for (final h in titles) (h, null as String?),
        if (showLyrics)
          for (final m in lyrics) (m.hymn, m.excerpt),
      ];
      flat.sort(
        (a, b) => _sort == _Sort.number
            ? a.$1.numberNumeric != b.$1.numberNumeric
                  ? a.$1.numberNumeric.compareTo(b.$1.numberNumeric)
                  : a.$1.numberLabel.compareTo(b.$1.numberLabel)
            : fold(a.$1.title).compareTo(fold(b.$1.title)),
      );
      rows = [for (final (h, excerpt) in flat) tile(h, excerpt)];
    }

    Widget chip(_Filter value, String label, int count) => ChoiceChip(
      label: Text('$label ($count)'),
      selected: filter == value,
      onSelected: count == 0 ? null : (_) => setState(() => _filter = value),
    );

    return ListView(
      children: [
        for (final row in [
          if (byText)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.lg,
                0,
                LadSpace.sm,
                LadSpace.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.resultCount(total),
                        style: LadTheme.textStyle(LadTypeScale.label, p.text),
                      ),
                    ),
                  ),
                  PopupMenuButton<_Sort>(
                    tooltip: l10n.sortBy,
                    onSelected: (v) => setState(() => _sort = v),
                    itemBuilder: (_) => [
                      for (final (value, label) in [
                        (_Sort.relevance, l10n.sortRelevance),
                        (_Sort.number, l10n.sortNumber),
                        (_Sort.title, l10n.sortTitle),
                      ])
                        CheckedPopupMenuItem(
                          value: value,
                          checked: value == _sort,
                          child: Text(label),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LadSpace.sm,
                        vertical: LadSpace.md,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            switch (_sort) {
                              _Sort.relevance => l10n.sortRelevance,
                              _Sort.number => l10n.sortNumber,
                              _Sort.title => l10n.sortTitle,
                            },
                            style: LadTheme.textStyle(
                              LadTypeScale.label,
                              p.goldText,
                            ),
                          ),
                          Icon(Icons.expand_more, color: p.goldText),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (byText)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                LadSpace.lg,
                0,
                LadSpace.lg,
                LadSpace.sm,
              ),
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: LadSpace.sm,
                runSpacing: LadSpace.sm,
                children: [
                  chip(
                    _Filter.all,
                    l10n.filterAll,
                    titles.length + lyrics.length,
                  ),
                  chip(_Filter.titles, l10n.filterTitles, titles.length),
                  chip(_Filter.lyrics, l10n.filterLyrics, lyrics.length),
                ],
              ),
            ),
          ...rows,
        ])
          ReadableWidth(child: row),
        const SizedBox(height: LadSpace.xxl),
      ],
    );
  }
}
