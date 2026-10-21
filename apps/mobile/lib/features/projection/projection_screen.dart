import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/community/community.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/dialogs.dart';
import '../../core/design_system/photos.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../core/projection/projection_server.dart';
import '../../core/projection/projection_state.dart';
import '../../core/projection/slides.dart';
import '../../core/user_data/user_data_models.dart';
import '../../l10n/generated/app_localizations.dart';

/// Ce qui est projeté : un cantique ou un programme de culte, et les options
/// de découpe (refrain répété ; pour un programme, transitions et message de
/// fin).
typedef ProjectionRequest = ({
  String? hymnId,
  String? serviceId,
  bool repeatRefrain,
});

final projectionSlidesProvider = FutureProvider.autoDispose
    .family<List<Slide>, ProjectionRequest>((ref, request) async {
      final catalog = ref.watch(catalogRepositoryProvider);
      final options = ProjectionOptions(repeatRefrain: request.repeatRefrain);
      if (request.hymnId case final id?) {
        final hymn = await catalog.hymnById(id);
        return hymn == null ? const [] : hymnSlides(hymn, options);
      }
      final repo = ref.watch(userDataRepositoryProvider);
      final service = (await ref.watch(worshipServicesProvider.future))
          .where((s) => s.id == request.serviceId)
          .firstOrNull;
      final program = ProgramOptions.decode(service?.options);
      final items = await repo.worshipServiceItems(request.serviceId!);
      return withProgramExtras(
        programSlides([
          for (final item in items)
            if (item.hymnId case final id?)
              HymnEntry(await catalog.hymnById(id))
            else
              LabelEntry(item.label ?? ''),
        ], options),
        transitions: program.transitions,
        endMessage: program.endMessage,
      );
    });

/// Options du programme projeté (null pour un cantique seul).
final _programOptionsProvider = Provider.autoDispose
    .family<ProgramOptions?, String?>((ref, serviceId) {
      if (serviceId == null) return null;
      final service = (ref.watch(worshipServicesProvider).value ?? const [])
          .where((s) => s.id == serviceId)
          .firstOrNull;
      return service == null ? null : ProgramOptions.decode(service.options);
    });

/// Pilote de projection (8.3, planche 5) : le téléphone sert l'écran projeté
/// (8.2) par son serveur local et le commande, sans Internet (ADR-013).
/// Télécommande : strophes, refrain, relancer, cantique suivant, défilement
/// automatique, écran masqué ou noir ; apparence de l'écran ; écran retour.
class ProjectionScreen extends ConsumerStatefulWidget {
  const ProjectionScreen({super.key, this.hymnId, this.serviceId})
    : assert((hymnId == null) != (serviceId == null));

  final String? hymnId;
  final String? serviceId;

  @override
  ConsumerState<ProjectionScreen> createState() => _ProjectionScreenState();
}

