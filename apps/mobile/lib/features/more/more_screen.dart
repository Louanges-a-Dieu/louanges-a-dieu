import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/preferences/preferences.dart';
import '../../core/sync/catalog_sync.dart';
import '../../l10n/generated/app_localizations.dart';

/// Onglet « Plus » : réglages, état hors connexion, à propos, licences.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs =
        ref.watch(preferencesProvider).value ?? const ReadingPreferences();
    final notifier = ref.read(preferencesProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(l10n.account),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/compte'),
          ),
          ListSectionHeader(l10n.settings),
          ListTile(
            title: Text(l10n.theme),
            trailing: DropdownButton<ThemeMode>(
              value: prefs.themeMode,
              underline: const SizedBox.shrink(),
              onChanged: (m) => m == null
                  ? null
                  : notifier.change((p) => p.copyWith(themeMode: m)),
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l10n.themeSystem),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l10n.themeLight),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l10n.themeDark),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(l10n.textSize),
            subtitle: Slider(
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
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(l10n.offlineTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/plus/hors-connexion'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.aboutHymnal),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/plus/a-propos'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.licenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            ),
          ),
        ],
      ),
    );
  }
}

/// État du recueil sur l'appareil et vérification manuelle d'une mise à jour.
class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final status = ref.watch(catalogStatusProvider).value;
    String date(DateTime? d) => d == null
        ? l10n.never
        : MaterialLocalizations.of(context).formatMediumDate(d);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offlineTitle)),
      body: ListView(
        padding: const EdgeInsets.all(LadSpace.xl),
        children: [
          Text(
            l10n.offlineStatus,
            style: LadTheme.textStyle(LadTypeScale.body, p.text),
          ),
          const SizedBox(height: LadSpace.xl),
          _Row(l10n.catalogCount, '${status?.count ?? '—'}'),
          _Row(
            l10n.catalogRelease,
            status?.releaseId == null ? '—' : '${status!.releaseId}',
          ),
          _Row(l10n.lastCheck, date(status?.lastCheck)),
          const SizedBox(height: LadSpace.xl),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(l10n.checkNow),
            onPressed: () async {
              final outcome = await refreshCatalog(ref);
              if (!context.mounted) return;
              final message = switch (outcome) {
                CatalogUpToDate() => l10n.syncUpToDate,
                CatalogUpdated() => l10n.syncUpdated,
                CatalogOffline() => l10n.syncOffline,
                CatalogUpdateRejected() => l10n.syncRejected,
                CatalogCheckSkipped() => l10n.syncSkipped,
              };
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: LadSpace.xs),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: LadTheme.textStyle(
              LadTypeScale.body,
              context.lad.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: LadTheme.textStyle(LadTypeScale.body, context.lad.text),
        ),
      ],
    ),
  );
}

/// Note liminaire du recueil, verbatim (assets/content/about_fr.json, Q-14).
final _aboutProvider = FutureProvider<List<({String text, String style})>>((
  ref,
) async {
  final json = jsonDecode(
    await rootBundle.loadString('assets/content/about_fr.json'),
  ) as Map<String, Object?>;
  return [
    for (final p
        in (json['paragraphs']! as List<Object?>).cast<Map<String, Object?>>())
      (text: p['text']! as String, style: p['style']! as String),
  ];
});

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final paragraphs = ref.watch(_aboutProvider).value ?? const [];
    final lyrics = LadTheme.textStyle(
      LadTypeScale.lyrics,
      p.text,
    ).copyWith(fontSize: LadTypeScale.body.size + 1);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutHymnal)),
      body: ListView(
        padding: const EdgeInsets.all(LadSpace.xl),
        children: [
          const Center(child: WheatEar(size: 36)),
          const SizedBox(height: LadSpace.lg),
          for (final para in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: LadSpace.md),
              child: Text(
                para.text,
                textAlign: para.style == 'heading'
                    ? TextAlign.center
                    : TextAlign.start,
                style: switch (para.style) {
                  'heading' => LadTheme.textStyle(LadTypeScale.title, p.text),
                  'italic' => lyrics.copyWith(fontStyle: FontStyle.italic),
                  _ => lyrics,
                },
              ),
            ),
        ],
      ),
    );
  }
}
