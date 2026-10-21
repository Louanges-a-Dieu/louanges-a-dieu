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

/// Surtitre en capitales espacées, or patiné (« CANTIQUE DU JOUR »).
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: LadTheme.textStyle(
      LadTypeScale.overline,
      color ?? context.lad.goldText,
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
      container: true,
      header: true,
      label: 'Cantique ${spokenNumber(hymn.numberLabel)}, ${hymn.title}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hymn.numberLabel,
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
/// Le refrain est en retrait, en italique (comme dans le livre), souligné d'un
/// filet doré. Les marqueurs « (bis) » restent visibles, plus discrets.
class SectionBlock extends StatelessWidget {
  const SectionBlock({
    super.key,
    required this.section,
    required this.fontSize,
    this.showName = false,
    this.fontFamily = LadFonts.lyrics,
    this.lineSpacing = 1.0,
  });

  final HymnSection section;
  final double fontSize;

  /// Police des paroles (réglage de lecture) et interligne relatif.
  final String fontFamily;
  final double lineSpacing;

  /// Affiche le nom de la section au-dessus (« Refrain », « Couplet 2 ») ;
  /// un couplet sans numéro imprimé n'est pas étiqueté (pas de « Couplet »
  /// répété à chaque strophe).
  final bool showName;

  bool get _named =>
      showName && (section.type != SectionType.verse || section.number != null);

  bool get _isRefrain => section.type == SectionType.refrain;

  String get _name => sectionName(section.type, section.number);

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final base = LadTheme.textStyle(LadTypeScale.lyrics, p.text).copyWith(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: LadTypeScale.lyrics.height * lineSpacing,
      fontStyle: _isRefrain ? FontStyle.italic : null,
      fontVariations: LadTheme.variations(
        fontFamily,
        LadTypeScale.lyrics.weight,
        fontSize,
      ),
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
        if (_named) ...[
          ExcludeSemantics(child: Overline(_name)),
          const SizedBox(height: LadSpace.sm),
        ],
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

    // Un nœud d'accessibilité par section, annoncé par son nom.
    if (!_isRefrain) {
      return Semantics(
        container: true,
        label: _named ? _name : null,
        child: lines,
      );
    }
    return Semantics(
      container: true,
      label: _name,
      child: Container(
        padding: const EdgeInsets.only(left: LadSpace.lg),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: p.goldLight, width: LadStroke.refrainRule),
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

/// Ligne de cantique dans une liste : carte fine avec numéro, titre serif,
/// premier vers s'il diffère (ou extrait trouvé) et action facultative
/// (favori, menu) hors de la zone d'ouverture.
class HymnListTile extends StatelessWidget {
  const HymnListTile({
    super.key,
    required this.hymn,
    this.excerpt,
    required this.onTap,
    this.trailing,
    this.margin = defaultMargin,
  });

  final HymnSummary hymn;

  /// Vers à afficher sous le titre (résultat de recherche dans les paroles).
  final String? excerpt;
  final VoidCallback onTap;

  /// Action propre à la ligne (cœur, menu), annoncée séparément.
  final Widget? trailing;

  /// Marges autour de la ligne.
  final EdgeInsetsGeometry margin;

  /// Marges d'une ligne dans une liste pleine largeur.
  static const defaultMargin = EdgeInsets.symmetric(
    horizontal: LadSpace.lg,
    vertical: LadSpace.xs,
  );

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final subtitle =
        excerpt ??
        (hymn.openingLine != null && !hymn.openingLine!.startsWith(hymn.title)
            ? hymn.openingLine
            : null);
    return Padding(
      padding: margin,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LadRadius.md),
          side: BorderSide(color: p.hairline, width: LadStroke.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
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
                      padding: EdgeInsets.fromLTRB(
                        LadSpace.md,
                        LadSpace.sm + 2,
                        trailing == null ? LadSpace.md : 0,
                        LadSpace.sm + 2,
                      ),
                      child: Row(
                        children: [
                          HymnNumberBadge(hymn.numberLabel),
                          const SizedBox(width: LadSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hymn.title,
                                  style: LadTheme.textStyle(
                                    LadTypeScale.listTitle,
                                    p.text,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: LadSpace.xxs),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: LadTheme.textStyle(
                                      LadTypeScale.caption,
                                      p.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Onglets-filtres en pilules (« Par numéro », « A–Z ») ; même comportement
/// que [TabBar] (glissement, état conservé).
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const PillTabBar({
    super.key,
    required this.tabs,
    this.padding = const EdgeInsets.fromLTRB(
      LadSpace.lg,
      0,
      LadSpace.lg,
      LadSpace.md,
    ),
  });

  final List<String> tabs;
  final EdgeInsetsGeometry padding;

  @override
  Size get preferredSize =>
      const Size.fromHeight(LadTouchTarget.min + LadSpace.md);

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final label = LadTheme.textStyle(LadTypeScale.label, p.text);
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(LadRadius.pill),
            border: Border.all(color: p.hairline, width: LadStroke.hairline),
          ),
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerHeight: 0,
            padding: const EdgeInsets.all(LadSpace.xxs + 1),
            labelPadding: const EdgeInsets.symmetric(horizontal: LadSpace.lg),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: p.goldText,
              borderRadius: BorderRadius.circular(LadRadius.pill),
            ),
            labelColor: p.surface,
            unselectedLabelColor: p.text,
            labelStyle: label.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: label,
            splashBorderRadius: BorderRadius.circular(LadRadius.pill),
            tabs: [
              for (final t in tabs)
                Tab(height: LadTouchTarget.min - 8, text: t),
            ],
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
    // Défile quand la place manque (petit écran, grand texte, onglets).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 0,
          ),
          child: Center(child: _content(p)),
        ),
      ),
    );
  }

  Widget _content(LadPalette p) => Padding(
    padding: const EdgeInsets.all(LadSpace.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WheatEar(size: 36),
        const SizedBox(height: LadSpace.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: LadTheme.textStyle(LadTypeScale.sectionTitle, p.text),
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
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

/// Chargement discret, sans faux pourcentage.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: LadSpace.xl,
            child: CircularProgressIndicator(strokeWidth: LadStroke.accent),
          ),
          if (label != null) ...[
            const SizedBox(height: LadSpace.md),
            Text(
              label!,
              style: LadTheme.textStyle(
                LadTypeScale.caption,
                context.lad.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

// ------------------------------------------------------- briques d'écran

/// Numéro de cantique dans un petit bloc ivoire-or, tel qu'imprimé
/// (« 37bis », « 1138 »). La lecture vocale est portée par le parent.
class HymnNumberBadge extends StatelessWidget {
  const HymnNumberBadge(this.numberLabel, {super.key});

  final String numberLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(
          minWidth: LadSpace.xxxl + LadSpace.xs,
          maxWidth: LadSpace.huge + LadSpace.sm,
          minHeight: LadSpace.xxl + LadSpace.sm,
        ),
        padding: const EdgeInsets.symmetric(horizontal: LadSpace.xs + 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surfaceWarm,
          borderRadius: BorderRadius.circular(LadRadius.sm),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            numberLabel,
            maxLines: 1,
            style: LadTheme.textStyle(LadTypeScale.listNumber, p.goldText),
          ),
        ),
      ),
    );
  }
}

/// En-tête d'écran éditorial : surtitre doré, titre serif, sous-titre discret.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Overline(eyebrow!),
                const SizedBox(height: LadSpace.xs + 2),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: LadTheme.textStyle(LadTypeScale.title, p.text),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: LadSpace.xs),
                Text(
                  subtitle!,
                  style: LadTheme.textStyle(
                    LadTypeScale.label,
                    p.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: LadSpace.md),
          trailing!,
        ],
      ],
    );
  }
}