class _ProjectionScreenState extends ConsumerState<ProjectionScreen>
    with WidgetsBindingObserver {
  ProjectionHost? _host;
  StreamSubscription<int>? _screensSub;
  int _screens = 0;
  bool _failed = false;
  bool? _repeatRefrain;
  ProjectionState? _state;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable().ignore();
    unawaited(_startHost());
    unawaited(_countProjection());
  }

  /// Statistiques anonymes : chaque cantique projeté (seul ou du programme).
  Future<void> _countProjection() async {
    final recorder = ref.read(usageRecorderProvider);
    final ids = widget.hymnId != null
        ? [widget.hymnId!]
        : [
            for (final item
                in await ref
                    .read(userDataRepositoryProvider)
                    .worshipServiceItems(widget.serviceId!))
              ?item.hymnId,
          ];
    for (final id in ids.toSet()) {
      await recorder.record(id, UsageEvent.project);
    }
  }

  @override
  void dispose() {
    _auto?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable().ignore();
    unawaited(_screensSub?.cancel());
    unawaited(_host?.stop());
    super.dispose();
  }

  Future<void> _startHost({String? token, int? port}) async {
    try {
      final host = await ref.read(projectionHostFactoryProvider)(
        token: token,
        port: port,
      );
      if (!mounted) {
        await host.stop();
        return;
      }
      await _screensSub?.cancel();
      _screensSub = host.screenCountChanges.listen((count) {
        if (mounted) setState(() => _screens = count);
      });
      setState(() {
        _host = host;
        _screens = host.screens;
        _failed = false;
      });
      if (_state case final state?) host.publish(state.toMessage());
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// iOS coupe le réseau d'une app en arrière-plan : le serveur est arrêté
  /// sans fin de session puis relancé avec la même adresse ; les écrans se
  /// reconnectent seuls et gardent la dernière diapositive entre-temps.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final host = _host;
    if (lifecycle == AppLifecycleState.paused && host != null) {
      _host = null;
      unawaited(host.stop(endSession: false));
      _pausedAddress = (token: host.token, port: host.port);
    } else if (lifecycle == AppLifecycleState.resumed &&
        _pausedAddress != null) {
      final address = _pausedAddress!;
      _pausedAddress = null;
      unawaited(_startHost(token: address.token, port: address.port));
    }
  }

  ({String token, int port})? _pausedAddress;

  void _apply(ProjectionState next) {
    setState(() => _state = next);
    _host?.publish(next.toMessage());
  }

  /// Commande manuelle : remet à zéro le délai du défilement automatique.
  void _command(ProjectionState next) {
    _apply(next);
    if (_auto != null) _startAuto();
  }

  void _startAuto() {
    _auto?.cancel();
    final seconds =
        (ref.read(preferencesProvider).value ?? const ReadingPreferences())
            .autoAdvanceSeconds;
    _auto = Timer(Duration(seconds: seconds), () {
      final state = _state;
      if (!mounted || state == null) return;
      if (!state.canGoForward) {
        setState(() => _auto = null);
        return;
      }
      _apply(state.forward());
      _startAuto();
    });
    setState(() {});
  }

  void _toggleAuto() {
    if (_auto != null) {
      _auto!.cancel();
      setState(() => _auto = null);
    } else {
      _startAuto();
    }
  }

  ProjectionDisplay _initialDisplay() {
    final prefs =
        ref.read(preferencesProvider).value ?? const ReadingPreferences();
    final program = ref.read(_programOptionsProvider(widget.serviceId));
    return ProjectionDisplay(
      background: program?.background ?? prefs.projectionBackground,
      showNumber: program?.showNumbers ?? prefs.projectionShowNumber,
      scale: prefs.projectionScale,
    );
  }

  /// Apparence choisie : appliquée tout de suite, gardée pour la prochaine
  /// fois (dans le programme, ou dans les réglages pour un cantique seul).
  Future<void> _changeDisplay(ProjectionDisplay display) async {
    final state = _state;
    if (state != null) _apply(state.withDisplay(display));
    await ref
        .read(preferencesProvider.notifier)
        .change(
          (p) => p.copyWith(
            projectionScale: display.scale,
            projectionBackground: widget.serviceId == null
                ? display.background
                : null,
            projectionShowNumber: widget.serviceId == null
                ? display.showNumber
                : null,
          ),
        );
    final program = ref.read(_programOptionsProvider(widget.serviceId));
    if (program != null) {
      await ref
          .read(userDataRepositoryProvider)
          .updateWorshipService(
            widget.serviceId!,
            options: program.copyWith(
              background: display.background,
              showNumbers: display.showNumber,
            ),
          );
    }
  }

  ProjectionRequest get _request => (
    hymnId: widget.hymnId,
    serviceId: widget.serviceId,
    repeatRefrain:
        _repeatRefrain ??
        ref.watch(_programOptionsProvider(widget.serviceId))?.repeatRefrain ??
        true,
  );

  Future<bool> _confirmStop() async {
    if (_screens == 0) return true;
    final l10n = AppLocalizations.of(context);
    return confirmDialog(
      context,
      title: l10n.stopProjectionTitle,
      message: l10n.stopProjectionMessage,
      action: l10n.stopProjection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final request = _request;
    final slides = ref.watch(projectionSlidesProvider(request));

    // Premières diapositives, ou nouvelles après changement d'option : on
    // reste sur la même section quand elle existe encore.
    final loaded = slides.value;
    if (loaded != null && !identical(loaded, _state?.slides)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || identical(loaded, _state?.slides)) return;
        final current = _state;
        _apply(
          current == null
              ? ProjectionState(slides: loaded, display: _initialDisplay())
              : current.withSlides(loaded, index: _sameSpot(current, loaded)),
        );
      });
    }
    final state = _state;

    return PopScope(
      canPop: _screens == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmStop() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.projectionTitle),
          actions: [
            IconButton(
              tooltip: l10n.connectScreen,
              icon: const Icon(Icons.cast),
              onPressed: _host == null ? null : _showConnect,
            ),
            IconButton(
              tooltip: l10n.displayMode,
              icon: const Icon(Icons.tune),
              onPressed: state == null
                  ? null
                  : () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (_) => _DisplaySheet(
                        initial: state.display,
                        onChanged: _changeDisplay,
                      ),
                    ),
            ),
            PopupMenuButton<String>(
              onSelected: (_) =>
                  setState(() => _repeatRefrain = !request.repeatRefrain),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'refrain',
                  checked: request.repeatRefrain,
                  child: Text(l10n.repeatRefrain),
                ),
              ],
            ),
          ],
        ),
        body: _failed
            ? MessageState(
                title: l10n.projectionUnavailable,
                message: l10n.noNetwork,
              )
            : state == null
            ? const Center(child: CircularProgressIndicator())
            : state.slides.isEmpty
            ? MessageState(
                title: l10n.nothingToProject,
                message: l10n.nothingToProjectMessage,
              )
            : _Controller(
                state: state,
                screens: _screens,
                auto: _auto != null,
                program: widget.serviceId != null,
                onConnect: _host == null ? null : _showConnect,
                onChanged: _command,
                onToggleAuto: _toggleAuto,
              ),
      ),
    );
  }

  /// Après changement d'option, reste sur la même section si elle existe.
  int _sameSpot(ProjectionState current, List<Slide> next) {
    final slide = current.current;
    if (slide == null) return 0;
    final json = slide.toJson().toString();
    final found = next.indexWhere((s) => s.toJson().toString() == json);
    return found >= 0 ? found : current.index;
  }

  Future<void> _showConnect() async {
    final host = _host;
    if (host == null) return;
    final urls = await host.screenUrls();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ScreenConnectSheet(urls: urls),
    );
  }
}

