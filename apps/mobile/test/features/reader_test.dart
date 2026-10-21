import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/preferences/preferences.dart';

import '../support/app_harness.dart';
import '../support/real_fonts.dart';
import 'faithful_journey_test.dart' show idle, search;

Future<void> openReader(WidgetTester tester, String query, String title) async {
  await search(tester, query);
  await tester.tap(find.text(title).first);
  await idle(tester);
  await tester.tap(find.byTooltip('Mode lecture'));
  await idle(tester);
}

void main() {
  setUpAll(loadRealFonts);

  testApp('mode lecture : A+ agrandit le texte, réglage conservé', (
    tester,
    db,
  ) async {
    await openReader(tester, '37', 'Au matin');
    await tester.tap(find.byTooltip('Taille du texte'));
    await idle(tester);
    await tester.tap(find.byTooltip('Agrandir le texte'));
    await idle(tester);
    final prefs = await settle(tester, PreferencesRepository(db).load());
    expect(prefs.lyricsSize, const ReadingPreferences().lyricsSize + 2);
  });

  testApp('une strophe à la fois, refrain répété, cantique suivant', (
    tester,
    _,
  ) async {
    await openReader(tester, '2', 'L’Éternel est mon berger');
    const verse1 = 'L’Éternel est mon berger,';
    const verse2 = 'Il me fait reposer';
    const refrain = 'Alléluia, gloire à Dieu,';
    Future<void> next() async {
      await tester.tap(find.byTooltip('Strophe suivante'));
      await idle(tester);
    }

    // Ordre chanté : couplet 1, refrain, couplet 2, refrain ; une à la fois.
    expect(find.text(verse1), findsOneWidget);
    expect(find.text(refrain), findsNothing);
    expect(find.text('1 / 4'), findsOneWidget);
    await next();
    expect(find.text(refrain), findsOneWidget);
    expect(find.text(verse1), findsNothing);
    await next();
    expect(find.text(verse2), findsOneWidget);
    await next();
    expect(find.text(refrain), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);

    // Dernière strophe : Suivant ne change pas de cantique.
    await next();
    expect(find.text('4 / 4'), findsOneWidget);

    // Cantique suivant : première strophe ; retour au précédent.
    await tester.tap(find.byTooltip('Cantique suivant'));
    await idle(tester);
    expect(find.text('Mon cœur Te loue, Seigneur,'), findsOneWidget);
    expect(find.text(refrain), findsNothing);

    await tester.tap(find.byTooltip('Cantique précédent'));
    await idle(tester);
    expect(find.text(verse1), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);

    // Glisser vers la gauche : strophe suivante.
    await tester.fling(find.byType(ListView), const Offset(-300, 0), 1000);
    await idle(tester);
    expect(find.text('2 / 4'), findsOneWidget);
  });

  testApp('petit écran, grands caractères : les commandes tiennent', (
    tester,
    _,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openReader(tester, '2', 'L’Éternel est mon berger');
    expect(tester.takeException(), isNull); // aucun débordement
    for (final tooltip in [
      'Cantique précédent',
      'Strophe précédente',
      'Strophe suivante',
      'Cantique suivant',
    ]) {
      final rect = tester.getRect(find.byTooltip(tooltip));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.height, greaterThanOrEqualTo(48)); // cible tactile
    }
  });
}
