import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../catalog/catalog_models.dart';
import '../catalog/published_hymn.dart';
import 'theme.dart';
import 'tokens.g.dart';

/// Accès aux couleurs du thème courant : `context.lad.gold`.
extension LadContext on BuildContext {
  LadPalette get lad => Theme.of(this).extension<LadColors>()!.palette;
}

/// Lecture vocale d'un numéro : « 37bis » → « 37 bis ».
String spokenNumber(String label) => label.replaceFirstMapped(
  RegExp(r'(\d+)(bis|ter)$'),
  (m) => '${m[1]} ${m[2]}',
);

/// Affichage d'un numéro en chiffres techniques, sur trois chiffres au moins :
/// « 37bis » → « 037bis ». Purement visuel : la lecture vocale, la recherche
/// et le partage utilisent le numéro imprimé.
String displayNumber(String label) =>
    label.replaceFirstMapped(RegExp(r'^\d+'), (m) => m[0]!.padLeft(3, '0'));

// ----------------------------------------------------------------- l'épi

/// Épi de blé stylisé, élément identitaire (provisoire, en attendant le
/// tracé vectoriel de la couverture fourni par le propriétaire).
class WheatEar extends StatelessWidget {
  const WheatEar({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(size * 0.5, size),
      painter: _WheatPainter(color ?? context.lad.gold),
    ),
  );
}

class _WheatPainter extends CustomPainter {
  _WheatPainter(this.color);

  final Color color;

  /// Grain en amande dont la base est en (0, 0) et la pointe vers le haut.
  static Path _grain(double length, double width) => Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(-width, -length * 0.45, 0, -length)
    ..quadraticBezierTo(width, -length * 0.45, 0, 0)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Tige
    canvas.drawLine(
      Offset(cx, h),
      Offset(cx, h * 0.2),
      stroke..strokeWidth = math.max(1, h * 0.03),
    );

    // Grains par paires, inclinés vers l'extérieur, plus petits vers le haut,
    // chacun prolongé d'une fine barbe.
    const rows = 5;
    for (var i = 0; i < rows; i++) {
      final t = i / (rows - 1);
      final y = h * (0.74 - t * 0.46);
      final length = h * (0.2 - t * 0.06);
      for (final side in [-1.0, 1.0]) {
        canvas
          ..save()
          ..translate(cx, y)
          ..rotate(side * 0.42)
          ..drawPath(_grain(length, length * 0.36), fill)
          ..drawLine(
            Offset(0, -length),
            Offset(0, -length * 1.55),
            stroke..strokeWidth = math.max(0.6, h * 0.012),
          )
          ..restore();
      }
    }
    // Grain sommital et sa barbe
    canvas
      ..save()
      ..translate(cx, h * 0.22)
      ..drawPath(_grain(h * 0.13, h * 0.045), fill)
      ..drawLine(Offset(0, -h * 0.13), Offset(0, -h * 0.21), stroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_WheatPainter old) => old.color != color;
}

/// Séparateur : petit épi puis filet de 1 px (écho du « ✤ » du livre).
class WheatDivider extends StatelessWidget {
  const WheatDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: LadSpace.xl),
    child: Row(
      children: [
        const WheatEar(size: 16),
        const SizedBox(width: LadSpace.md),
        Expanded(
          child: Container(
            height: LadStroke.hairline,
            color: context.lad.hairline,
          ),
        ),
      ],
    ),
  );
}

/// Trait d'accent doré, court, sous un titre.
class AccentRule extends StatelessWidget {
  const AccentRule({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: LadSpace.xxl,
    height: LadStroke.accent,
    color: context.lad.gold,
  );
}

/// Petit intitulé technique en capitales espacées (« CANTIQUE DU JOUR »).
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: LadTheme.textStyle(
      LadTypeScale.overline,
      color ?? context.lad.textSecondary,
    ),
  );
}

// ------------------------------------------------------------- en-tête

/// Numéro et titre d'un cantique, tels qu'imprimés.
class HymnHeader extends StatelessWidget {
  const HymnHeader({super.key, required this.hymn});

  final PublishedHymn hymn;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Semantics(
      header: true,
      label: 'Cantique ${spokenNumber(hymn.numberLabel)}, ${hymn.title}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayNumber(hymn.numberLabel),
            style: LadTheme.textStyle(LadTypeScale.hymnNumber, p.goldText),
          ),
          const SizedBox(height: LadSpace.sm),
          Text(
            hymn.title,
            style: LadTheme.textStyle(LadTypeScale.title, p.text),
          ),
          const SizedBox(height: LadSpace.lg),
          const AccentRule(),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- paroles

/// Une section (strophe ou refrain) avec la taille de lecture choisie.
/// Le refrain est en retrait, plus appuyé, souligné d'un filet doré (la police
/// des paroles n'a pas d'italique). Les marqueurs « (bis) » restent visibles,
/// plus discrets, en chiffres techniques.
class SectionBlock extends StatelessWidget {
  const SectionBlock({
    super.key,
    required this.section,
    required this.fontSize,
  });

