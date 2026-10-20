import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/state.dart';
import '../../core/catalog/catalog_models.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/catalog/sung_order.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorite_button.dart';
import '../hymn/hymn_screen.dart';

/// Mode lecture : texte seul, largeur de lecture limitée, taille réglable,
/// cantique précédent/suivant (glissement ou boutons), écran maintenu
/// allumé. Option « couplet par couplet » : une section à la fois.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.hymnId});

  final String hymnId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  PageController? _pages;
  int? _index;

  /// Section affichée en mode « couplet par couplet » ; -1 : la dernière
  /// (retour depuis le cantique suivant).
  int _section = 0;

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

  void _turn(int delta) => delta > 0
      ? _pages!.nextPage(duration: LadDurations.base, curve: Curves.easeOut)
      : _pages!.previousPage(
          duration: LadDurations.base,
          curve: Curves.easeOut,
        );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hymns = ref.watch(hymnsByNumberProvider).value;
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final notifier = ref.read(preferencesProvider.notifier);
    if (hymns == null) return const Scaffold();
    _index ??= hymns
        .indexWhere((h) => h.id == widget.hymnId)
        .clamp(0, hymns.length - 1);
    _pages ??= PageController(initialPage: _index!);
    final current = hymns[_index!];

    // Sections du cantique affiché (mode « couplet par couplet »).
    final hymn = ref.watch(hymnProvider(current.id)).value;
    final sections = hymn == null
        ? const <HymnSection>[]
        : _sections(hymn, prefs);
    final byStanza = prefs.readerByStanza && sections.isNotEmpty;
    final section = _section < 0
        ? sections.length - 1
        : _section.clamp(0, sections.isEmpty ? 0 : sections.length - 1);

    void step(int delta) {
      if (!byStanza) return _turn(delta);
      final target = section + delta;
      if (target >= 0 && target < sections.length) {
        setState(() => _section = target);
      } else if (delta > 0 && _index! < hymns.length - 1) {
        _turn(1);
      } else if (delta < 0 && _index! > 0) {
        _turn(-1);
        _section = -1;
      }
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          FavoriteButton(hymnId: current.id),
          IconButton(
            tooltip: l10n.smallerText,
            icon: const Icon(Icons.text_decrease),
            onPressed: prefs.lyricsSize <= LadLyricsSize.min
                ? null
                : () => notifier.change(
                    (p) => p.copyWith(
                      lyricsSize: p.lyricsSize - LadLyricsSize.step,
                    ),
                  ),
          ),
          IconButton(
            tooltip: l10n.largerText,
            icon: const Icon(Icons.text_increase),
            onPressed: prefs.lyricsSize >= LadLyricsSize.max
                ? null
                : () => notifier.change(
                    (p) => p.copyWith(
                      lyricsSize: p.lyricsSize + LadLyricsSize.step,
                    ),
                  ),
          ),
          IconButton(
            tooltip: l10n.readingSettings,
            icon: const Icon(Icons.tune),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => const _ReaderSettings(),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: hymns.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          if (_section >= 0) _section = 0;
        }),
        itemBuilder: (context, i) => _ReaderPage(
          summary: hymns[i],
          prefs: prefs,
          section: i == _index && byStanza ? section : null,
        ),
      ),
      bottomNavigationBar: _Controls(
        previousTooltip: byStanza ? l10n.previousSection : l10n.previousHymn,
        nextTooltip: byStanza ? l10n.nextSection : l10n.nextHymn,
        progress: byStanza
            ? l10n.sectionProgress(section + 1, sections.length)
            : current.numberLabel,
        onPrevious: byStanza
            ? (section > 0 || _index! > 0 ? () => step(-1) : null)
            : (_index! > 0 ? () => step(-1) : null),
        onNext: byStanza
            ? (section < sections.length - 1 || _index! < hymns.length - 1
                  ? () => step(1)
                  : null)
            : (_index! < hymns.length - 1 ? () => step(1) : null),
      ),
    );
  }

  static List<HymnSection> _sections(
    PublishedHymn hymn,
    ReadingPreferences prefs,
  ) => prefs.sungOrder ? sungOrder(hymn.sections) : hymn.sections;
}

/// Précédent / Suivant bien espacés, en bas, dans la zone de sécurité.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.previousTooltip,
    required this.nextTooltip,
    required this.progress,
    required this.onPrevious,
    required this.onNext,
  });

  final String previousTooltip;
  final String nextTooltip;
  final String progress;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(
          top: BorderSide(color: p.hairline, width: LadStroke.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LadSpace.lg,
            vertical: LadSpace.sm,
          ),
          child: Row(
            children: [
              Tooltip(
                message: previousTooltip,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chevron_left),
                  label: Text(l10n.previous),
                  onPressed: onPrevious,
                ),
              ),
              Expanded(
                child: Text(
                  progress,
                  textAlign: TextAlign.center,
                  style: LadTheme.textStyle(
                    LadTypeScale.caption,
                    p.textSecondary,
                  ),
                ),
              ),
              Tooltip(
                message: nextTooltip,
                child: FilledButton.icon(
                  icon: const Icon(Icons.chevron_right),
                  iconAlignment: IconAlignment.end,
                  label: Text(l10n.next),
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderPage extends ConsumerWidget {
  const _ReaderPage({
    required this.summary,
    required this.prefs,
    required this.section,
  });

  final HymnSummary summary;
  final ReadingPreferences prefs;

  /// Section seule à afficher, ou `null` pour le cantique entier.
  final int? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hymn = ref.watch(hymnProvider(summary.id)).value;
    if (hymn == null) return const SizedBox.shrink();
    final header = _ReaderHeader(hymn: hymn);
    final index = section;
    if (index == null) {
      return HymnContent(
        hymn: hymn,
        fontSize: prefs.lyricsSize,
        sungOrderEnabled: prefs.sungOrder,
        header: header,
        maxWidth: 680,
        bottomPadding: LadSpace.xxl,
      );
    }
    final sections = _ReaderScreenState._sections(hymn, prefs);
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          LadSpace.lg,
          LadSpace.sm,
          LadSpace.lg,
          LadSpace.xxl,
        ),
        children: [
          ReadableWidth(
            maxWidth: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: LadSpace.xl),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : LadDurations.base,
                  child: SectionBlock(
                    key: ValueKey(index),
                    section: sections[index],
                    fontSize: prefs.lyricsSize,
                    showName: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête discret du mode lecture : numéro, titre serif, filet doré.
class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({required this.hymn});

  final PublishedHymn hymn;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Semantics(
      container: true,
      header: true,
      label: 'Cantique ${spokenNumber(hymn.numberLabel)}, ${hymn.title}',
      excludeSemantics: true,
      child: Column(
        children: [
          HymnNumberBadge(hymn.numberLabel),
          const SizedBox(height: LadSpace.md),
          Text(
            hymn.title,
            textAlign: TextAlign.center,
            style: LadTheme.textStyle(LadTypeScale.title, p.text),
          ),
          const SizedBox(height: LadSpace.md),
          const AccentRule(),
        ],
      ),
    );
  }
}

/// Réglages de lecture (taille, ordre chanté, couplet par couplet),
/// enregistrés sur l'appareil.
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
              title: Text(l10n.readerByStanza),
              subtitle: Text(l10n.readerByStanzaHint),
              value: prefs.readerByStanza,
              onChanged: (v) =>
                  notifier.change((p) => p.copyWith(readerByStanza: v)),
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
