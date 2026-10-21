// GÉNÉRÉ par packages/design_tokens à partir de tokens.json — NE PAS MODIFIER.
// Source : packages/design_tokens/tokens.json (ADR-014).

import 'dart:ui';

/// Palette de couleurs d'un thème.
final class LadPalette {
  const LadPalette({
    required this.background,
    required this.surface,
    required this.surfaceWarm,
    required this.hairline,
    required this.text,
    required this.textSecondary,
    required this.gold,
    required this.goldText,
    required this.goldLight,
    required this.goldPale,
    required this.error,
    required this.success,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color surfaceWarm;
  final Color hairline;
  final Color text;
  final Color textSecondary;
  final Color gold;
  final Color goldText;
  final Color goldLight;
  final Color goldPale;
  final Color error;
  final Color success;
  final Color info;

  static const light = LadPalette(
    background: Color(0xFFF7F0E4),
    surface: Color(0xFFFFFAF1),
    surfaceWarm: Color(0xFFF0E5D2),
    hairline: Color(0xFFE8D9BF),
    text: Color(0xFF392A1B),
    textSecondary: Color(0xFF76634B),
    gold: Color(0xFFA86D13),
    goldText: Color(0xFF89570E),
    goldLight: Color(0xFFD7A84F),
    goldPale: Color(0xFFE8D1A6),
    error: Color(0xFF9B2C2C),
    success: Color(0xFF3F6B4A),
    info: Color(0xFF4F5F68),
  );

  static const dark = LadPalette(
    background: Color(0xFF171F1F),
    surface: Color(0xFF222B29),
    surfaceWarm: Color(0xFF1C2524),
    hairline: Color(0xFF34403D),
    text: Color(0xFFF4EADB),
    textSecondary: Color(0xFFB7A88F),
    gold: Color(0xFFD7A84F),
    goldText: Color(0xFFE0BB6E),
    goldLight: Color(0xFFD7A84F),
    goldPale: Color(0xFF3A3223),
    error: Color(0xFFE8998F),
    success: Color(0xFF8FC39C),
    info: Color(0xFF9FB2BC),
  );

  static const sepia = LadPalette(
    background: Color(0xFFF1E4CA),
    surface: Color(0xFFF7ECD6),
    surfaceWarm: Color(0xFFE9D9B8),
    hairline: Color(0xFFDCC79F),
    text: Color(0xFF3A2814),
    textSecondary: Color(0xFF6A5233),
    gold: Color(0xFF9A6210),
    goldText: Color(0xFF7A4C0A),
    goldLight: Color(0xFFC9973F),
    goldPale: Color(0xFFE2C690),
    error: Color(0xFF932A22),
    success: Color(0xFF3A6241),
    info: Color(0xFF47565C),
  );

  static const projection = LadPalette(
    background: Color(0xFF171F1F),
    surface: Color(0xFF171F1F),
    surfaceWarm: Color(0xFF171F1F),
    hairline: Color(0xFF2C3633),
    text: Color(0xFFFFF5E5),
    textSecondary: Color(0xFFC9BBA3),
    gold: Color(0xFFD7A84F),
    goldText: Color(0xFFDFC18D),
    goldLight: Color(0xFFD7A84F),
    goldPale: Color(0xFF3A3223),
    error: Color(0xFFE8998F),
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
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

/// Épaisseurs de trait (dp).
abstract final class LadStroke {
  static const double hairline = 1;
  static const double refrainRule = 2;
  static const double accent = 2;
}

/// Ombre douce (cartes mises en avant) ; couleur : texte du thème.
abstract final class LadShadow {
  static const double softOffsetY = 6;
  static const double softBlur = 20;
  static const double softOpacity = 0.08;
}

/// Durées d'animation.
abstract final class LadDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
}

/// Familles de polices de l'application.
abstract final class LadFonts {
  static const String display = 'Cormorant Garamond';
  static const String lyrics = 'Literata';
  static const String ui = 'Inter';
  static const String numeric = 'Cormorant Garamond';
}

/// Familles de polices de l'écran projeté.
abstract final class LadProjectionFonts {
  static const String display = 'Cormorant Garamond';
  static const String lyrics = 'Literata';
  static const String ui = 'Inter';
  static const String numeric = 'Cormorant Garamond';
}

/// Rôle typographique.
enum LadFontRole { display, lyrics, ui, numeric }

/// Spécification d'un style de texte.
final class LadTextSpec {
  const LadTextSpec({
    required this.role,
    required this.size,
    required this.height,
    required this.weight,
    this.letterSpacing = 0,
  });

  final LadFontRole role;
  final double size;
  final double height;
  final FontWeight weight;

  /// Interlettrage en em (multiplié par la taille du texte).
  final double letterSpacing;
}

/// Échelle typographique de l'application.
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
    size: 28,
    height: 1.15,
    weight: FontWeight.w600,
  );

  static const sectionTitle = LadTextSpec(
    role: LadFontRole.display,
    size: 23,
    height: 1.2,
    weight: FontWeight.w600,
  );

  static const cardTitle = LadTextSpec(
    role: LadFontRole.display,
    size: 21,
    height: 1.2,
    weight: FontWeight.w600,
  );

  static const listTitle = LadTextSpec(
    role: LadFontRole.display,
    size: 19,
    height: 1.25,
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
    size: 18,
    height: 1.3,
    weight: FontWeight.w600,
  );

  static const lyrics = LadTextSpec(
    role: LadFontRole.lyrics,
    size: 20,
    height: 1.6,
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

  static const overline = LadTextSpec(
    role: LadFontRole.ui,
    size: 11,
    height: 1.3,
    weight: FontWeight.w600,
    letterSpacing: 0.16,
  );

  static const marker = LadTextSpec(
    role: LadFontRole.ui,
    size: 13,
    height: 1.3,
    weight: FontWeight.w400,
  );
}

/// Échelle typographique de l'écran projeté.
abstract final class LadProjectionTypeScale {
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
    size: 28,
    height: 1.15,
    weight: FontWeight.w600,
  );

  static const sectionTitle = LadTextSpec(
    role: LadFontRole.display,
    size: 23,
    height: 1.2,
    weight: FontWeight.w600,
  );

  static const cardTitle = LadTextSpec(
    role: LadFontRole.display,
    size: 21,
    height: 1.2,
    weight: FontWeight.w600,
  );

  static const listTitle = LadTextSpec(
    role: LadFontRole.display,
    size: 19,
    height: 1.25,
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
    size: 18,
    height: 1.3,
    weight: FontWeight.w600,
  );

  static const lyrics = LadTextSpec(
    role: LadFontRole.lyrics,
    size: 20,
    height: 1.6,
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

  static const overline = LadTextSpec(
    role: LadFontRole.ui,
    size: 11,
    height: 1.3,
    weight: FontWeight.w600,
    letterSpacing: 0.16,
  );

  static const marker = LadTextSpec(
    role: LadFontRole.ui,
    size: 13,
    height: 1.3,
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
