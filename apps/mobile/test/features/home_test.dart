import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/design_system/components.dart';
import 'package:louanges_a_dieu/core/user_data/reading_history.dart';
import 'package:louanges_a_dieu/features/worship/worship.dart';

import '../support/app_harness.dart';
import '../support/real_fonts.dart';
import 'faithful_journey_test.dart' show idle, search;

void main() {
  setUpAll(loadRealFonts);

  testApp('petit écran, grands caractères : recherche visible sans défiler', (
    tester,
    _,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    final field = tester.getRect(find.text('Numéro, titre ou paroles'));
    expect(field.bottom, lessThan(640 - 80)); // au-dessus de la barre
  });

  testApp('reprendre la lecture : derniers cantiques ouverts, effaçables', (
    tester,
    db,
  ) async {
    expect(find.text('Reprendre votre lecture'), findsNothing);

    await search(tester, '37bis');
    await tester.tap(find.text('Autre texte sur la même mélodie').first);
    await idle(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(BackButton));
      await idle(tester);
    }

    await tester.scrollUntilVisible(
      find.text('Reprendre votre lecture'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.widgetWithText(HymnListTile, 'Autre texte sur la même mélodie'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Effacer'));
    await idle(tester);
    await tester.tap(find.text('Effacer'));
    await idle(tester);
    expect(find.text('Reprendre votre lecture'), findsNothing);
    expect(await settle(tester, ReadingHistoryRepository(db).read()), isEmpty);
  });

  testApp('historique : sans doublon, cinq cantiques au plus', (
    tester,
    db,
  ) async {
    final history = ReadingHistoryRepository(db);
    for (final id in ['a', 'b', 'c', 'a', 'd', 'e', 'f']) {
      await settle(tester, history.record(id));
    }
    expect(await settle(tester, history.read()), ['f', 'e', 'd', 'a', 'c']);
  });

  testApp('raccourci « Projeter les paroles » : choisir un cantique', (
    tester,
    _,
  ) async {
    await tester.scrollUntilVisible(
      find.text('Projeter les paroles'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Projeter les paroles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projeter les paroles'));
    await idle(tester);
    expect(find.byType(HymnPickerScreen), findsOneWidget);
  });
}