class _Controller extends StatelessWidget {
  const _Controller({
    required this.state,
    required this.screens,
    required this.auto,
    required this.program,
    required this.onConnect,
    required this.onChanged,
    required this.onToggleAuto,
  });

  final ProjectionState state;
  final int screens;
  final bool auto;
  final bool program;
  final VoidCallback? onConnect;
  final ValueChanged<ProjectionState> onChanged;
  final VoidCallback onToggleAuto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final next = state.next;
    final status = ListTile(
      leading: Icon(
        screens > 0 ? Icons.cast_connected : Icons.cast,
        color: screens > 0 ? p.success : p.textSecondary,
      ),
      title: Text(
        screens > 0 ? l10n.screensConnected(screens) : l10n.noScreenConnected,
      ),
      trailing: screens == 0 && onConnect != null
          ? TextButton(onPressed: onConnect, child: Text(l10n.connectScreen))
          : null,
    );
    final upNext = Padding(
      padding: const EdgeInsets.fromLTRB(
        LadSpace.md,
        LadSpace.sm,
        LadSpace.md,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          next == null ? l10n.lastSlide : l10n.upNext(slideLabel(next)),
          style: LadTheme.textStyle(LadTypeScale.caption, p.textSecondary),
        ),
      ),
    );
    final slideList = ListView.builder(
      itemCount: state.slides.length,
      itemBuilder: (context, i) {
        final slide = state.slides[i];
        final selected = i == state.index;
        return ListTile(
          dense: slide is LyricsSlide,
          selected: selected,
          selectedTileColor: p.goldPale,
          contentPadding: EdgeInsets.only(
            left: slide is LyricsSlide ? LadSpace.xxl : LadSpace.md,
            right: LadSpace.md,
          ),
          title: Text(
            slideLabel(slide),
            style: slide is LyricsSlide
                ? null
                : const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: slide is LyricsSlide
              ? Text(
                  slide.lines.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => onChanged(state.goTo(i)),
        );
      },
    );
    final remote = _Remote(
      state: state,
      auto: auto,
      program: program,
      onChanged: onChanged,
      onToggleAuto: onToggleAuto,
    );
    Widget preview(double maxHeight) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LadSpace.md),
        child: Center(
          heightFactor: 1,
          child: SlidePreview(
            slide: state.current,
            blank: state.blank,
            mask: state.mask,
            display: state.display,
          ),
        ),
      ),
    );

    // Tablette (planche 5, écran 14) : liste à gauche, aperçu et
    // télécommande à droite.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Row(
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.38,
                child: Column(
                  children: [
                    ListSectionHeader(l10n.allSlides),
                    Expanded(child: slideList),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: p.hairline),
              Expanded(
                child: Column(
                  children: [
                    status,
                    preview(constraints.maxHeight / 2),
                    upNext,
                    const Spacer(),
                    remote,
                  ],
                ),
              ),
            ],
          );
        }
        // Aperçu limité à un tiers de la hauteur : la liste et les boutons
        // restent visibles.
        return Column(
          children: [
            status,
            preview(constraints.maxHeight / 3),
            upNext,
            ListSectionHeader(l10n.allSlides),
            Expanded(child: slideList),
            remote,
          ],
        );
      },
    );
  }
}

