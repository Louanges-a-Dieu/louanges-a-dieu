import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/search/search_service.dart';
import '../../l10n/generated/app_localizations.dart';

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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: (v) => setState(() => _query = v.trim()),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: l10n.cancel,
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? MessageState(
              title: l10n.searchEmptyTitle,
              message: l10n.searchEmptyMessage,
            )
          : ref
                .watch(searchResultsProvider(_query))
                .when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => MessageState(title: '$e'),
                  data: (results) => results.isEmpty
                      ? MessageState(
                          title: l10n.noResultTitle,
                          message: l10n.noResultMessage,
                        )
                      : _Results(results: results),
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
        if (numbers.isNotEmpty) ...[
          ListSectionHeader(l10n.resultsNumber),
          for (final h in numbers)
            HymnListTile(hymn: h, onTap: () => open(h.id)),
        ],
        if (results.titleMatches.isNotEmpty) ...[
          ListSectionHeader(l10n.resultsTitles),
          for (final h in results.titleMatches)
            HymnListTile(hymn: h, onTap: () => open(h.id)),
        ],
        if (results.lyricMatches.isNotEmpty) ...[
          ListSectionHeader(l10n.resultsLyrics),
          for (final m in results.lyricMatches)
            HymnListTile(
              hymn: m.hymn,
              excerpt: m.excerpt,
              onTap: () => open(m.hymn.id),
            ),
        ],
        const SizedBox(height: LadSpace.xxl),
      ],
    );
  }
}
