import 'package:flutter/services.dart';

/// Charge les vraies polices de l'app : sans elles, les tests dessinent chaque
/// glyphe comme un carré d'un cadratin et surestiment largeurs et hauteurs.
/// À appeler avant les tests qui mesurent une mise en page.
Future<void> loadRealFonts() async {
  const fonts = {
    'Cormorant Garamond': [
      'assets/fonts/CormorantGaramond/CormorantGaramond-VF.ttf',
    ],
    'Literata': [
      'assets/fonts/Literata/Literata-VF.ttf',
      'assets/fonts/Literata/Literata-Italic-VF.ttf',
    ],
    'Inter': ['assets/fonts/Inter/Inter-VF.ttf'],
  };
  for (final MapEntry(key: family, value: files) in fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load(file));
    }
    await loader.load();
  }
}
