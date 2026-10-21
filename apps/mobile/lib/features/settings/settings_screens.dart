import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/env.dart';
import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../audio/audio_screen.dart';
import 'reading_settings.dart';

/// Adresse de contact du projet (Q-17).
const contactEmail = 'louangesaDieu04@gmail.com';

/// Version de l'app (« 0.1.0 (1) »).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Page de réglages : titre, contenu limité en largeur, défilement.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
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
            children: children,
          ),
        ),
      ],
    ),
  );
}

/// Apparence (planche 7, écran 8) : thème de l'app, taille et police des
/// paroles, aperçu.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final notifier = ref.read(preferencesProvider.notifier);
    final day = ref.watch(hymnOfTheDayProvider);
    final sample = day == null ? null : ref.watch(hymnProvider(day.id)).value;
    final platform = MediaQuery.platformBrightnessOf(context);
    return _SettingsPage(
      title: l10n.appearance,
      children: [
        ListSectionHeader(l10n.theme),
        Wrap(
          spacing: LadSpace.md,
          runSpacing: LadSpace.md,
          children: [
            for (final (appearance, label) in [
              (LadAppearance.system, l10n.themeSystem),
              (LadAppearance.light, l10n.themeLight),
              (LadAppearance.dark, l10n.themeDark),
              (LadAppearance.sepia, l10n.themeSepia),
            ])
              _ThemeTile(
                theme: LadTheme.forAppearance(appearance, platform),
                label: label,
                selected: prefs.appearance == appearance,
                onTap: () =>
                    notifier.change((p) => p.copyWith(appearance: appearance)),
              ),
          ],
        ),
        const SizedBox(height: LadSpace.lg),
        ListSectionHeader(l10n.textSize),
        Slider(
          min: LadLyricsSize.min,
          max: LadLyricsSize.max,
          divisions:
              (LadLyricsSize.max - LadLyricsSize.min) ~/ LadLyricsSize.step,
          value: prefs.lyricsSize,
          label: '${prefs.lyricsSize.round()}',
          semanticFormatterCallback: (v) => '${v.round()} points',
          onChanged: (v) => notifier.change((p) => p.copyWith(lyricsSize: v)),
        ),
        ListSectionHeader(l10n.lyricsFont),
        SegmentedButton<LyricsFont>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: LyricsFont.classic,
              label: Text(l10n.fontClassic),
            ),
            ButtonSegment(
              value: LyricsFont.modern,
              label: Text(l10n.fontModern),
            ),
            ButtonSegment(
              value: LyricsFont.editorial,
              label: Text(l10n.fontEditorial),
            ),
          ],
          selected: {prefs.lyricsFont},
          onSelectionChanged: (s) =>
              notifier.change((p) => p.copyWith(lyricsFont: s.first)),
        ),
        if (sample?.sections.firstOrNull case final HymnSection first) ...[
          const SizedBox(height: LadSpace.lg),
          ListSectionHeader(l10n.preview),
          Container(
            padding: const EdgeInsets.all(LadSpace.lg),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(LadRadius.lg),
              border: Border.all(color: p.hairline, width: LadStroke.hairline),
            ),
            child: SectionBlock(
              section: HymnSection(
                id: first.id,
                type: first.type,
                number: first.number,
                order: first.order,
                lines: first.lines.take(2).toList(),
              ),
              fontSize: prefs.lyricsSize,
              fontFamily: LadTheme.lyricsFamily(prefs.lyricsFont),
              lineSpacing: prefs.lineSpacing,
            ),
          ),
        ],
      ],
    );
  }
}

