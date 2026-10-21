import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../settings/reading_settings.dart';

/// Mode lecture : une strophe (couplet ou refrain) à la fois, le refrain
/// répété après chaque couplet (ordre chanté, ADR-009). Précédent /
/// Suivant (boutons, glissement, flèches du clavier) passent d'une strophe à
/// l'autre ; Cantique précédent / suivant changent de cantique, dans l'ordre
/// du recueil, ou de la liste / du programme lu ([listId], [serviceId]).
/// Réglages de lecture (taille, police, apparence…), plein écran, et à la
/// dernière strophe les cantiques suivants (planche 3).
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.hymnId,
    this.listId,
    this.serviceId,
  });

  final String hymnId;
  final String? listId;
  final String? serviceId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int? _index;

  /// Strophe affichée dans le cantique courant.
  int _section = 0;

  bool? _awake;
  ReaderOrientation? _orientation;

  @override
  void dispose() {
    WakelockPlus.disable().ignore();
    SystemChrome.setPreferredOrientations(const []).ignore();
    super.dispose();
  }

  /// Écran allumé et orientation, appliqués quand le réglage change.
  void _applyDevice(ReadingPreferences prefs) {
    if (_awake != prefs.keepScreenOn) {
      _awake = prefs.keepScreenOn;
      WakelockPlus.toggle(enable: prefs.keepScreenOn).ignore();
    }
    if (_orientation != prefs.orientation) {
      _orientation = prefs.orientation;
      SystemChrome.setPreferredOrientations(switch (prefs.orientation) {
        ReaderOrientation.auto => const [],
        ReaderOrientation.portrait => const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        ReaderOrientation.landscape => const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      }).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hymns = ref
        .watch(
          readerSequenceProvider((
            listId: widget.listId,
            serviceId: widget.serviceId,
          )),
        )
        .value;
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final notifier = ref.read(preferencesProvider.notifier);
    _applyDevice(prefs);
    if (hymns == null || hymns.isEmpty) return const Scaffold();
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

    // « Auto » : l'apparence de l'app (claire, sombre ou sépia).
    final theme = prefs.readerTheme == LadAppearance.system
        ? Theme.of(context)
        : LadTheme.forAppearance(prefs.readerTheme, Brightness.light);
    final dark = theme.brightness == Brightness.dark;
    void goTo(int target) => setState(() => _section = target);
    final following = hymns.sublist(index + 1).take(4).toList();

    return Theme(
      data: theme,
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
          following: section == sections.length - 1 ? following : const [],
          onFollowing: (h) => toHymn(hymns.indexOf(h))?.call(),
          inSequence: widget.listId != null || widget.serviceId != null,
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
              tooltip: l10n.readingSettings,
              icon: const Icon(Icons.text_fields),
              onPressed: () => showReadingSettings(context),
            ),
            IconButton(
              tooltip: dark ? l10n.readerLight : l10n.readerDark,
              icon: Icon(
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              ),
              onPressed: () => notifier.change(
                (p) => p.copyWith(
                  readerTheme: dark ? LadAppearance.light : LadAppearance.dark,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.fullScreen,
              icon: const Icon(Icons.fullscreen),
              onPressed: () =>
                  context.push('/presentation?cantique=${current.id}'),
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
    required List<HymnSummary> following,
    required ValueChanged<HymnSummary> onFollowing,
    required bool inSequence,
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
                    prefs: prefs,
                    following: following,
                    onFollowing: onFollowing,
                    inSequence: inSequence,
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
    required this.prefs,
    required this.following,
    required this.onFollowing,
    required this.inSequence,
  });

  final PublishedHymn hymn;
  final List<HymnSection> sections;
  final int section;
  final ReadingPreferences prefs;
  final List<HymnSummary> following;
  final ValueChanged<HymnSummary> onFollowing;
  final bool inSequence;

  @override
  Widget build(BuildContext context) {
    final wide = prefs.margins == ReaderMargins.wide;
    return SelectionArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          wide ? LadSpace.xxl : LadSpace.lg,
          LadSpace.sm,
          wide ? LadSpace.xxl : LadSpace.lg,
          LadSpace.xxl,
        ),
        children: [
          ReadableWidth(
            maxWidth: wide ? 560 : 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReaderHeader(hymn: hymn, prefs: prefs),
                const SizedBox(height: LadSpace.xl),
                if (sections.isNotEmpty)
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : LadDurations.base,
                    child: SectionBlock(
                      key: ValueKey('${hymn.id}/$section'),
                      section: sections[section],
                      fontSize: prefs.lyricsSize,
                      fontFamily: LadTheme.lyricsFamily(prefs.lyricsFont),
                      lineSpacing: prefs.lineSpacing,
                      showName: true,
                    ),
                  ),
                if (following.isNotEmpty) ...[
                  const SizedBox(height: LadSpace.xxl),
                  _Following(
                    hymns: following,
                    inSequence: inSequence,
                    onTap: onFollowing,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fin du cantique : les suivants (du recueil, de la liste ou du
/// programme), et un bouton pour lire le premier (planche 3, écran 16).
class _Following extends StatelessWidget {
  const _Following({
    required this.hymns,
    required this.inSequence,
    required this.onTap,
  });

  final List<HymnSummary> hymns;
  final bool inSequence;
  final ValueChanged<HymnSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListSectionHeader(inSequence ? l10n.nextInList : l10n.nextHymns),
        for (final h in hymns)
          HymnListTile(hymn: h, margin: EdgeInsets.zero, onTap: () => onTap(h)),
        const SizedBox(height: LadSpace.md),
        FilledButton.icon(
          icon: const Icon(Icons.skip_next),
          label: Text(l10n.readHymn(hymns.first.numberLabel)),
          onPressed: () => onTap(hymns.first),
        ),
      ],
    );
  }
}

/// En-tête discret du mode lecture : numéro, titre serif, références,
/// filet doré ; chaque élément peut être masqué (réglages de lecture).
class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({required this.hymn, required this.prefs});

  final PublishedHymn hymn;
  final ReadingPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final references = prefs.showReferences
        ? hymn.bibleReferences.map((r) => r.displayText).join(' · ')
        : '';
    return Semantics(
      container: true,
      header: true,
      label: 'Cantique ${spokenNumber(hymn.numberLabel)}, ${hymn.title}',
      excludeSemantics: true,
      child: Column(
        children: [
          if (prefs.showNumber) ...[
            HymnNumberBadge(hymn.numberLabel),
            const SizedBox(height: LadSpace.md),
          ],
          if (prefs.showTitle) ...[
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
          ],
          if (references.isNotEmpty) ...[
            Text(
              references,
              textAlign: TextAlign.center,
              style: LadTheme.textStyle(LadTypeScale.caption, p.goldText),
            ),
            const SizedBox(height: LadSpace.md),
          ],
          const AccentRule(),
        ],
      ),
    );
  }
}
