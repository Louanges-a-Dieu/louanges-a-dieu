import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Mode lecture : une strophe (couplet ou refrain) à la fois, le refrain
/// répété après chaque couplet (ordre chanté, ADR-009). Précédent /
/// Suivant (boutons, glissement, flèches du clavier) passent d'une strophe à
/// l'autre ; Cantique précédent / suivant changent de cantique. Taille
/// réglable, largeur de lecture limitée, écran maintenu allumé.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.hymnId});

  final String hymnId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int? _index;

  /// Strophe affichée dans le cantique courant.
  int _section = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().ignore();
  }

  @override
  void dispose() {
    WakelockPlus.disable().ignore();
    super.dispose();
  }

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
    final index = _index!;
    final current = hymns[index];

    final hymn = ref.watch(hymnProvider(current.id)).value;
    final sections = hymn == null
        ? const <HymnSection>[]
        : sungOrder(hymn.sections);
    final section = _section.clamp(
      0,
      sections.isEmpty ? 0 : sections.length - 1,
    );

    final VoidCallback? previousSection = section > 0
        ? () => setState(() => _section = section - 1)
        : null;
    final VoidCallback? nextSection = section < sections.length - 1
        ? () => setState(() => _section = section + 1)
        : null;
    VoidCallback? toHymn(int target) => target >= 0 && target < hymns.length
        ? () => setState(() {
            _index = target;
            _section = 0;
          })
        : null;

    final dark = switch (prefs.readerTheme) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => Theme.of(context).brightness == Brightness.dark,
    };
    void goTo(int target) => setState(() => _section = target);

    return Theme(
      data: dark ? LadTheme.dark : LadTheme.light,
      child: Builder(
        builder: (context) => _scaffold(
          context,
          l10n: l10n,
          current: current,
          hymn: hymn,
          sections: sections,
          section: section,
          prefs: prefs,
          previousSection: previousSection,
          nextSection: nextSection,
          previousHymn: toHymn(index - 1),
          nextHymn: toHymn(index + 1),
          actions: [
            FavoriteButton(hymnId: current.id),
            IconButton(
              tooltip: l10n.stanzaList,
              icon: const Icon(Icons.format_list_numbered),
              onPressed: sections.isEmpty
                  ? null
                  : () => _showStanzas(context, sections, section, goTo),
            ),
            IconButton(
              tooltip: l10n.textSize,
              icon: const Icon(Icons.format_size),
              onPressed: () => _showTextSize(context),
            ),
            IconButton(
              tooltip: dark ? l10n.readerLight : l10n.readerDark,
              icon: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
              onPressed: () => notifier.change(
                (p) => p.copyWith(
                  readerTheme: dark ? ThemeMode.light : ThemeMode.dark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scaffold(
    BuildContext context, {
    required AppLocalizations l10n,
    required HymnSummary current,
    required PublishedHymn? hymn,
    required List<HymnSection> sections,
    required int section,
    required ReadingPreferences prefs,
    required VoidCallback? previousSection,
    required VoidCallback? nextSection,
    required VoidCallback? previousHymn,
    required VoidCallback? nextHymn,
    required List<Widget> actions,
  }) {
    return Scaffold(
      appBar: AppBar(actions: actions),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): ?previousSection,
          const SingleActivator(LogicalKeyboardKey.arrowRight): ?nextSection,
        },
        child: Focus(
          autofocus: true,
          child: _SwipeDetector(
            onSwipeLeft: nextSection,
            onSwipeRight: previousSection,
            child: hymn == null
                ? const SizedBox.expand()
                : _ReaderPage(
                    hymn: hymn,
                    sections: sections,
                    section: section,
                    fontSize: prefs.lyricsSize,
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _Controls(
        progress: sections.isEmpty
            ? current.numberLabel
            : l10n.sectionProgress(section + 1, sections.length),
        onPreviousSection: previousSection,
        onNextSection: nextSection,
        onPreviousHymn: previousHymn,
        onNextHymn: nextHymn,
      ),
    );
  }

  /// Liste des strophes dans l'ordre chanté, la strophe affichée en évidence,
  /// et « Aller au refrain » (le prochain refrain, sinon le premier).
  void _showStanzas(
    BuildContext context,
    List<HymnSection> sections,
    int current,
    void Function(int) goTo,
  ) {
    final refrains = [
      for (var i = 0; i < sections.length; i++)
        if (sections[i].type == SectionType.refrain) i,
    ];
    final nextRefrain = refrains.isEmpty
        ? null
        : refrains.firstWhere((i) => i > current, orElse: () => refrains.first);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) {
        final l10n = AppLocalizations.of(sheet);
        final p = sheet.lad;
        void pick(int i) {
          Navigator.pop(sheet);
          goTo(i);
        }

        var verse = 0;
        final names = [
          for (final s in sections)
            s.type == SectionType.verse && s.number == null
                ? l10n.stanzaNumber(++verse)
                : sectionName(s.type, s.number),
        ];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListSectionHeader(l10n.stanzaList),
                for (var i = 0; i < sections.length; i++)
                  ListTile(
                    selected: i == current,
                    selectedTileColor: p.surfaceWarm,
                    selectedColor: p.goldText,
                    leading: Text(
                      '${i + 1}.',
                      style: LadTheme.textStyle(
                        LadTypeScale.label,
                        i == current ? p.goldText : p.textSecondary,
                      ),
                    ),
                    title: Text(names[i]),
                    subtitle: Text(
                      sections[i].lines.firstOrNull?.text ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => pick(i),
                  ),
                if (nextRefrain != null)
                  Padding(
                    padding: const EdgeInsets.all(LadSpace.lg),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.redo),
                      label: Text(l10n.goToRefrain),
                      onPressed: () => pick(nextRefrain),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Taille du texte : curseur, avec A− / A+ de part et d'autre.
  void _showTextSize(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Consumer(
        builder: (sheet, ref, _) {
          final l10n = AppLocalizations.of(sheet);
          final size =
              (ref.watch(preferencesProvider).value ??
                      const ReadingPreferences())
                  .lyricsSize;
          final notifier = ref.read(preferencesProvider.notifier);
          void set(double value) =>
              notifier.change((p) => p.copyWith(lyricsSize: value));
          const steps =
              (LadLyricsSize.max - LadLyricsSize.min) ~/ LadLyricsSize.step;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.lg,
                0,
                LadSpace.lg,
                LadSpace.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListSectionHeader(l10n.textSize),
                  Row(
                    children: [
                      IconButton(
                        tooltip: l10n.smallerText,
                        icon: const Icon(Icons.text_decrease),
                        onPressed: size <= LadLyricsSize.min
                            ? null
                            : () => set(size - LadLyricsSize.step),
                      ),
                      Expanded(
                        child: Slider(
                          min: LadLyricsSize.min,
                          max: LadLyricsSize.max,
                          divisions: steps,
                          value: size,
                          label: '${size.round()}',
                          semanticFormatterCallback: (v) =>
                              '${v.round()} points',
                          onChanged: set,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.largerText,
                        icon: const Icon(Icons.text_increase),
                        onPressed: size >= LadLyricsSize.max
                            ? null
                            : () => set(size + LadLyricsSize.step),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// En bas, dans la zone de sécurité, symboles seuls (nom en infobulle et
/// pour les lecteurs d'écran) : cantique précédent, strophe précédente,
/// position, strophe suivante, cantique suivant.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.progress,
    required this.onPreviousSection,
    required this.onNextSection,
    required this.onPreviousHymn,
    required this.onNextHymn,
  });

  final String progress;
  final VoidCallback? onPreviousSection;
  final VoidCallback? onNextSection;
  final VoidCallback? onPreviousHymn;
  final VoidCallback? onNextHymn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    const stanzaSize = Size.square(56);
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
          // Sur tablette, alignés sur la largeur du texte.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.previousHymn,
                    color: p.goldText,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: onPreviousHymn,
                  ),
                  const Spacer(),
                  IconButton.outlined(
                    tooltip: l10n.previousSection,
                    iconSize: 28,
                    style: IconButton.styleFrom(minimumSize: stanzaSize),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onPreviousSection,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 72),
                    child: Text(
                      progress,
                      textAlign: TextAlign.center,
                      style: LadTheme.textStyle(
                        LadTypeScale.caption,
                        p.textSecondary,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: l10n.nextSection,
                    iconSize: 28,
                    style: IconButton.styleFrom(
                      minimumSize: stanzaSize,
                      backgroundColor: p.goldText,
                      foregroundColor: p.surface,
                    ),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: onNextSection,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.nextHymn,
                    color: p.goldText,
                    icon: const Icon(Icons.skip_next),
                    onPressed: onNextHymn,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glissement horizontal rapide, lu sur les événements bruts : la sélection
/// de texte (appui long) et le défilement vertical gardent leurs gestes.
class _SwipeDetector extends StatefulWidget {
  const _SwipeDetector({
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.child,
  });

  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final Widget child;

  @override
  State<_SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<_SwipeDetector> {
  static const _minDistance = 60.0;
  static const _maxDuration = Duration(milliseconds: 450);

  Offset? _start;
  Duration? _startTime;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      _start = e.position;
      _startTime = e.timeStamp;
    },
    onPointerUp: (e) {
      final start = _start;
      final startTime = _startTime;
      _start = null;
      if (start == null || startTime == null) return;
      final d = e.position - start;
      if (e.timeStamp - startTime > _maxDuration ||
          d.dx.abs() < _minDistance ||
          d.dx.abs() < d.dy.abs() * 2) {
        return;
      }
      (d.dx < 0 ? widget.onSwipeLeft : widget.onSwipeRight)?.call();
    },
    onPointerCancel: (_) => _start = null,
    child: widget.child,
  );
}

class _ReaderPage extends StatelessWidget {
  const _ReaderPage({
    required this.hymn,
    required this.sections,
    required this.section,
    required this.fontSize,
  });

  final PublishedHymn hymn;
  final List<HymnSection> sections;
  final int section;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
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
                _ReaderHeader(hymn: hymn),
                const SizedBox(height: LadSpace.xl),
                if (sections.isNotEmpty)
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : LadDurations.base,
                    child: SectionBlock(
                      key: ValueKey('${hymn.id}/$section'),
                      section: sections[section],
                      fontSize: fontSize,
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
            // Plus grand que sur la fiche : le titre se lit de loin.
            style: LadTheme.textStyle(
              LadTypeScale.title,
              p.text,
            ).copyWith(fontSize: LadTypeScale.title.size + 6),
          ),
          const SizedBox(height: LadSpace.md),
          const AccentRule(),
        ],
      ),
    );
  }
}
