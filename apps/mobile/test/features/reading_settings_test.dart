import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/design_system/components.dart';
import 'package:louanges_a_dieu/core/design_system/tokens.g.dart';
import 'package:louanges_a_dieu/core/preferences/preferences.dart';
import 'package:louanges_a_dieu/features/reader/presentation_screen.dart';

import '../support/app_harness.dart';
import '../support/real_fonts.dart';
import 'faithful_journey_test.dart' show idle;
import 'reader_test.dart' show openReader;

/// Planche 3 : réglages de lecture, cantiques suivants, plein écran.
void main() {
  setUpAll(loadRealFonts);

  Color background(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).last).lad.background;

  testApp('réglages de lecture : sépia, police, en-tête, réinitialiser', (
    tester,
    db,
  ) async {
    await openReader(tester, '37', 'Au matin');
    await tester.tap(find.byTooltip('Réglages de lecture'));
    await idle(tester);

    await tester.tap(find.text('Sépia'));
    await idle(tester);
    expect(background(tester), LadPalette.sepia.background);
    await tester.tap(find.text('Éditorial'));
    await idle(tester);
    await tester.ensureVisible(find.text('Afficher le numéro'));
    await tester.pump();
    await tester.tap(find.text('Afficher le numéro'));
    await idle(tester);

    var prefs = await settle(tester, PreferencesRepository(db).load());
    expect(prefs.readerTheme, LadAppearance.sepia);
    expect(prefs.lyricsFont, LyricsFont.editorial);
    expect(prefs.showNumber, isFalse);

    await tester.ensureVisible(find.text('Réinitialiser'));
    await tester.pump();
    await tester.tap(find.text('Réinitialiser'));
    await idle(tester);
    prefs = await settle(tester, PreferencesRepository(db).load());
    expect(prefs.readerTheme, LadAppearance.system);
    expect(prefs.lyricsFont, LyricsFont.classic);
    expect(prefs.showNumber, isTrue);
  });

  testApp('dernière strophe : cantiques suivants, puis lecture du suivant', (
    tester,
    _,
  ) async {
    await openReader(tester, '1', 'Ô jour heureux');
    expect(find.text('Lire le cantique 2'), findsNothing);
    await tester.tap(find.byTooltip('Strophe suivante'));
    await idle(tester);
    expect(find.text('Lire le cantique 2'), findsOneWidget);
    await tester.ensureVisible(find.text('Lire le cantique 2'));
    await tester.pump();
    await tester.tap(find.text('Lire le cantique 2'));
    await idle(tester);
    expect(find.text('L’Éternel est mon berger,'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
  });

  testApp('plein écran : diapositives, défilement automatique, fermeture', (
    tester,
    _,
  ) async {
    await openReader(tester, '2', 'L’Éternel est mon berger');
    await tester.tap(find.byTooltip('Plein écran'));
    await idle(tester);
    expect(find.byType(PresentationScreen), findsOneWidget);
    // Titre, puis couplet 1, refrain, couplet 2, refrain.
    expect(find.text('2 · 1 / 5'), findsOneWidget);
    await tester.tap(find.byTooltip('Suivante'));
    await idle(tester);
    expect(find.text('L’Éternel est mon berger,'), findsOneWidget);

    await tester.tap(find.byTooltip('Défilement auto'));
    await tester.pump(const Duration(seconds: 9));
    await idle(tester);
    expect(find.text('2 · 3 / 5'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('2 · 3 / 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await idle(tester);
    expect(find.byType(PresentationScreen), findsNothing);
  });

  testApp('apparence de l’app : sépia appliqué partout', (tester, db) async {
    await tester.tap(find.text('Plus').last);
    await idle(tester);
    await tester.tap(find.text('Apparence'));
    await idle(tester);
    await tester.tap(find.bySemanticsLabel('Sépia'));
    await idle(tester);
    expect(background(tester), LadPalette.sepia.background);
    final prefs = await settle(tester, PreferencesRepository(db).load());
    expect(prefs.appearance, LadAppearance.sepia);
  });
}
