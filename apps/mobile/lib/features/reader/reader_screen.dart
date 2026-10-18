import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../hymn/hymn_screen.dart';

/// Mode lecture : texte seul, taille réglable, cantique précédent/suivant par
/// glissement, écran maintenu allumé.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.hymnId});

  final String hymnId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  PageController? _pages;
  int? _index;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().ignore();
  }

  @override
  void dispose() {
    WakelockPlus.disable().ignore();
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hymns = ref.watch(hymnsByNumberProvider).value;
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    if (hymns == null) return const Scaffold();
    _index ??= hymns
        .indexWhere((h) => h.id == widget.hymnId)
        .clamp(0, hymns.length - 1);
    _pages ??= PageController(initialPage: _index!);
    final current = hymns[_index!];
    final isFavorite =
        ref.watch(favoriteIdsProvider).value?.contains(current.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: isFavorite ? l10n.removeFavorite : l10n.addFavorite,
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_outline,
              color: context.lad.gold,
            ),
            onPressed: () => ref
                .read(userDataRepositoryProvider)
                .setFavorite(current.id, isFavorite: !isFavorite),
          ),
          IconButton(
            tooltip: l10n.textSize,
            icon: const Icon(Icons.format_size),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: hymns.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) =>
                _ReaderPage(summary: hymns[i], prefs: prefs),
          ),
          // Commandes équivalentes au glissement (accessibilité).
          Positioned(
            left: 0,
            right: 0,
            bottom: LadSpace.md,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: l10n.previousHymn,
                  icon: Icon(
                    Icons.chevron_left,
                    color: context.lad.textSecondary,
                  ),
                  onPressed: () => _pages!.previousPage(
                    duration: LadDurations.base,
                    curve: Curves.easeOut,
                  ),
                ),
                IconButton(
                  tooltip: l10n.nextHymn,
                  icon: Icon(
                    Icons.chevron_right,
                    color: context.lad.textSecondary,
                  ),
                  onPressed: () => _pages!.nextPage(
                    duration: LadDurations.base,
                    curve: Curves.easeOut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ReaderSettings(),
    );
  }
}

class _ReaderPage extends ConsumerWidget {
  const _ReaderPage({required this.summary, required this.prefs});

  final HymnSummary summary;
  final ReadingPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hymn = ref.watch(hymnProvider(summary.id)).value;
    if (hymn == null) return const SizedBox.shrink();
    return HymnContent(
      hymn: hymn,
      fontSize: prefs.lyricsSize,
      sungOrderEnabled: prefs.sungOrder,
    );
  }
}

/// Réglages de lecture (taille, ordre chanté), enregistrés sur l'appareil.
class _ReaderSettings extends ConsumerWidget {
  const _ReaderSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final notifier = ref.read(preferencesProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LadSpace.xl,
          0,
          LadSpace.xl,
          LadSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.textSize),
            Slider(
              value: prefs.lyricsSize,
              min: LadLyricsSize.min,
              max: LadLyricsSize.max,
              divisions:
                  ((LadLyricsSize.max - LadLyricsSize.min) / LadLyricsSize.step)
                      .round(),
              label: prefs.lyricsSize.round().toString(),
              onChanged: (v) =>
                  notifier.change((p) => p.copyWith(lyricsSize: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sungOrderOption),
              value: prefs.sungOrder,
              onChanged: (v) =>
                  notifier.change((p) => p.copyWith(sungOrder: v)),
            ),
          ],
        ),
      ),
    );
  }
}
