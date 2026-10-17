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
abstract final class LadTheme {
  static ThemeData get light => _build(LadPalette.light, Brightness.light);
  static ThemeData get dark => _build(LadPalette.dark, Brightness.dark);
  static ThemeData get projection =>
      _build(LadPalette.projection, Brightness.dark);

  static String fontFamily(LadFontRole role) => switch (role) {
    LadFontRole.display => LadFonts.display,
    LadFontRole.lyrics => LadFonts.lyrics,
    LadFontRole.ui => LadFonts.ui,
  };

  static TextStyle textStyle(LadTextSpec spec, Color color) => TextStyle(
    fontFamily: fontFamily(spec.role),
    fontSize: spec.size,
    height: spec.height,
    fontWeight: spec.weight,
    color: color,
  );

  static ThemeData _build(LadPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.goldText,
      onPrimary: p.background,
      secondary: p.gold,
      onSecondary: p.text,
      error: p.error,
      onError: p.background,
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      surfaceContainer: p.surface,
      outline: p.hairline,
      outlineVariant: p.hairline,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      fontFamily: LadFonts.ui,
      textTheme: TextTheme(
        displayLarge: textStyle(LadTypeScale.display, p.text),
        titleLarge: textStyle(LadTypeScale.title, p.text),
        headlineSmall: textStyle(LadTypeScale.headline, p.text),
        bodyLarge: textStyle(LadTypeScale.body, p.text),
        bodyMedium: textStyle(LadTypeScale.body, p.text),
        labelLarge: textStyle(LadTypeScale.label, p.text),
        bodySmall: textStyle(LadTypeScale.caption, p.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: p.hairline,
        thickness: LadStroke.hairline,
        space: LadSpace.xl,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [LadColors(p)],
    );
  }
}
