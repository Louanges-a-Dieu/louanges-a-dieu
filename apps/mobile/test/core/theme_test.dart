import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
