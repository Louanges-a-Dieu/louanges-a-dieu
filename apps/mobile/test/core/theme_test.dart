import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/design_system/components.dart';
import 'package:louanges_a_dieu/core/design_system/theme.dart';
import 'package:louanges_a_dieu/core/design_system/tokens.g.dart';

void main() {
  test('le thème clair a un fond blanc pur (Q-11)', () {
    expect(LadTheme.light.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
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

  test(
    'direction « clair net » : polices géométriques, numéros techniques',
    () {
      expect(LadFonts.ui, 'Space Grotesk');
      expect(LadFonts.lyrics, 'Manrope');
      expect(LadFonts.numeric, 'IBM Plex Mono');
      expect(LadTypeScale.hymnNumber.role, LadFontRole.numeric);
      expect(LadRadius.sm, lessThanOrEqualTo(2));
    },
  );

  test("l'aperçu de projection garde les polices de l'écran projeté", () {
    final style = LadTheme.textStyle(
      LadProjectionTypeScale.lyrics,
      LadPalette.projection.text,
      projection: true,
    );
    expect(style.fontFamily, LadProjectionFonts.lyrics);
    expect(LadProjectionFonts.lyrics, isNot(LadFonts.lyrics));
  });

  test('numéro affiché sur trois chiffres, sans toucher au suffixe', () {
    expect(displayNumber('7'), '007');
    expect(displayNumber('37bis'), '037bis');
    expect(displayNumber('1138'), '1138');
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
