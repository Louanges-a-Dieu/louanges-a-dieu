import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/catalog/sung_order.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../favorites/favorite_button.dart';

/// Mode lecture : une strophe (couplet ou refrain) à la fois. Précédent /
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
        : _sections(hymn, prefs);
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
        onPreviousHymn: toHymn(index - 1),
        onNextHymn: toHymn(index + 1),
      ),
    );
  }

  static List<HymnSection> _sections(
    PublishedHymn hymn,
    ReadingPreferences prefs,
  ) => prefs.sungOrder ? sungOrder(hymn.sections) : hymn.sections;
}

/// En bas, dans la zone de sécurité : cantique précédent / suivant (discrets),
/// puis strophe précédente / suivante (principaux) et la position.
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
    Widget hymnButton(
      String label,
      IconData icon,
      VoidCallback? onPressed, {
      bool end = false,
    }) {
      // Marges et écart réduits : le libellé entier tient sur une ligne
      // dès 360 px ; au-delà de la place disponible, il passe à la ligne.
      final parts = [
        Icon(icon, size: 18),
        const SizedBox(width: LadSpace.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            textAlign: end ? TextAlign.end : TextAlign.start,
          ),
        ),
      ];
      return TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: LadSpace.xs),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: end ? parts.reversed.toList() : parts,
        ),
      );
    }

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
          padding: const EdgeInsets.fromLTRB(
            LadSpace.lg,
            LadSpace.xs,
            LadSpace.lg,
            LadSpace.sm,
          ),
          // Sur tablette, alignés sur la largeur du texte.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: hymnButton(
                            l10n.previousHymn,
                            Icons.skip_previous,
                            onPreviousHymn,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: hymnButton(
                            l10n.nextHymn,
                            Icons.skip_next,
                            onNextHymn,
                            end: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: LadSpace.xs),
                  Row(
                    children: [
                      Tooltip(
                        message: l10n.previousSection,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chevron_left),
                          label: Text(l10n.previous),
                          onPressed: onPreviousSection,
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
                        message: l10n.nextSection,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.chevron_right),
                          iconAlignment: IconAlignment.end,
                          label: Text(l10n.next),
                          onPressed: onNextSection,
                        ),
                      ),
                    ],
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
            style: LadTheme.textStyle(LadTypeScale.title, p.text),
          ),
          const SizedBox(height: LadSpace.md),
          const AccentRule(),
        ],
      ),
    );
  }
}

/// Réglages de lecture (taille, ordre chanté),
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
