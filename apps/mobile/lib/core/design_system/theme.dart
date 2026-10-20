import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Couleurs du design system accessibles depuis les widgets :
/// `Theme.of(context).extension<LadColors>()!.palette`.
@immutable
final class LadColors extends ThemeExtension<LadColors> {
  const LadColors(this.palette);

  final LadPalette palette;

  @override
  LadColors copyWith({LadPalette? palette}) =>
      LadColors(palette ?? this.palette);

  @override
  LadColors lerp(LadColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Thèmes construits exclusivement à partir des tokens (ADR-014).
///
/// Direction « Le recueil vivant » (2026-10-20) : fond ivoire, brun profond,
/// or patiné pour les accents et l'action principale ; rayons modérés, filets
/// fins, ombre douce réservée aux cartes mises en avant ; titres et paroles en
/// serif, interface en sans-serif. Thème sombre et projection : vert-noir
/// immersif.
abstract final class LadTheme {
  static ThemeData get light => _build(LadPalette.light, Brightness.light);
  static ThemeData get dark => _build(LadPalette.dark, Brightness.dark);
  static ThemeData get projection =>
      _build(LadPalette.projection, Brightness.dark);

  /// Ombre douce des cartes mises en avant (héro, cantique du jour).
  static List<BoxShadow> softShadow(LadPalette p) => [
    BoxShadow(
      color: p.text.withValues(alpha: LadShadow.softOpacity),
      offset: const Offset(0, LadShadow.softOffsetY),
      blurRadius: LadShadow.softBlur,
    ),
  ];

  /// Famille de polices d'un rôle ; [projection] : polices de l'écran projeté
  /// (aperçu du pilote, qui doit rester fidèle).
  static String fontFamily(LadFontRole role, {bool projection = false}) =>
      projection
      ? switch (role) {
          LadFontRole.display => LadProjectionFonts.display,
          LadFontRole.lyrics => LadProjectionFonts.lyrics,
          LadFontRole.ui => LadProjectionFonts.ui,
          LadFontRole.numeric => LadProjectionFonts.numeric,
        }
      : switch (role) {
          LadFontRole.display => LadFonts.display,
          LadFontRole.lyrics => LadFonts.lyrics,
          LadFontRole.ui => LadFonts.ui,
          LadFontRole.numeric => LadFonts.numeric,
        };

  static TextStyle textStyle(
    LadTextSpec spec,
    Color color, {
    bool projection = false,
  }) {
    final family = fontFamily(spec.role, projection: projection);
    return TextStyle(
      fontFamily: family,
      fontSize: spec.size,
      height: spec.height,
      fontWeight: spec.weight,
      letterSpacing: spec.letterSpacing * spec.size,
      fontVariations: variations(family, spec.weight, spec.size),
      // Chiffres alignés : les chiffres elzéviriens par défaut de Cormorant
      // rendent les numéros de cantique ambigus (« 991 » lu « 99I »).
      fontFeatures:
          family == LadFonts.display || family == LadProjectionFonts.display
          ? const [FontFeature.liningFigures()]
          : null,
      color: color,
    );
  }

  /// Polices à axe de taille optique (celles de l'écran projeté).
  static const _opticalSize = {
    LadProjectionFonts.lyrics,
    LadProjectionFonts.ui,
  };

  /// Polices variables : la graisse (et, si la police l'a, la taille optique)
  /// doit être transmise explicitement au moteur de rendu.
  static List<FontVariation> variations(
    String family,
    FontWeight weight,
    double size,
  ) => [
    FontVariation.weight(weight.value.toDouble()),
    if (_opticalSize.contains(family))
      FontVariation('opsz', size.clamp(12, 72).toDouble()),
  ];

  static ThemeData _build(LadPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.goldText,
      onPrimary: p.surface,
      primaryContainer: p.goldPale,
      onPrimaryContainer: p.text,
      secondary: p.gold,
      onSecondary: p.surface,
      secondaryContainer: p.goldPale,
      onSecondaryContainer: p.text,
      error: p.error,
      onError: p.surface,
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceWarm,
      surfaceContainerHighest: p.surfaceWarm,
      inverseSurface: p.text,
      onInverseSurface: p.background,
      outline: p.hairline,
      outlineVariant: p.hairline,
      shadow: p.text,
      surfaceTint: Colors.transparent,
    );
    final label = textStyle(LadTypeScale.label, p.text);
    RoundedRectangleBorder rounded(double radius, [BorderSide? side]) =>
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: side ?? BorderSide.none,
        );
    final hairline = BorderSide(color: p.hairline, width: LadStroke.hairline);
    final control = rounded(LadRadius.md);
    const buttonSize = Size(LadTouchTarget.min, LadTouchTarget.min);
    const buttonPadding = EdgeInsets.symmetric(horizontal: LadSpace.lg + 2);
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LadRadius.md),
      borderSide: hairline,
    );
    final serifTitle = textStyle(LadTypeScale.sectionTitle, p.text);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      fontFamily: LadFonts.ui,
      splashFactory: InkRipple.splashFactory,
      splashColor: p.gold.withValues(alpha: 0.10),
      highlightColor: p.gold.withValues(alpha: 0.06),
      hoverColor: p.gold.withValues(alpha: 0.06),
      focusColor: p.gold.withValues(alpha: 0.14),
      textTheme: TextTheme(
        displayLarge: textStyle(LadTypeScale.display, p.text),
        titleLarge: textStyle(LadTypeScale.title, p.text),
        titleMedium: textStyle(LadTypeScale.headline, p.text),
        headlineSmall: serifTitle,
        bodyLarge: textStyle(LadTypeScale.body, p.text),
        bodyMedium: textStyle(LadTypeScale.body, p.text),
        labelLarge: label,
        labelMedium: textStyle(LadTypeScale.caption, p.text),
        bodySmall: textStyle(LadTypeScale.caption, p.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: serifTitle,
        iconTheme: IconThemeData(color: p.text),
        actionsIconTheme: IconThemeData(color: p.text),
      ),
      dividerTheme: DividerThemeData(
        color: p.hairline,
        thickness: LadStroke.hairline,
        space: LadSpace.xl,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: LadTouchTarget.min + LadSpace.xl,
        indicatorColor: p.goldPale,
        indicatorShape: rounded(LadRadius.sm),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) =>
              textStyle(
                LadTypeScale.caption,
                states.contains(WidgetState.selected)
                    ? p.text
                    : p.textSecondary,
              ).copyWith(
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : null,
              ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.goldText
                : p.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surfaceWarm,
        elevation: 0,
        indicatorColor: p.goldPale,
        indicatorShape: rounded(LadRadius.sm),
        selectedIconTheme: IconThemeData(color: p.goldText),
        unselectedIconTheme: IconThemeData(color: p.textSecondary),
        selectedLabelTextStyle: label,
        unselectedLabelTextStyle: textStyle(
          LadTypeScale.label,
          p.textSecondary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.goldText,
          foregroundColor: p.surface,
          disabledBackgroundColor: p.hairline,
          disabledForegroundColor: p.textSecondary,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: control,
          textStyle: label,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: p.surface,
          foregroundColor: p.text,
          disabledForegroundColor: p.textSecondary,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: control,
          side: hairline,
          textStyle: label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.goldText,
          minimumSize: buttonSize,
          shape: control,
          textStyle: label.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: buttonSize,
          shape: control,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.goldText,
        foregroundColor: p.surface,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: rounded(LadRadius.lg),
        extendedTextStyle: label,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: field,
        enabledBorder: field,
        focusedBorder: field.copyWith(
          borderSide: BorderSide(color: p.gold, width: LadStroke.accent),
        ),
        labelStyle: textStyle(LadTypeScale.label, p.textSecondary),
        hintStyle: textStyle(LadTypeScale.body, p.textSecondary),
        prefixIconColor: p.gold,
        suffixIconColor: p.textSecondary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        titleTextStyle: textStyle(LadTypeScale.body, p.text),
        subtitleTextStyle: textStyle(LadTypeScale.caption, p.textSecondary),
        selectedColor: p.text,
        selectedTileColor: p.goldPale,
        shape: rounded(LadRadius.md),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.goldText,
        checkmarkColor: p.surface,
        side: hairline,
        shape: const StadiumBorder(),
        labelStyle: textStyle(LadTypeScale.caption, p.text),
        secondaryLabelStyle: textStyle(LadTypeScale.caption, p.surface),
        padding: const EdgeInsets.symmetric(horizontal: LadSpace.sm),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded(LadRadius.lg, hairline),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: rounded(LadRadius.xl, hairline),
        titleTextStyle: serifTitle,
        contentTextStyle: textStyle(LadTypeScale.body, p.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: p.hairline,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(LadRadius.xl),
          ),
          side: hairline,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: rounded(LadRadius.md, hairline),
        textStyle: textStyle(LadTypeScale.body, p.text),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded(LadRadius.xl),
        headerHeadlineStyle: serifTitle,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: textStyle(LadTypeScale.label, p.background),
        actionTextColor: p.goldLight,
        elevation: 0,
        shape: rounded(LadRadius.md),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.text,
        unselectedLabelColor: p.textSecondary,
        labelStyle: label.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textStyle(LadTypeScale.label, p.textSecondary),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.gold, width: LadStroke.accent),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.hairline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.surface
              : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.goldText : p.surface,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.goldText : p.hairline,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.goldText,
        inactiveTrackColor: p.hairline,
        thumbColor: p.goldText,
        overlayColor: p.gold.withValues(alpha: 0.12),
        valueIndicatorColor: p.text,
        valueIndicatorTextStyle: textStyle(LadTypeScale.label, p.background),
        trackHeight: LadStroke.accent + 1,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(LadRadius.sm / 2)),
        ),
        side: BorderSide(color: p.textSecondary, width: LadStroke.hairline),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.goldText : null,
        ),
        checkColor: WidgetStatePropertyAll(p.surface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.gold,
        linearTrackColor: p.hairline,
        circularTrackColor: Colors.transparent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(p.gold.withValues(alpha: 0.5)),
        radius: const Radius.circular(LadRadius.pill),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.text,
          borderRadius: BorderRadius.circular(LadRadius.sm),
        ),
        textStyle: textStyle(LadTypeScale.caption, p.background),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [LadColors(p)],
    );
  }
}
