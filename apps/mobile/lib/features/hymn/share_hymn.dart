import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/catalog/published_hymn.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/sharing/hymn_text.dart';
import '../../l10n/generated/app_localizations.dart';

/// Feuille « Partager le cantique » : en image (couverture et premier
/// couplet, aperçu visible), en texte, ou copie des paroles. WhatsApp,
/// e-mail… passent par le partage du système.
Future<void> showShareHymn(BuildContext context, PublishedHymn hymn) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ShareSheet(hymn: hymn),
    );

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.hymn});

  final PublishedHymn hymn;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _card = GlobalKey();
  bool _busy = false;

  PublishedHymn get hymn => widget.hymn;
  String get _subject => '${hymn.numberLabel} — ${hymn.title}';

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final name = 'louanges-a-dieu-${hymn.numberLabel}.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              png!.buffer.asUint8List(),
              mimeType: 'image/png',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          subject: _subject,
          text: 'Louanges à Dieu, n° ${hymn.numberLabel}',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText() => SharePlus.instance.share(
    ShareParams(text: hymnShareText(hymn), subject: _subject),
  );

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: hymnShareText(hymn)));
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.lyricsCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    Widget item(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback? onTap,
    ) => ListTile(
      leading: Icon(icon, color: p.goldText),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: p.textSecondary),
      onTap: onTap,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.lg,
                0,
                LadSpace.lg,
                LadSpace.md,
              ),
              child: Text(
                l10n.shareHymn,
                style: LadTheme.textStyle(LadTypeScale.sectionTitle, p.text),
              ),
            ),
            Center(
              child: Semantics(
                image: true,
                label: l10n.shareImagePreview,
                excludeSemantics: true,
                child: RepaintBoundary(
                  key: _card,
                  child: ShareCard(hymn: hymn),
                ),
              ),
            ),
            const SizedBox(height: LadSpace.md),
            item(
              Icons.image_outlined,
              l10n.shareAsImage,
              l10n.shareAsImageSubtitle,
              _busy ? null : _shareImage,
            ),
            item(
              Icons.notes,
              l10n.shareAsText,
              l10n.shareAsTextSubtitle,
              _shareText,
            ),
            item(
              Icons.copy_outlined,
              l10n.copyLyrics,
              l10n.copyLyricsSubtitle,
              _copy,
            ),
            const SizedBox(height: LadSpace.sm),
          ],
        ),
      ),
    );
  }
}

/// Carte partagée en image : bandeau (numéro, titre), premier couplet, source.
/// Toujours en thème clair, quelle que soit l'apparence de l'app.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.hymn});

  final PublishedHymn hymn;

  /// Au-delà, le couplet est coupé et suivi de « … ».
  static const maxLines = 8;
  static const width = 340.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const ink = HeroCard.ink;
    const p = LadPalette.light;
    final lines =
        hymn.sections.firstOrNull?.lines.map((l) => l.text).toList() ??
        const <String>[];
    final shown = lines.take(maxLines).toList();
    final lyrics = LadTheme.textStyle(
      LadTypeScale.lyrics,
      p.text,
    ).copyWith(fontSize: 17);

    return Theme(
      data: LadTheme.light,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(LadRadius.xl),
          border: Border.all(color: p.hairline, width: LadStroke.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroCard(
              image: 'assets/images/banner_wheat_ears.jpg',
              minHeight: 0,
              padding: const EdgeInsets.all(LadSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Overline(l10n.appTitle, color: ink.goldText),
                  const SizedBox(height: LadSpace.sm),
                  Text(
                    hymn.numberLabel,
                    style: LadTheme.textStyle(
                      LadTypeScale.display,
                      ink.goldText,
                    ),
                  ),
                  Text(
                    hymn.title,
                    style: LadTheme.textStyle(LadTypeScale.title, ink.text),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.xl,
                LadSpace.xl,
                LadSpace.xl,
                LadSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in shown) Text(line, style: lyrics),
                  if (lines.length > shown.length) Text('…', style: lyrics),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LadSpace.xl,
                0,
                LadSpace.xl,
                LadSpace.lg,
              ),
              child: Row(
                children: [
                  WheatEar(size: 16, color: p.gold),
                  const SizedBox(width: LadSpace.sm),
                  Flexible(
                    child: Text(
                      l10n.shareCardSource(hymn.numberLabel),
                      style: LadTheme.textStyle(
                        LadTypeScale.caption,
                        p.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
