import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/design_system/components.dart';
import 'package:louanges_a_dieu/core/design_system/theme.dart';
import 'package:louanges_a_dieu/core/design_system/tokens.g.dart';

void main() {
  test('le thème clair a un fond ivoire (« Le recueil vivant »)', () {
    expect(LadTheme.light.scaffoldBackgroundColor, const Color(0xFFF7F0E4));
  });

  test('chaque thème expose sa palette via LadColors', () {
    expect(LadTheme.light.extension<LadColors>()!.palette, LadPalette.light);
    expect(LadTheme.dark.extension<LadColors>()!.palette, LadPalette.dark);
    expect(
      LadTheme.projection.extension<LadColors>()!.palette,
      LadPalette.projection,
    );
  });

  test('le texte principal utilise la couleur de texte des tokens', () {
    expect(LadTheme.light.textTheme.bodyLarge!.color, LadPalette.light.text);
  });

  test('les styles typographiques reprennent les familles des tokens', () {
    final style = LadTheme.textStyle(
      LadTypeScale.lyrics,
      LadPalette.light.text,
    );
    expect(style.fontFamily, LadFonts.lyrics);
    expect(style.fontSize, LadTypeScale.lyrics.size);
    expect(style.height, LadTypeScale.lyrics.height);
  });

  test('la taille de lecture par défaut est dans les bornes', () {
    expect(
      LadLyricsSize.defaultSize,
      inInclusiveRange(LadLyricsSize.min, LadLyricsSize.max),
    );
  });

  test('titres et paroles en serif, interface en sans-serif', () {
    expect(LadFonts.display, 'Cormorant Garamond');
    expect(LadFonts.lyrics, 'Literata');
    expect(LadFonts.ui, 'Inter');
    expect(LadTypeScale.title.role, LadFontRole.display);
    expect(LadTypeScale.lyrics.role, LadFontRole.lyrics);
    expect(LadRadius.lg, inInclusiveRange(12, 18));
  });

  test("l'aperçu de projection utilise les polices de l'écran projeté", () {
    final style = LadTheme.textStyle(
      LadProjectionTypeScale.lyrics,
      LadPalette.projection.text,
      projection: true,
    );
    expect(style.fontFamily, LadProjectionFonts.lyrics);
  });

  test('action principale : libellé ivoire sur or foncé', () {
    final style = LadTheme.light.filledButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), LadPalette.light.goldText);
    expect(style.foregroundColor!.resolve({}), LadPalette.light.surface);
  });

  test('lecture vocale d’un numéro bis', () {
    expect(spokenNumber('37bis'), '37 bis');
  });

  test(
    "l'interlettrage des tokens est appliqué en proportion de la taille",
    () {
      final style = LadTheme.textStyle(
        LadTypeScale.overline,
        LadPalette.light.text,
      );
      expect(
        style.letterSpacing,
        closeTo(
          LadTypeScale.overline.letterSpacing * LadTypeScale.overline.size,
          1e-9,
        ),
      );
    },
  );
}