/// Champ de recherche commun. Avec [onTap] et sans [controller] : simple
/// entrée qui ouvre l'écran de recherche.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  static const _minHeight = LadTouchTarget.min + LadSpace.sm;

  @override
  Widget build(BuildContext context) {
    final p = context.lad;
    final icon = Icon(Icons.search, color: p.gold);
    if (controller == null) {
      return Semantics(
        button: true,
        label: hint,
        excludeSemantics: true,
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LadRadius.md),
            side: BorderSide(color: p.hairline, width: LadStroke.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: LadSpace.lg),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: LadSpace.md),
                    Expanded(
                      child: Text(
                        hint,
                        style: LadTheme.textStyle(
                          LadTypeScale.body,
                          p.textSecondary,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon,
          suffixIcon: onClear == null
              ? null
              : ListenableBuilder(
                  listenable: controller!,
                  builder: (context, _) => controller!.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .deleteButtonTooltip,
                          icon: const Icon(Icons.close),
                          onPressed: onClear,
                        ),
                ),
        ),
      ),
    );
  }
}

/// Grande carte éditoriale sur photo chaude (accueil, fiche cantique) : voile
/// brun pour garantir la lisibilité, contenu en clair.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.image,
    required this.child,
    this.minHeight = 220,
    this.imageAlignment = Alignment.center,
    this.padding = const EdgeInsets.all(LadSpace.xl),
  });

  /// Photo embarquée (`assets/images/`, registre : docs/ownership/assets.md).
  final String image;
  final Widget child;
  final double minHeight;
  final Alignment imageAlignment;
  final EdgeInsetsGeometry padding;

  /// Couleurs du contenu, communes aux thèmes : la carte est toujours sombre.
  static const ink = LadPalette.projection;

  @override
  Widget build(BuildContext context) {
    final veil = LadPalette.light.text;
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: veil,
        borderRadius: BorderRadius.circular(LadRadius.xl),
        boxShadow: LadTheme.softShadow(context.lad),
        image: DecorationImage(
          image: AssetImage(image),
          fit: BoxFit.cover,
          alignment: imageAlignment,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              veil.withValues(alpha: 0.92),
              veil.withValues(alpha: 0.72),
              veil.withValues(alpha: 0.28),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: ink.text),
            child: IconTheme.merge(
              data: IconThemeData(color: ink.text),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Limite la largeur d'une ligne de liste sur tablette, centrée.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = 860});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