/// Télécommande (planche 5, écrans 6 et 9) : commandes du culte au-dessus,
/// Précédente / Suivante en grand dessous.
class _Remote extends StatelessWidget {
  const _Remote({
    required this.state,
    required this.auto,
    required this.program,
    required this.onChanged,
    required this.onToggleAuto,
  });

  final ProjectionState state;
  final bool auto;
  final bool program;
  final ValueChanged<ProjectionState> onChanged;
  final VoidCallback onToggleAuto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refrain = state.nextRefrain;
    final nextHymn = state.nextHymn;
    Widget tool(
      IconData icon,
      String label,
      VoidCallback? onPressed, {
      bool? selected,
      IconData? selectedIcon,
    }) => Semantics(
      toggled: selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            tooltip: label,
            isSelected: selected,
            icon: Icon(icon),
            selectedIcon: selectedIcon == null ? null : Icon(selectedIcon),
            style: IconButton.styleFrom(minimumSize: const Size.square(48)),
            onPressed: onPressed,
          ),
          ExcludeSemantics(
            child: Text(
              label,
              style: LadTheme.textStyle(
                LadTypeScale.caption,
                context.lad.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(LadSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: LadSpace.md,
              runSpacing: LadSpace.sm,
              children: [
                tool(
                  Icons.replay,
                  l10n.restartHymn,
                  state.index == state.hymnStart
                      ? null
                      : () => onChanged(state.goTo(state.hymnStart)),
                ),
                tool(
                  Icons.redo,
                  l10n.refrainShort,
                  refrain == null ? null : () => onChanged(state.goTo(refrain)),
                ),
                tool(
                  Icons.visibility_off_outlined,
                  l10n.maskScreen,
                  () => onChanged(state.toggleMask()),
                  selected: state.mask,
                  selectedIcon: Icons.visibility_outlined,
                ),
                tool(
                  Icons.tv,
                  l10n.blankScreen,
                  () => onChanged(state.toggleBlank()),
                  selected: state.blank,
                  selectedIcon: Icons.tv_off,
                ),
                tool(
                  Icons.play_arrow,
                  auto ? l10n.autoAdvanceStop : l10n.autoAdvanceStart,
                  state.canGoForward || auto ? onToggleAuto : null,
                  selected: auto,
                  selectedIcon: Icons.pause,
                ),
                if (program)
                  tool(
                    Icons.skip_next,
                    l10n.nextHymnShort,
                    nextHymn == null
                        ? null
                        : () => onChanged(state.goTo(nextHymn)),
                  ),
              ],
            ),
            const SizedBox(height: LadSpace.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: _big,
                    icon: const Icon(Icons.chevron_left),
                    label: Text(l10n.previousSlide),
                    onPressed: state.canGoBack
                        ? () => onChanged(state.back())
                        : null,
                  ),
                ),
                const SizedBox(width: LadSpace.sm),
                Expanded(
                  child: FilledButton.icon(
                    style: _big,
                    icon: const Icon(Icons.chevron_right),
                    iconAlignment: IconAlignment.end,
                    label: Text(l10n.nextSlide),
                    onPressed: state.canGoForward
                        ? () => onChanged(state.forward())
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final _big = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)),
  );
}

/// Mode d'affichage (planche 5, écran 3) : fond, numéro, taille du texte ;
/// chaque changement est appliqué à l'écran tout de suite.
class _DisplaySheet extends StatefulWidget {
  const _DisplaySheet({required this.initial, required this.onChanged});

  final ProjectionDisplay initial;
  final ValueChanged<ProjectionDisplay> onChanged;

  @override
  State<_DisplaySheet> createState() => _DisplaySheetState();
}

class _DisplaySheetState extends State<_DisplaySheet> {
  late var _display = widget.initial;