  final HymnSection section;
  final double fontSize;

  bool get _isRefrain => section.type == SectionType.refrain;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final weight = _isRefrain ? FontWeight.w500 : LadTypeScale.lyrics.weight;
    final base = LadTheme.textStyle(LadTypeScale.lyrics, p.text).copyWith(
      fontSize: fontSize,
      fontWeight: weight,
      fontVariations: LadTheme.variations(LadFonts.lyrics, weight, fontSize),
    );
    final markerSize =
        fontSize * LadTypeScale.marker.size / LadTypeScale.lyrics.size;
    final marker = LadTheme.textStyle(LadTypeScale.marker, p.textSecondary)
        .copyWith(
          fontSize: markerSize,
          height: base.height! * fontSize / markerSize,
        );

    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in section.lines)
          Text.rich(
            _lineSpan(line, base, marker),
            semanticsLabel: line.repeat == null
                ? line.text
                : '${line.text.substring(0, line.text.length - line.repeat!.marker.length).trimRight()}, '
                      '${line.repeat!.count == 2
                          ? 'deux fois'
                          : line.repeat!.count == 3
                          ? 'trois fois'
                          : '${line.repeat!.count} fois'}',
          ),
      ],
    );

    if (!_isRefrain) return lines;
    return Semantics(
      label: 'Refrain',
      child: Container(
        padding: const EdgeInsets.only(left: LadSpace.lg),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: p.gold, width: LadStroke.refrainRule),
          ),
        ),
        child: lines,
      ),
    );
  }

  static InlineSpan _lineSpan(HymnLine line, TextStyle base, TextStyle marker) {
    final repeat = line.repeat;
    if (repeat == null || !line.text.trimRight().endsWith(repeat.marker)) {
      return TextSpan(text: line.text, style: base);
    }
    final at = line.text.lastIndexOf(repeat.marker);
    return TextSpan(
      children: [
        TextSpan(text: line.text.substring(0, at), style: base),
        TextSpan(text: line.text.substring(at), style: marker),
      ],
    );
  }
}

// -------------------------------------------------------------- listes

/// Ligne de cantique dans une liste : numéro, titre, premier vers s'il diffère.
class HymnListTile extends StatelessWidget {
  const HymnListTile({
    super.key,
    required this.hymn,
    this.excerpt,
    required this.onTap,
  });

  final HymnSummary hymn;

  /// Vers à afficher sous le titre (résultat de recherche dans les paroles).
  final String? excerpt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final subtitle =
        excerpt ??
        (hymn.openingLine != null && !hymn.openingLine!.startsWith(hymn.title)
            ? hymn.openingLine
            : null);
    return Semantics(
      button: true,
      label:
          'Cantique ${spokenNumber(hymn.numberLabel)}, ${hymn.title}${subtitle == null ? '' : ', $subtitle'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LadTouchTarget.min + LadSpace.md,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LadSpace.lg,
              vertical: LadSpace.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: LadSpace.huge,
                  child: Text(
                    displayNumber(hymn.numberLabel),
                    style: LadTheme.textStyle(
                      LadTypeScale.listNumber,
                      p.goldText,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hymn.title,
                        style: LadTheme.textStyle(LadTypeScale.body, p.text),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LadTheme.textStyle(
                            LadTypeScale.label,
                            p.textSecondary,
                          ).copyWith(fontFamily: LadFonts.lyrics),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Titre de groupe dans une liste (« Titres », « A »…).
class ListSectionHeader extends StatelessWidget {
  const ListSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        LadSpace.lg,
        LadSpace.xl,
        LadSpace.lg,
        LadSpace.xs,
      ),
      child: Overline(text),
    ),
  );
}

// --------------------------------------------------------------- états

/// État vide, sans résultat ou d'erreur : message sobre, action facultative.
class MessageState extends StatelessWidget {
  const MessageState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LadSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WheatEar(size: 36),
            const SizedBox(height: LadSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: LadTheme.textStyle(LadTypeScale.headline, p.text),
            ),
            if (message != null) ...[
              const SizedBox(height: LadSpace.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: LadTheme.textStyle(LadTypeScale.body, p.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: LadSpace.xl),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
