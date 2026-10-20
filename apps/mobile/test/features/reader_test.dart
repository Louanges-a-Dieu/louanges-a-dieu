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
    await tester.tap(find.byTooltip('Agrandir le texte'));
    await idle(tester);
    final prefs = await settle(tester, PreferencesRepository(db).load());
    expect(prefs.lyricsSize, const ReadingPreferences().lyricsSize + 2);
  });

  testApp('une strophe à la fois, puis cantique suivant / précédent', (
    tester,
    _,
  ) async {
    await openReader(tester, '2', 'L’Éternel est mon berger');

    // Le couplet seul, puis le refrain seul.
    expect(find.text('L’Éternel est mon berger,'), findsOneWidget);
    expect(find.text('Alléluia, gloire à Dieu,'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Section suivante'));
    await idle(tester);
    expect(find.text('Alléluia, gloire à Dieu,'), findsOneWidget);
    expect(find.text('L’Éternel est mon berger,'), findsNothing);
    expect(find.text('2 / 2'), findsOneWidget);

    // Dernière strophe : Suivant ne change pas de cantique.
    await tester.tap(find.byTooltip('Section suivante'));
    await idle(tester);
    expect(find.text('2 / 2'), findsOneWidget);

    // Cantique suivant : première strophe ; retour au précédent.
    await tester.tap(find.text('Cantique suivant'));
    await idle(tester);
    expect(find.text('Mon cœur Te loue, Seigneur,'), findsOneWidget);
    expect(find.text('Alléluia, gloire à Dieu,'), findsNothing);

    await tester.tap(find.text('Cantique précédent'));
    await idle(tester);
    expect(find.text('L’Éternel est mon berger,'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    // Glisser vers la gauche : strophe suivante.
    await tester.fling(find.byType(ListView), const Offset(-300, 0), 1000);
    await idle(tester);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testApp('petit écran, grands caractères : les quatre boutons tiennent', (
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
    for (final label in [
      'Cantique précédent',
      'Cantique suivant',
      'Précédent',
      'Suivant',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
  });
}