  void _set(ProjectionDisplay display) {
    setState(() => _display = display);
    widget.onChanged(display);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final label = LadTheme.textStyle(LadTypeScale.label, p.textSecondary);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LadSpace.xl,
          0,
          LadSpace.xl,
          LadSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.displayMode,
              style: LadTheme.textStyle(LadTypeScale.headline, p.text),
            ),
            const SizedBox(height: LadSpace.md),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: SlidePreview(
                  slide: const TitleSlide(
                    numberLabel: '1',
                    title: 'Louanges à Dieu',
                  ),
                  blank: false,
                  display: _display,
                ),
              ),
            ),
            const SizedBox(height: LadSpace.lg),
            Text(l10n.projectionBackground, style: label),
            const SizedBox(height: LadSpace.sm),
            Wrap(
              spacing: LadSpace.sm,
              runSpacing: LadSpace.sm,
              children: [
                for (final (value, name) in [
                  ('dark', l10n.backgroundDark),
                  ('light', l10n.backgroundLight),
                  for (final (i, photo) in appPhotos.keys.indexed)
                    ('image:$photo', l10n.photoNumber(i + 1)),
                ])
                  ChoiceChip(
                    label: Text(name),
                    selected: _display.background == value,
                    onSelected: (_) =>
                        _set(_display.copyWith(background: value)),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showNumber),
              value: _display.showNumber,
              onChanged: (v) => _set(_display.copyWith(showNumber: v)),
            ),
            Text(l10n.textSize, style: label),
            Slider(
              min: ProjectionDisplay.minScale,
              max: ProjectionDisplay.maxScale,
              divisions: 6,
              value: _display.scale,
              label: '${(_display.scale * 100).round()} %',
              semanticFormatterCallback: (v) => '${(v * 100).round()} %',
              onChanged: (v) =>
                  setState(() => _display = _display.copyWith(scale: v)),
              onChangeEnd: (v) => _set(_display.copyWith(scale: v)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu de ce que montre l'écran projeté (mêmes couleurs), au format 16/9.
class SlidePreview extends StatelessWidget {
  const SlidePreview({
    super.key,
    required this.slide,
    required this.blank,
    this.mask = false,
    this.display = const ProjectionDisplay(),
  });

  final Slide? slide;
  final bool blank;
  final bool mask;
  final ProjectionDisplay display;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: SlideView(
      slide: slide,
      blank: blank,
      mask: mask,
      display: display,
      framed: true,
    ),
  );
}

/// Une diapositive avec le fond de l'écran projeté ; plein écran sur
/// l'appareil (présentation) ou encadrée (aperçu du pilote).
class SlideView extends StatelessWidget {
  const SlideView({
    super.key,
    required this.slide,
    required this.blank,
    this.mask = false,
    this.display = const ProjectionDisplay(),
    this.framed = false,
  });

  final Slide? slide;
  final bool blank;
  final bool mask;
  final ProjectionDisplay display;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    // Fond clair : palette claire ; sinon celle de l'écran projeté.
    final p = display.background == 'light'
        ? LadPalette.light
        : LadPalette.projection;
    final photo = photoAsset(display.image);
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        // « Écran noir » : noir pur, comme l'écran projeté ; sinon le fond
        // choisi : photo voilée, clair, ou vert-noir et sa lumière discrète
        // venue du bas.
        color: blank ? Colors.black : p.background,
        image: blank || photo == null
            ? null
            : DecorationImage(
                image: AssetImage(photo),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.55),
                  BlendMode.darken,
                ),
              ),
        gradient: blank || photo != null || display.background == 'light'
            ? null
            : RadialGradient(
                center: const Alignment(0.4, 1.1),
                radius: 0.9,
                // Un dégradé remplace la couleur : teintes opaques sur le fond.
                colors: [
                  Color.alphaBlend(
                    p.goldLight.withValues(alpha: 0.16),
                    p.background,
                  ),
                  p.background,
                ],
              ),
        borderRadius: framed ? BorderRadius.circular(LadRadius.md) : null,
        border: framed ? Border.all(color: context.lad.hairline) : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(framed ? LadSpace.md : LadSpace.xl),
        child: blank
            ? Center(
                child: framed
                    ? Text(
                        l10n.blankScreenOn,
                        style: _style(
                          LadProjectionTypeScale.label,
                          LadPalette.projection.textSecondary,
                        ),
                      )
                    : null,
              )
            : Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: mask
                      ? _brand(p)
                      : _slideContent(slide, p, display.showNumber),
                ),
              ),
      ),
    );
  }

  /// Polices et échelle de l'écran projeté : l'aperçu doit lui rester fidèle.
  static TextStyle _style(LadTextSpec spec, Color color) =>
      LadTheme.textStyle(spec, color, projection: true);

  static Widget _brand(LadPalette p) => Column(
    children: [
      WheatEar(size: 40, color: p.gold),
      Text(
        'Louanges à Dieu'.toUpperCase(),
        style: _style(LadProjectionTypeScale.caption, p.goldText),
      ),
    ],
  );

  Widget _slideContent(Slide? slide, LadPalette p, bool showNumber) =>
      switch (slide) {
        null => const SizedBox.shrink(),
        TransitionSlide() => _brand(p),
        EndSlide(:final message) => Column(
          children: [
            WheatEar(size: 32, color: p.gold),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _style(LadProjectionTypeScale.title, p.text),
            ),
          ],
        ),
        TitleSlide(:final numberLabel, :final title) => Column(
          children: [
            if (showNumber)
              Text(
                numberLabel,
                style: _style(LadProjectionTypeScale.hymnNumber, p.goldText),
              ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _style(LadProjectionTypeScale.title, p.text),
            ),
          ],
        ),
        SectionSlide(:final label) => Text(
          label,
          textAlign: TextAlign.center,
          style: _style(LadProjectionTypeScale.title, p.text),
        ),
        final LyricsSlide s => Column(
          children: [
            Text(
              (showNumber
                      ? '${s.numberLabel} · ${slideLabel(s)}'
                      : slideLabel(s))
                  .toUpperCase(),
              style: _style(LadProjectionTypeScale.caption, p.goldText),
            ),
            const SizedBox(height: LadSpace.xs),
            for (final line in s.lines)
              Text(
                line,
                textAlign: TextAlign.center,
                style: _style(LadProjectionTypeScale.lyrics, p.text).copyWith(
                  fontStyle: s.sectionType == SectionType.refrain
                      ? FontStyle.italic
                      : null,
                ),
              ),
          ],
        ),
      };
}

