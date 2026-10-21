import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';

/// Réglages de lecture (planche 3, écrans 9 et 10 ; planche 7, écran 9) :
/// taille, police, apparence, interligne, marges, en-tête, écran allumé,
/// orientation. Dans une feuille depuis le mode lecture, ou dans
/// Paramètres → Lecture.
class ReadingSettings extends ConsumerWidget {
  const ReadingSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final notifier = ref.read(preferencesProvider.notifier);
    void set(ReadingPreferences Function(ReadingPreferences) apply) =>
        notifier.change(apply);
    const steps = (LadLyricsSize.max - LadLyricsSize.min) ~/ LadLyricsSize.step;
    const spacings = ReadingPreferences.lineSpacings;
    final spacingIndex = spacings
        .indexWhere((s) => s >= prefs.lineSpacing)
        .clamp(0, spacings.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsLabel(l10n.textSize),
        Row(
          children: [
            IconButton(
              tooltip: l10n.smallerText,
              icon: const Icon(Icons.text_decrease),
              onPressed: prefs.lyricsSize <= LadLyricsSize.min
                  ? null
                  : () => set(
                      (p) => p.copyWith(
                        lyricsSize: p.lyricsSize - LadLyricsSize.step,
                      ),
                    ),
            ),
            Expanded(
              child: Slider(
                min: LadLyricsSize.min,
                max: LadLyricsSize.max,
                divisions: steps,
                value: prefs.lyricsSize,
                label: '${prefs.lyricsSize.round()}',
                semanticFormatterCallback: (v) => '${v.round()} points',
                onChanged: (v) => set((p) => p.copyWith(lyricsSize: v)),
              ),
            ),
            IconButton(
              tooltip: l10n.largerText,
              icon: const Icon(Icons.text_increase),
              onPressed: prefs.lyricsSize >= LadLyricsSize.max
                  ? null
                  : () => set(
                      (p) => p.copyWith(
                        lyricsSize: p.lyricsSize + LadLyricsSize.step,
                      ),
                    ),
            ),
          ],
        ),
        SettingsLabel(l10n.lyricsFont),
        _Choice<LyricsFont>(
          value: prefs.lyricsFont,
          options: {
            LyricsFont.classic: l10n.fontClassic,
            LyricsFont.modern: l10n.fontModern,
            LyricsFont.editorial: l10n.fontEditorial,
          },
          onChanged: (v) => set((p) => p.copyWith(lyricsFont: v)),
        ),
        SettingsLabel(l10n.readerAppearance),
        _Choice<LadAppearance>(
          value: prefs.readerTheme,
          options: {
            LadAppearance.system: l10n.appearanceAuto,
            LadAppearance.light: l10n.themeLight,
            LadAppearance.dark: l10n.themeDark,
            LadAppearance.sepia: l10n.themeSepia,
          },
          onChanged: (v) => set((p) => p.copyWith(readerTheme: v)),
        ),
        SettingsLabel(l10n.lineSpacing),
        Slider(
          min: 0,
          max: spacings.length - 1.0,
          divisions: spacings.length - 1,
          value: spacingIndex.toDouble(),
          label: formatSpacing(spacings[spacingIndex]),
          semanticFormatterCallback: (v) =>
              l10n.lineSpacingValue(formatSpacing(spacings[v.round()])),
          onChanged: (v) =>
              set((p) => p.copyWith(lineSpacing: spacings[v.round()])),
        ),
        SettingsLabel(l10n.margins),
        _Choice<ReaderMargins>(
          value: prefs.margins,
          options: {
            ReaderMargins.standard: l10n.marginsStandard,
            ReaderMargins.wide: l10n.marginsWide,
          },
          onChanged: (v) => set((p) => p.copyWith(margins: v)),
        ),
        SettingsLabel(l10n.orientation),
        _Choice<ReaderOrientation>(
          value: prefs.orientation,
          options: {
            ReaderOrientation.auto: l10n.appearanceAuto,
            ReaderOrientation.portrait: l10n.orientationPortrait,
            ReaderOrientation.landscape: l10n.orientationLandscape,
          },
          onChanged: (v) => set((p) => p.copyWith(orientation: v)),
        ),
        const SizedBox(height: LadSpace.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.showNumber),
          value: prefs.showNumber,
          onChanged: (v) => set((p) => p.copyWith(showNumber: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.showTitle),
          value: prefs.showTitle,
          onChanged: (v) => set((p) => p.copyWith(showTitle: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.showReferences),
          value: prefs.showReferences,
          onChanged: (v) => set((p) => p.copyWith(showReferences: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.keepScreenOn),
          value: prefs.keepScreenOn,
          onChanged: (v) => set((p) => p.copyWith(keepScreenOn: v)),
        ),
        const SizedBox(height: LadSpace.sm),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.resetReading),
            style: TextButton.styleFrom(foregroundColor: p.goldText),
            onPressed: () => set((p) => p.resetReading()),
          ),
        ),
      ],
    );
  }
}

/// « 1,15 » : interligne relatif.
String formatSpacing(double value) =>
    value.toStringAsFixed(value * 10 % 1 == 0 ? 1 : 2).replaceAll('.', ',');

/// Feuille « Réglages de lecture » du mode lecture.
Future<void> showReadingSettings(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              LadSpace.lg,
              0,
              LadSpace.lg,
              LadSpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListSectionHeader(AppLocalizations.of(sheet).readingSettings),
                const ReadingSettings(),
              ],
            ),
          ),
        ),
      ),
    );

/// Intitulé d'un réglage dans une page de paramètres.
class SettingsLabel extends StatelessWidget {
  const SettingsLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: LadSpace.md, bottom: LadSpace.sm),
    child: Text(
      text,
      style: LadTheme.textStyle(LadTypeScale.label, context.lad.textSecondary),
    ),
  );
}

/// Choix exclusif en boutons segmentés (étiquettes écrites, jamais la seule
/// couleur).
class _Choice<T extends Object> extends StatelessWidget {
  const _Choice({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    showSelectedIcon: false,
    segments: [
      for (final MapEntry(:key, :value) in options.entries)
        ButtonSegment(value: key, label: Text(value)),
    ],
    selected: {value},
    onSelectionChanged: (s) => onChanged(s.first),
  );
}
