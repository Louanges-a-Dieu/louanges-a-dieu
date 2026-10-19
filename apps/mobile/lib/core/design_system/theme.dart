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
/// Direction « clair net » (2026-10-19) : blanc froid, noir profond, angles
/// nets, filets de 1 px, aucune ombre ; polices géométriques, numéros en
/// chiffres techniques ; l'or reste l'unique accent.
abstract final class LadTheme {
  static ThemeData get light => _build(LadPalette.light, Brightness.light);
  static ThemeData get dark => _build(LadPalette.dark, Brightness.dark);
  static ThemeData get projection =>
      _build(LadPalette.projection, Brightness.dark);

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
      fontFeatures: family == LadProjectionFonts.display
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
      primary: p.text,
      onPrimary: p.background,
      secondary: p.gold,
      onSecondary: p.text,
      error: p.error,
      onError: p.background,
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.background,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surface,
      surfaceContainerHighest: p.surface,
      secondaryContainer: p.surface,
      onSecondaryContainer: p.text,
      inverseSurface: p.text,
      onInverseSurface: p.background,
      outline: p.hairline,
      outlineVariant: p.hairline,
      shadow: Colors.transparent,
    );
    final label = textStyle(LadTypeScale.label, p.text);
    const sharp = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(LadRadius.sm)),
    );
    final hairline = BorderSide(color: p.hairline, width: LadStroke.hairline);
    const buttonSize = Size(LadTouchTarget.min, LadTouchTarget.min);
    const buttonPadding = EdgeInsets.symmetric(horizontal: LadSpace.lg);
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LadRadius.sm),
      borderSide: hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      fontFamily: LadFonts.ui,
      splashFactory: InkRipple.splashFactory,
      textTheme: TextTheme(
        displayLarge: textStyle(LadTypeScale.display, p.text),
        titleLarge: textStyle(LadTypeScale.title, p.text),
        titleMedium: textStyle(LadTypeScale.headline, p.text),
        headlineSmall: textStyle(LadTypeScale.headline, p.text),
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
        titleTextStyle: textStyle(LadTypeScale.headline, p.text),
        shape: Border(bottom: hairline),
      ),
      dividerTheme: DividerThemeData(
        color: p.hairline,
        thickness: LadStroke.hairline,
        space: LadSpace.xl,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: LadTouchTarget.min + LadSpace.xl,
        indicatorColor: p.surface,
        indicatorShape: sharp,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textStyle(
            LadTypeScale.caption,
            states.contains(WidgetState.selected) ? p.text : p.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.text
                : p.textSecondary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.text,
          foregroundColor: p.background,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: sharp,
          textStyle: label,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: sharp,
          side: BorderSide(color: p.text, width: LadStroke.hairline),
          textStyle: label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: buttonSize,
          shape: sharp,
          textStyle: label,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.text, shape: sharp),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.text,
        foregroundColor: p.background,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: sharp,
        extendedTextStyle: label,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: field,
        enabledBorder: field,
        focusedBorder: field.copyWith(
          borderSide: BorderSide(color: p.text, width: LadStroke.hairline),
        ),
        labelStyle: textStyle(LadTypeScale.label, p.textSecondary),
        hintStyle: textStyle(LadTypeScale.body, p.textSecondary),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        titleTextStyle: textStyle(LadTypeScale.body, p.text),
        subtitleTextStyle: textStyle(LadTypeScale.caption, p.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.background,
        side: hairline,
        shape: sharp,
        labelStyle: textStyle(LadTypeScale.caption, p.text),
      ),
      cardTheme: CardThemeData(
        color: p.background,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LadRadius.md),
          side: hairline,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LadRadius.md),
          side: hairline,
        ),
        titleTextStyle: textStyle(LadTypeScale.headline, p.text),
        contentTextStyle: textStyle(LadTypeScale.body, p.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: p.hairline,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(LadRadius.lg),
          ),
          side: hairline,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LadRadius.md),
          side: hairline,
        ),
        textStyle: textStyle(LadTypeScale.body, p.text),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: textStyle(LadTypeScale.label, p.background),
        actionTextColor: p.gold,
        elevation: 0,
        shape: sharp,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.text,
        unselectedLabelColor: p.textSecondary,
        labelStyle: label,
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
              ? p.background
              : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.text : p.surface,
        ),
        trackOutlineColor: WidgetStatePropertyAll(p.hairline),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.text,
        inactiveTrackColor: p.hairline,
        thumbColor: p.text,
        overlayColor: p.gold.withValues(alpha: 0.12),
        trackHeight: LadStroke.accent,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(LadRadius.sm)),
        ),
        side: BorderSide(color: p.textSecondary, width: LadStroke.hairline),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.text,
        linearTrackColor: p.hairline,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [LadColors(p)],
    );
  }
}