/// Connexion d'un écran : adresse, code à scanner, étapes ; [tv] : textes
/// pour un téléviseur (karaoké en famille), sans écran retour.
class ScreenConnectSheet extends StatelessWidget {
  const ScreenConnectSheet({super.key, required this.urls, this.tv = false});

  final List<Uri> urls;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final main = urls.firstOrNull;
    final step = LadTheme.textStyle(LadTypeScale.body, p.text);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LadSpace.xl,
          0,
          LadSpace.xl,
          LadSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.connectScreen,
              style: LadTheme.textStyle(LadTypeScale.headline, p.text),
            ),
            const SizedBox(height: LadSpace.md),
            Text(
              '1. ${tv ? l10n.connectTvStep1 : l10n.connectStep1}',
              style: step,
            ),
            const SizedBox(height: LadSpace.sm),
            Text(
              '2. ${tv ? l10n.connectTvStep2 : l10n.connectStep2}',
              style: step,
            ),
            const SizedBox(height: LadSpace.lg),
            if (main == null)
              Text(
                l10n.noNetwork,
                style: LadTheme.textStyle(LadTypeScale.body, p.error),
              )
            else ...[
              SelectableText(
                main.toString(),
                textAlign: TextAlign.center,
                style: LadTheme.textStyle(LadTypeScale.title, p.goldText),
              ),
              const SizedBox(height: LadSpace.md),
              Center(
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(LadSpace.sm),
                    child: QrImageView(
                      data: main.toString(),
                      size: 180,
                      semanticsLabel: main.toString(),
                    ),
                  ),
                ),
              ),
              if (urls.length > 1) ...[
                const SizedBox(height: LadSpace.md),
                Text(
                  l10n.otherAddresses,
                  style: LadTheme.textStyle(
                    LadTypeScale.caption,
                    p.textSecondary,
                  ),
                ),
                for (final u in urls.skip(1))
                  SelectableText(
                    u.toString(),
                    style: LadTheme.textStyle(LadTypeScale.body, p.text),
                  ),
              ],
            ],
            const SizedBox(height: LadSpace.lg),
            Text(
              '3. ${tv ? l10n.connectTvStep3 : l10n.connectStep3}',
              style: step,
            ),
            if (main != null && !tv) ...[
              const SizedBox(height: LadSpace.xl),
              Text(
                l10n.returnScreen,
                style: LadTheme.textStyle(LadTypeScale.cardTitle, p.text),
              ),
              const SizedBox(height: LadSpace.xs),
              Text(
                l10n.returnScreenHint,
                style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
              ),
              const SizedBox(height: LadSpace.sm),
              SelectableText(
                main.replace(queryParameters: {'role': 'retour'}).toString(),
                style: LadTheme.textStyle(LadTypeScale.body, p.goldText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
