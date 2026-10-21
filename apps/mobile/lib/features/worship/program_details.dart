import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/catalog/catalog_models.dart';
import '../../core/database/app_database.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/photos.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../core/user_data/user_data_models.dart';
import '../../l10n/generated/app_localizations.dart';

/// Informations d'un programme saisies dans le formulaire.
typedef ProgramValues = ({
  String title,
  String? serviceDate,
  String? location,
  String? description,
  String? cover,
});

/// Formulaire d'un programme (planche 4, écran 8) : titre, date, lieu,
/// description, image (photo de l'app). Sans heure (décision du
/// propriétaire).
Future<ProgramValues?> showProgramForm(
  BuildContext context, {
  WorshipServiceRow? initial,
}) => showModalBottomSheet<ProgramValues>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _ProgramForm(initial: initial),
);

class _ProgramForm extends StatefulWidget {
  const _ProgramForm({this.initial});

  final WorshipServiceRow? initial;

  @override
  State<_ProgramForm> createState() => _ProgramFormState();
}

class _ProgramFormState extends State<_ProgramForm> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _location = TextEditingController(text: widget.initial?.location);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late String? _date = widget.initial?.serviceDate;
  late String? _cover = widget.initial?.cover;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _text(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop<ProgramValues>(context, (
      title: title,
      serviceDate: _date,
      location: _text(_location),
      description: _text(_description),
      cover: _cover,
    ));
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date ?? '') ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _date = date.toIso8601String().substring(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final label = LadTheme.textStyle(LadTypeScale.label, p.textSecondary);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
                widget.initial == null ? l10n.newProgram : l10n.editProgram,
                style: LadTheme.textStyle(LadTypeScale.headline, p.text),
              ),
              const SizedBox(height: LadSpace.lg),
              TextField(
                controller: _title,
                autofocus: widget.initial == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.programTitle),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: LadSpace.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _date == null
                      ? l10n.chooseDate
                      : MaterialLocalizations.of(context)
                            .formatFullDate(DateTime.parse(_date!)),
                ),
                onPressed: _pickDate,
              ),
              const SizedBox(height: LadSpace.md),
              TextField(
                controller: _location,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.locationOptional,
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: LadSpace.md),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.descriptionOptional,
                ),
              ),
              const SizedBox(height: LadSpace.lg),
              Text(l10n.imageOptional, style: label),
              const SizedBox(height: LadSpace.sm),
              Wrap(
                spacing: LadSpace.sm,
                runSpacing: LadSpace.sm,
                children: [
                  _CoverChoice(
                    label: l10n.noImage,
                    selected: _cover == null,
                    onTap: () => setState(() => _cover = null),
                  ),
                  for (final MapEntry(key: name, value: asset)
                      in appPhotos.entries)
                    _CoverChoice(
                      label: l10n.photoNumber(
                        appPhotos.keys.toList().indexOf(name) + 1,
                      ),
                      asset: asset,
                      selected: _cover == name,
                      onTap: () => setState(() => _cover = name),
                    ),
                ],
              ),
              const SizedBox(height: LadSpace.xl),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.initial == null ? l10n.create : l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverChoice extends StatelessWidget {
  const _CoverChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.asset,
  });

  final String label;
  final String? asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LadRadius.md),
        child: Container(
          width: 88,
          height: 60,
          decoration: BoxDecoration(
            color: p.surfaceWarm,
            borderRadius: BorderRadius.circular(LadRadius.md),
            border: Border.all(
              color: selected ? p.goldText : p.hairline,
              width: selected ? LadStroke.accent + 1 : LadStroke.hairline,
            ),
            image: asset == null
                ? null
                : DecorationImage(image: AssetImage(asset!), fit: BoxFit.cover),
          ),
          alignment: Alignment.center,
          child: asset == null
              ? Text(
                  label,
                  textAlign: TextAlign.center,
                  style: LadTheme.textStyle(
                    LadTypeScale.caption,
                    p.textSecondary,
                  ),
                )
              : selected
              ? const Icon(Icons.check_circle, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// Options de projection d'un programme (planche 4, écran 10).
Future<ProgramOptions?> showProgramOptions(
  BuildContext context,
  ProgramOptions initial,
) => showModalBottomSheet<ProgramOptions>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _OptionsSheet(initial: initial),
);

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({required this.initial});

  final ProgramOptions initial;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late var _options = widget.initial;
  late final _end = TextEditingController(text: widget.initial.endMessage);

  @override
  void dispose() {
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final label = LadTheme.textStyle(LadTypeScale.label, p.textSecondary);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
                l10n.projectionOptions,
                style: LadTheme.textStyle(LadTypeScale.headline, p.text),
              ),
              const SizedBox(height: LadSpace.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.showNumbers),
                value: _options.showNumbers,
                onChanged: (v) => setState(
                  () => _options = _options.copyWith(showNumbers: v),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.repeatRefrain),
                value: _options.repeatRefrain,
                onChanged: (v) => setState(
                  () => _options = _options.copyWith(repeatRefrain: v),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.transitions),
                subtitle: Text(l10n.transitionsHint),
                value: _options.transitions,
                onChanged: (v) => setState(
                  () => _options = _options.copyWith(transitions: v),
                ),
              ),
              const SizedBox(height: LadSpace.md),
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
                      selected: _options.background == value,
                      onSelected: (_) => setState(
                        () => _options = _options.copyWith(background: value),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: LadSpace.lg),
              TextField(
                controller: _end,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.endMessage,
                  hintText: l10n.endMessageHint,
                ),
              ),
              const SizedBox(height: LadSpace.xl),
              FilledButton(
                onPressed: () {
                  final end = _end.text.trim();
                  Navigator.pop(
                    context,
                    _options.copyWith(
                      endMessage: () => end.isEmpty ? null : end,
                    ),
                  );
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Élément d'un programme pour le partage : cantique ou moment libre.
typedef ProgramLine = ({HymnSummary? hymn, String? label, String? notes});

/// Texte d'un programme à partager : titre, date, lieu, description, éléments.
String programShareText(
  BuildContext context,
  WorshipServiceRow service,
  List<ProgramLine> lines,
) {
  final l10n = AppLocalizations.of(context);
  final date = service.serviceDate == null
      ? null
      : MaterialLocalizations.of(context)
            .formatFullDate(DateTime.parse(service.serviceDate!));
  var n = 0;
  return [
    service.title,
    ?date,
    ?service.location,
    ?service.description,
    '',
    for (final line in lines)
      if (line.hymn case final h?)
        '${++n}. ${h.numberLabel} — ${h.title}${line.notes == null ? '' : ' (${line.notes})'}'
      else
        '— ${line.label ?? ''} —',
    '',
    l10n.sharedFrom,
  ].join('\n');
}

/// Partage d'un programme en image (planche 4, écran 13) : carte claire avec
/// la photo du programme, ses informations et ses cantiques.
class ProgramShareCard extends StatelessWidget {
  const ProgramShareCard({
    super.key,
    required this.service,
    required this.lines,
  });

  final WorshipServiceRow service;
  final List<ProgramLine> lines;

  /// Au-delà, la liste est coupée et suivie de « … ».
  static const maxLines = 14;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const ink = HeroCard.ink;
    const p = LadPalette.light;
    final date = service.serviceDate == null
        ? null
        : MaterialLocalizations.of(context)
              .formatFullDate(DateTime.parse(service.serviceDate!));
    final shown = lines.take(maxLines).toList();
    var n = 0;
    return Theme(
      data: LadTheme.light,
      child: Container(
        width: 340,
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
              image: photoAsset(service.cover) ?? appPhotos.values.first,
              minHeight: 0,
              padding: const EdgeInsets.all(LadSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Overline(l10n.appTitle, color: ink.goldText),
                  const SizedBox(height: LadSpace.sm),
                  Text(
                    service.title,
                    style: LadTheme.textStyle(LadTypeScale.title, ink.text),
                  ),
                  if (date != null || service.location != null)
                    Text(
                      [?date, ?service.location].join(' · '),
                      style: LadTheme.textStyle(
                        LadTypeScale.caption,
                        ink.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(LadSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (service.description != null) ...[
                    Text(
                      service.description!,
                      style: LadTheme.textStyle(
                        LadTypeScale.body,
                        p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: LadSpace.md),
                  ],
                  for (final line in shown)
                    if (line.hymn case final h?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: LadSpace.xs),
                        child: Text(
                          '${++n}.  ${h.numberLabel} — ${h.title}',
                          style: LadTheme.textStyle(LadTypeScale.body, p.text),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(
                          top: LadSpace.sm,
                          bottom: LadSpace.xs,
                        ),
                        child: Overline(line.label ?? '', color: p.goldText),
                      ),
                  if (lines.length > shown.length)
                    Text(
                      '…',
                      style: LadTheme.textStyle(LadTypeScale.body, p.text),
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

/// Feuille « Partager le programme » : lien en ligne, image ou texte.
Future<void> showProgramShareChoice(
  BuildContext context, {
  required WorshipServiceRow service,
  required List<ProgramLine> lines,
  required Future<void> Function() onLink,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) =>
      _ProgramShareSheet(service: service, lines: lines, onLink: onLink),
);

class _ProgramShareSheet extends StatefulWidget {
  const _ProgramShareSheet({
    required this.service,
    required this.lines,
    required this.onLink,
  });

  final WorshipServiceRow service;
  final List<ProgramLine> lines;
  final Future<void> Function() onLink;

  @override
  State<_ProgramShareSheet> createState() => _ProgramShareSheetState();
}

class _ProgramShareSheetState extends State<_ProgramShareSheet> {
  final _card = GlobalKey();
  bool _busy = false;

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      const name = 'programme-louanges-a-dieu.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              png!.buffer.asUint8List(),
              mimeType: 'image/png',
              name: name,
            ),
          ],
          fileNameOverrides: const [name],
          subject: widget.service.title,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.lad;
    final text = programShareText(context, widget.service, widget.lines);
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
                l10n.shareProgram,
                style: LadTheme.textStyle(LadTypeScale.sectionTitle, p.text),
              ),
            ),
            item(
              Icons.link,
              l10n.shareLinkOption,
              l10n.shareLinkOptionSubtitle,
              () async {
                Navigator.pop(context);
                await widget.onLink();
              },
            ),
            item(
              Icons.image_outlined,
              l10n.shareAsImage,
              l10n.shareProgramImageSubtitle,
              _busy ? null : _shareImage,
            ),
            item(
              Icons.notes,
              l10n.shareAsText,
              l10n.shareProgramTextSubtitle,
              () => SharePlus.instance.share(
                ShareParams(text: text, subject: widget.service.title),
              ),
            ),
            item(
              Icons.copy_outlined,
              l10n.copyText,
              l10n.copyTextSubtitle,
              () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) Navigator.pop(context);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.textCopied)),
                );
              },
            ),
            const SizedBox(height: LadSpace.md),
            Center(
              child: Semantics(
                image: true,
                label: l10n.shareImagePreview,
                excludeSemantics: true,
                child: RepaintBoundary(
                  key: _card,
                  child: ProgramShareCard(
                    service: widget.service,
                    lines: widget.lines,
                  ),
                ),
              ),
            ),
            const SizedBox(height: LadSpace.lg),
          ],
        ),
      ),
    );
  }
}
