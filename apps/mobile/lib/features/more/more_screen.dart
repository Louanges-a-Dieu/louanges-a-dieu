import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/env.dart';
import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/sync/catalog_sync.dart';
import '../../l10n/generated/app_localizations.dart';
import '../audio/audio_downloads.dart';

/// Onglet « Plus » : réglages, état hors connexion, à propos, licences.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final hasAudio = ref.watch(envProvider).hasAudio;
    Widget entry(IconData icon, String title, String route) => ListTile(
      minTileHeight: LadTouchTarget.min + LadSpace.sm,
      leading: Icon(icon, color: p.gold),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        children: [
          ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                entry(Icons.account_circle_outlined, l10n.account, '/compte'),
                ListSectionHeader(l10n.settings),
                entry(
                  Icons.palette_outlined,
                  l10n.appearance,
                  '/plus/apparence',
                ),
                entry(
                  Icons.chrome_reader_mode_outlined,
                  l10n.reading,
                  '/plus/lecture',
                ),
                if (hasAudio)
                  entry(
                    Icons.headphones_outlined,
                    l10n.audioSettings,
                    '/plus/audio',
                  ),
                entry(
                  Icons.cloud_off_outlined,
                  l10n.offlineTitle,
                  '/plus/hors-connexion',
                ),
                entry(
                  Icons.shield_outlined,
                  l10n.privacy,
                  '/plus/confidentialite',
                ),
                ListSectionHeader(l10n.helpAndInfo),
                entry(Icons.help_outline, l10n.help, '/plus/aide'),
                entry(Icons.info_outline, l10n.about, '/plus/a-propos'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// État du recueil sur l'appareil et vérification manuelle d'une mise à jour.
/// Aucune barre de progression : la vérification n'a pas d'avancement
/// mesurable ; seuls l'état réel et le résultat sont affichés.
class OfflineScreen extends ConsumerStatefulWidget {
  const OfflineScreen({super.key});

  @override
  ConsumerState<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends ConsumerState<OfflineScreen> {
  bool _checking = false;
  String? _result;

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _checking = true;
      _result = null;
    });
    final outcome = await refreshCatalog(ref);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = switch (outcome) {
        CatalogUpToDate() => l10n.syncUpToDate,
        CatalogUpdated() => l10n.syncUpdated,
        CatalogOffline() => l10n.syncOffline,
        CatalogUpdateRejected() => l10n.syncRejected,
        CatalogCheckSkipped() => l10n.syncSkipped,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final status = ref.watch(catalogStatusProvider).value;
    String date(DateTime? d) => d == null
        ? l10n.never
        : MaterialLocalizations.of(context).formatMediumDate(d);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offlineTitle)),
      body: ListView(
        padding: const EdgeInsets.all(LadSpace.lg),
        children: [
          ReadableWidth(
            maxWidth: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: l10n.offlineLead,
                  subtitle: l10n.offlineStatus,
                ),
                const SizedBox(height: LadSpace.xl),
                Container(
                  padding: const EdgeInsets.all(LadSpace.lg + 4),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(LadRadius.lg),
                    border: Border.all(
                      color: p.hairline,
                      width: LadStroke.hairline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book_outlined, color: p.gold),
                          const SizedBox(width: LadSpace.sm),
                          Text(
                            l10n.offlinePanelTitle,
                            style: LadTheme.textStyle(
                              LadTypeScale.cardTitle,
                              p.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: LadSpace.md),
                      _Row(
                        l10n.catalogCount,
                        status == null
                            ? '—'
                            : NumberFormat.decimalPattern('fr')
                                  .format(status.count),
                      ),
                      _Row(
                        l10n.catalogRelease,
                        status?.releaseId == null
                            ? '—'
                            : '${status!.releaseId}',
                      ),
                      _Row(l10n.lastCheck, date(status?.lastCheck)),
                      const SizedBox(height: LadSpace.lg),
                      FilledButton.icon(
                        icon: _checking
                            ? SizedBox.square(
                                dimension: LadSpace.lg,
                                child: CircularProgressIndicator(
                                  strokeWidth: LadStroke.accent,
                                  color: p.surface,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_checking ? l10n.checking : l10n.checkNow),
                        onPressed: _checking ? null : _check,
                      ),
                      if (_result != null) ...[
                        const SizedBox(height: LadSpace.md),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _result!,
                            style: LadTheme.textStyle(
                              LadTypeScale.label,
                              p.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ref.watch(envProvider).hasAudio &&
                    ref.watch(audioDownloadsProvider).supported) ...[
                  const SizedBox(height: LadSpace.lg),
                  const _AudioDownloadsPanel(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Enregistrements téléchargés pour l'écoute sans Internet : nombre, place
/// occupée, suppression.
class _AudioDownloadsPanel extends ConsumerWidget {
  const _AudioDownloadsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final usage = ref.watch(audioDownloadsUsageProvider).value;
    final megabytes = NumberFormat(
      '0.0',
      'fr',
    ).format((usage?.bytes ?? 0) / (1024 * 1024));
    return Container(
      padding: const EdgeInsets.all(LadSpace.lg + 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(LadRadius.lg),
        border: Border.all(color: p.hairline, width: LadStroke.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.headphones_outlined, color: p.gold),
              const SizedBox(width: LadSpace.sm),
              Expanded(
                child: Text(
                  l10n.audioDownloadsTitle,
                  style: LadTheme.textStyle(LadTypeScale.cardTitle, p.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: LadSpace.md),
          Text(
            usage == null
                ? '—'
                : usage.count == 0
                ? l10n.audioDownloadsNone
                : l10n.audioDownloadsUsage(usage.count, megabytes),
            style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
          ),
          if ((usage?.count ?? 0) > 0) ...[
            const SizedBox(height: LadSpace.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.audioDownloadsDeleteAll),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.audioDownloadsDeleteAll),
                    content: Text(l10n.audioDownloadsDeleteConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.audioRemoveDownload),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await ref.read(audioDownloadsProvider).deleteAll();
                ref.invalidate(audioDownloadsUsageProvider);
              },
            ),
          ],
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
                  'italic' => lyrics.copyWith(color: p.textSecondary),
                  _ => lyrics,
                },
              ),
            ),
        ],
      ),
    );
  }
}
