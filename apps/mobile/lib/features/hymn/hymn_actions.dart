import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/env.dart';
import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/catalog/published_hymn.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';
import '../audio/audio_downloads.dart';
import '../audio/audio_screen.dart';
import '../lists/lists.dart';
import '../worship/worship.dart';
import 'share_hymn.dart';

/// Feuille « Actions » de la fiche : toutes les actions d'un cantique au même
/// endroit. Celles qui dépendent d'un enregistrement n'apparaissent que si
/// l'écoute est possible.
Future<void> showHymnActions(
  BuildContext context,
  WidgetRef ref,
  PublishedHymn hymn,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _HymnActionsSheet(hymn: hymn, host: context, hostRef: ref),
);

class _HymnActionsSheet extends ConsumerWidget {
  const _HymnActionsSheet({
    required this.hymn,
    required this.host,
    required this.hostRef,
  });

  final PublishedHymn hymn;

  /// Contexte de la fiche : les actions s'y poursuivent une fois la feuille
  /// fermée.
  final BuildContext host;
  final WidgetRef hostRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final env = ref.watch(envProvider);
    final isFavorite = ref.watch(
      favoriteIdsProvider.select(
        (ids) => ids.value?.contains(hymn.id) ?? false,
      ),
    );
    final downloads = ref.watch(audioDownloadsProvider);
    final listen = canListen(env, hymn);

    void then(void Function() action) {
      Navigator.pop(context);
      action();
    }

    Widget item(
      IconData icon,
      String title,
      String? subtitle,
      VoidCallback onTap,
    ) => ListTile(
      leading: Container(
        width: LadTouchTarget.min,
        height: LadTouchTarget.min,
        decoration: BoxDecoration(
          color: p.surfaceWarm,
          borderRadius: BorderRadius.circular(LadRadius.md),
        ),
        child: Icon(icon, color: p.goldText),
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: onTap,
    );

    final divider = Divider(
      height: LadSpace.lg,
      indent: LadSpace.lg,
      endIndent: LadSpace.lg,
      color: p.hairline,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.lg,
                0,
                LadSpace.lg,
                LadSpace.sm,
              ),
              child: Text(
                '${hymn.numberLabel} — ${hymn.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LadTheme.textStyle(LadTypeScale.sectionTitle, p.text),
              ),
            ),
            item(
              Icons.chrome_reader_mode_outlined,
              l10n.read,
              l10n.readSubtitle,
              () => then(() => host.push('/lecture/${hymn.id}')),
            ),
            if (listen)
              item(
                Icons.headphones_outlined,
                l10n.listen,
                l10n.listenSubtitle,
                () => then(() => host.push('/ecoute/${hymn.id}')),
              ),
            if (canKaraoke(env, hymn))
              item(
                Icons.mic_none,
                l10n.sing,
                l10n.singSubtitle,
                () => then(() => host.push('/karaoke/${hymn.id}')),
              ),
            item(
              Icons.cast,
              l10n.project,
              l10n.projectSubtitle,
              () => then(() => host.push('/projection?cantique=${hymn.id}')),
            ),
            divider,
            item(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              isFavorite ? l10n.removeFavorite : l10n.addFavorite,
              null,
              () => then(
                () => hostRef
                    .read(userDataRepositoryProvider)
                    .setFavorite(hymn.id, isFavorite: !isFavorite),
              ),
            ),
            item(
              Icons.playlist_add,
              l10n.addToList,
              null,
              () => then(() => showAddToList(host, hostRef, hymn.id)),
            ),
            item(
              Icons.event_note_outlined,
              l10n.addToProgram,
              null,
              () => then(() => showAddToWorship(host, hostRef, hymn.id)),
            ),
            divider,
            item(
              Icons.ios_share,
              l10n.share,
              l10n.shareSubtitle,
              () => then(() => showShareHymn(host, hymn)),
            ),
            if (listen && downloads.supported)
              item(
                Icons.download_outlined,
                l10n.audioDownload,
                l10n.downloadSubtitle,
                () => then(() {
                  for (final track in hymn.audio) {
                    downloads
                        .download(track, env.audioUrl(track.storageKey))
                        .ignore();
                  }
                  ScaffoldMessenger.of(
                    host,
                  ).showSnackBar(SnackBar(content: Text(l10n.downloadStarted)));
                }),
              ),
            const SizedBox(height: LadSpace.sm),
          ],
        ),
      ),
    );
  }
}
