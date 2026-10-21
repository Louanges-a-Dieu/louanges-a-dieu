import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/state.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../core/projection/slides.dart';
import '../../l10n/generated/app_localizations.dart';
import '../projection/projection_screen.dart';

/// Présentation plein écran sur l'appareil lui-même (planche 3, écran 13 ;
/// planche 4, écran 12) : les diapositives de la projection, texte très
/// lisible sur fond sombre, défilement automatique facultatif. Pour une
/// tablette posée sur un pupitre, ou un téléphone branché à un écran.
class PresentationScreen extends ConsumerStatefulWidget {
  const PresentationScreen({super.key, this.hymnId, this.serviceId})
    : assert((hymnId == null) != (serviceId == null));

  final String? hymnId;
  final String? serviceId;

  @override
  ConsumerState<PresentationScreen> createState() => _PresentationScreenState();
}

class _PresentationScreenState extends ConsumerState<PresentationScreen> {
  int _index = 0;
  bool _auto = false;
  bool _controls = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().ignore();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky).ignore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable().ignore();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge).ignore();
    super.dispose();
  }

  void _go(int target, int count) {
    if (target < 0 || target >= count) return;
    setState(() => _index = target);
    if (_auto) _schedule(count);
  }

  /// Défilement automatique : une diapositive toutes les N secondes
  /// (réglage), arrêt à la dernière.
  void _schedule(int count) {
    _timer?.cancel();
    if (!_auto) return;
    final seconds =
        (ref.read(preferencesProvider).value ?? const ReadingPreferences())
            .autoAdvanceSeconds;
    _timer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      if (_index + 1 >= count) {
        setState(() => _auto = false);
        return;
      }
      _go(_index + 1, count);
    });
  }

  void _toggleAuto(int count) {
    setState(() => _auto = !_auto);
    _schedule(count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slides =
        ref
            .watch(
              projectionSlidesProvider((
                hymnId: widget.hymnId,
                serviceId: widget.serviceId,
                repeatRefrain: true,
              )),
            )
            .value ??
        const <Slide>[];
    final count = slides.length;
    final index = count == 0 ? 0 : _index.clamp(0, count - 1);
    final slide = count == 0 ? null : slides[index];
    const p = LadPalette.projection;
    final caption = LadTheme.textStyle(
      LadProjectionTypeScale.caption,
      p.goldText,
      projection: true,
    );
    void previous() => _go(index - 1, count);
    void next() => _go(index + 1, count);

    return Theme(
      data: LadTheme.projection,
      child: Scaffold(
        backgroundColor: p.background,
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): previous,
            const SingleActivator(LogicalKeyboardKey.arrowRight): next,
            const SingleActivator(LogicalKeyboardKey.space): next,
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.maybePop(context),
          },
          child: Focus(
            autofocus: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _controls = !_controls),
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200) next();
                if (v > 200) previous();
              },
              child: Stack(
                children: [
                  Positioned.fill(child: SlideView(slide: slide, blank: false)),
                  if (_controls && slide != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(LadSpace.md),
                          child: Text(
                            '${_number(slide)} · ${index + 1} / $count',
                            textAlign: TextAlign.center,
                            style: caption,
                          ),
                        ),
                      ),
                    ),
                  if (_controls)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(LadSpace.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _RoundButton(
                                icon: Icons.chevron_left,
                                label: l10n.previousSlide,
                                onPressed: index > 0 ? previous : null,
                              ),
                              _RoundButton(
                                icon: _auto ? Icons.pause : Icons.play_arrow,
                                label: _auto
                                    ? l10n.autoAdvanceStop
                                    : l10n.autoAdvanceStart,
                                onPressed: count > 1
                                    ? () => _toggleAuto(count)
                                    : null,
                              ),
                              _RoundButton(
                                icon: Icons.chevron_right,
                                label: l10n.nextSlide,
                                onPressed: index + 1 < count ? next : null,
                              ),
                              _RoundButton(
                                icon: Icons.close,
                                label: l10n.close,
                                onPressed: () => Navigator.maybePop(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _number(Slide slide) => switch (slide) {
    TitleSlide(:final numberLabel) => numberLabel,
    LyricsSlide(:final numberLabel) => numberLabel,
    SectionSlide(:final label) => label,
  };
}

/// Bouton rond sur fond sombre, avec son nom écrit dessous (et en infobulle).
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const p = LadPalette.projection;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LadSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            tooltip: label,
            iconSize: 28,
            color: p.text,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(56),
              side: BorderSide(color: p.textSecondary),
              backgroundColor: p.background.withValues(alpha: 0.6),
            ),
            icon: Icon(icon),
            onPressed: onPressed,
          ),
          const SizedBox(height: LadSpace.xs),
          ExcludeSemantics(
            child: Text(
              label,
              style: LadTheme.textStyle(LadTypeScale.caption, p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
