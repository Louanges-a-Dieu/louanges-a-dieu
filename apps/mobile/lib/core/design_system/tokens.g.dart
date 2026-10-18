// GÉNÉRÉ par packages/design_tokens à partir de tokens.json — NE PAS MODIFIER.
// Source : packages/design_tokens/tokens.json (ADR-014).

import 'dart:ui';

/// Palette de couleurs d'un thème.
final class LadPalette {
  const LadPalette({
    required this.background,
    required this.surface,
    required this.hairline,
    required this.text,
    required this.textSecondary,
    required this.gold,
    required this.goldText,
    required this.error,
    required this.success,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color hairline;
  final Color text;
  final Color textSecondary;
  final Color gold;
  final Color goldText;
  final Color error;
  final Color success;
  final Color info;

  static const light = LadPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFAF8),
    hairline: Color(0xFFECE8E2),
    text: Color(0xFF1F1A17),
    textSecondary: Color(0xFF6B625B),
    gold: Color(0xFFB08D57),
    goldText: Color(0xFF8A6A35),
    error: Color(0xFF9B2C2C),
    success: Color(0xFF3F6B4A),
    info: Color(0xFF4F5F68),
  );

  static const dark = LadPalette(
    background: Color(0xFF121110),
    surface: Color(0xFF1B1A18),
    hairline: Color(0xFF2C2925),
    text: Color(0xFFF2EEE8),
    textSecondary: Color(0xFFA89F96),
    gold: Color(0xFFC9A46B),
    goldText: Color(0xFFD4B27A),
    error: Color(0xFFE38B8B),
    success: Color(0xFF8FC39C),
    info: Color(0xFF9FB2BC),
  );

  static const projection = LadPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    hairline: Color(0xFF262626),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFBDBDBD),
    gold: Color(0xFFC9A46B),
    goldText: Color(0xFFD4B27A),
    error: Color(0xFFE38B8B),
    success: Color(0xFF8FC39C),
    info: Color(0xFF9FB2BC),
  );
}

/// Espacements (dp).
abstract final class LadSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;
}

/// Rayons (dp).
abstract final class LadRadius {
  static const double none = 0;
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double pill = 999;
}

/// Épaisseurs de trait (dp).
abstract final class LadStroke {
  static const double hairline = 1;
  static const double refrainRule = 2;
}

/// Durées d'animation.
abstract final class LadDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
}

/// Familles de polices.
abstract final class LadFonts {
  static const String display = 'Cormorant Garamond';
  static const String lyrics = 'Literata';
  static const String ui = 'Inter';
}

/// Rôle typographique.
enum LadFontRole { display, lyrics, ui }

/// Spécification d'un style de texte.
final class LadTextSpec {
  const LadTextSpec({
    required this.role,
    required this.size,
    required this.height,
    required this.weight,
  });

  final LadFontRole role;
  final double size;
  final double height;
  final FontWeight weight;
}

/// Échelle typographique.
abstract final class LadTypeScale {
  static const display = LadTextSpec(
    role: LadFontRole.display,
    size: 40,
    height: 1.1,
    weight: FontWeight.w500,
  );

  static const hymnNumber = LadTextSpec(
    role: LadFontRole.display,
    size: 32,
    height: 1.1,
    weight: FontWeight.w600,
  );

  static const title = LadTextSpec(
    role: LadFontRole.display,
    size: 26,
    height: 1.2,
    weight: FontWeight.w600,
  );

  static const listNumber = LadTextSpec(
    role: LadFontRole.display,
    size: 20,
    height: 1.2,
    weight: FontWeight.w600,
  );

  static const headline = LadTextSpec(
    role: LadFontRole.ui,
    size: 20,
    height: 1.3,
    weight: FontWeight.w600,
  );

  static const lyrics = LadTextSpec(
    role: LadFontRole.lyrics,
    size: 20,
    height: 1.55,
    weight: FontWeight.w400,
  );

  static const body = LadTextSpec(
    role: LadFontRole.ui,
    size: 16,
    height: 1.5,
    weight: FontWeight.w400,
  );

  static const label = LadTextSpec(
    role: LadFontRole.ui,
    size: 14,
    height: 1.4,
    weight: FontWeight.w500,
  );

  static const caption = LadTextSpec(
    role: LadFontRole.ui,
    size: 12,
    height: 1.4,
    weight: FontWeight.w400,
  );
}

/// Taille de lecture des paroles réglable par l'utilisateur (pt).
abstract final class LadLyricsSize {
  static const double min = 16;
  static const double defaultSize = 20;
  static const double max = 34;
  static const double step = 2;
}

/// Taille minimale d'une cible tactile (dp).
abstract final class LadTouchTarget {
  static const double min = 48;
}