/// Vignette d'un thème : ses vraies couleurs, son nom écrit, coche.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeData theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final t = theme.extension<LadColors>()!.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LadRadius.md),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 96,
              decoration: BoxDecoration(
                color: t.background,
                borderRadius: BorderRadius.circular(LadRadius.md),
                border: Border.all(
                  color: selected ? p.goldText : p.hairline,
                  width: selected ? LadStroke.accent : LadStroke.hairline,
                ),
              ),
              padding: const EdgeInsets.all(LadSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aa',
                    style: LadTheme.textStyle(LadTypeScale.cardTitle, t.text),
                  ),
                  const Spacer(),
                  for (final w in [44.0, 32.0, 40.0])
                    Container(
                      width: w,
                      height: 3,
                      margin: const EdgeInsets.only(top: 4),
                      color: t.textSecondary,
                    ),
                  const SizedBox(height: 4),
                  Container(width: 24, height: 3, color: t.gold),
                ],
              ),
            ),
            const SizedBox(height: LadSpace.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) Icon(Icons.check, size: 16, color: p.goldText),
                Text(
                  label,
                  style: LadTheme.textStyle(
                    LadTypeScale.caption,
                    selected ? p.goldText : p.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lecture (planche 7, écran 9) : réglages du mode lecture, ordre chanté sur
/// la fiche, délai du défilement automatique.
class ReadingSettingsScreen extends ConsumerWidget {
  const ReadingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final notifier = ref.read(preferencesProvider.notifier);
    return _SettingsPage(
      title: l10n.reading,
      children: [
        const ReadingSettings(),
        const Divider(height: LadSpace.xl),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.sungOrderOption),
          subtitle: Text(l10n.sungOrderHint),
          value: prefs.sungOrder,
          onChanged: (v) => notifier.change((p) => p.copyWith(sungOrder: v)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.autoAdvanceDelay),
          subtitle: Text(l10n.autoAdvanceHint),
          trailing: DropdownButton<int>(
            value: prefs.autoAdvanceSeconds,
            underline: const SizedBox.shrink(),
            onChanged: (v) => v == null
                ? null
                : notifier.change((p) => p.copyWith(autoAdvanceSeconds: v)),
            items: [
              for (final s in ReadingPreferences.autoAdvanceChoices)
                DropdownMenuItem(value: s, child: Text(l10n.seconds(s))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Audio (planche 7, écran 10) : vitesse, boucle, téléchargements.
class AudioSettingsScreen extends StatelessWidget {
  const AudioSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SettingsPage(
      title: l10n.audioSettings,
      children: [
        const ListeningOptions(),
        const Divider(height: LadSpace.xl),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.audioDownloadsTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/plus/hors-connexion'),
        ),
      ],
    );
  }
}

/// Ouvre un lien hors de l'app ; message si impossible.
Future<void> openExternal(BuildContext context, Uri url) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).linkOpenFailed;
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

/// Courriel au projet, avec sujet (et corps) prérempli.
Uri contactUri(String subject, [String? body]) => Uri(
  scheme: 'mailto',
  path: contactEmail,
  query: [
    'subject=${Uri.encodeComponent(subject)}',
    if (body != null) 'body=${Uri.encodeComponent(body)}',
  ].join('&'),
);

/// Confidentialité (planche 7, écran 14) : ce que l'app conserve, politique,
/// compte.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final web = ref.watch(envProvider).publicWebUrl;
    return _SettingsPage(
      title: l10n.privacy,
      children: [
        ListSectionHeader(l10n.privacyDataTitle),
        Text(
          l10n.privacyDataText,
          style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
        ),
        const SizedBox(height: LadSpace.lg),
        if (web.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.open_in_new),
            onTap: () =>
                openExternal(context, Uri.parse('$web/confidentialite')),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(l10n.accountAndDeletion),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/compte'),
        ),
      ],
    );
  }
}

/// Questions fréquentes : (question, réponse).
List<(String, String)> faq(AppLocalizations l10n) => [
  (l10n.faqOfflineQ, l10n.faqOfflineA),
  (l10n.faqFindQ, l10n.faqFindA),
  (l10n.faqAccountQ, l10n.faqAccountA),
  (l10n.faqProjectQ, l10n.faqProjectA),
  (l10n.faqTextSizeQ, l10n.faqTextSizeA),
  (l10n.faqRefrainQ, l10n.faqRefrainA),
  (l10n.faqListenQ, l10n.faqListenA),
  (l10n.faqShareQ, l10n.faqShareA),
  (l10n.faqDeleteQ, l10n.faqDeleteA),
];

/// Aide et support (planche 7, écran 16) : questions fréquentes avec
/// recherche, contact, signalement d'un problème.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final version = ref.watch(appVersionProvider).value ?? '';
    final words = _query.toLowerCase().split(' ').where((w) => w.isNotEmpty);
    final entries = [
      for (final e in faq(l10n))
        if (words.every((w) => '${e.$1} ${e.$2}'.toLowerCase().contains(w))) e,
    ];
    return _SettingsPage(
      title: l10n.help,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: l10n.helpSearchHint,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        ListSectionHeader(l10n.faqTitle),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(LadSpace.md),
            child: Text(l10n.helpNoAnswer),
          ),
        for (final (question, answer) in entries)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: LadSpace.md),
            expandedAlignment: Alignment.centerLeft,
            title: Text(question),
            children: [Text(answer)],
          ),
        const SizedBox(height: LadSpace.lg),
        ListSectionHeader(l10n.contactUs),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mail_outline),
          title: Text(l10n.contactUs),
          subtitle: const Text(contactEmail),
          onTap: () => openExternal(context, contactUri(l10n.appTitle)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.report_outlined),
          title: Text(l10n.reportProblem),
          subtitle: Text(l10n.reportProblemHint),
          onTap: () => openExternal(
            context,
            contactUri(
              l10n.reportProblem,
              l10n.reportProblemBody(version, defaultTargetPlatform.name),
            ),
          ),
        ),
      ],
    );
  }
}

/// À propos (planche 7, écran 15) : logo, version, note du recueil, mentions,
/// licences, contact.
class AppAboutScreen extends ConsumerWidget {
  const AppAboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final version = ref.watch(appVersionProvider).value;
    return _SettingsPage(
      title: l10n.about,
      children: [
        const SizedBox(height: LadSpace.lg),
        const Center(child: WheatEar(size: 48)),
        const SizedBox(height: LadSpace.md),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: LadTheme.textStyle(LadTypeScale.title, p.text),
        ),
        Text(
          l10n.appTagline,
          textAlign: TextAlign.center,
          style: LadTheme.textStyle(LadTypeScale.caption, p.textSecondary),
        ),
        if (version != null)
          Text(
            l10n.versionLabel(version),
            textAlign: TextAlign.center,
            style: LadTheme.textStyle(LadTypeScale.caption, p.textSecondary),
          ),
        const SizedBox(height: LadSpace.xl),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(l10n.aboutHymnal),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/plus/a-propos/recueil'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(l10n.licenses),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.appTitle,
            applicationVersion: version,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mail_outline),
          title: Text(l10n.contactUs),
          subtitle: const Text(contactEmail),
          onTap: () => openExternal(context, contactUri(l10n.appTitle)),
        ),
      ],
    );
  }
}
