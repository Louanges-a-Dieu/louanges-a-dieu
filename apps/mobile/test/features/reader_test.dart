import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/preferences/preferences.dart';

import '../support/app_harness.dart';
import 'faithful_journey_test.dart' show idle, search;

Future<void> openReader(WidgetTester tester, String query, String title) async {
  await search(tester, query);
  await tester.tap(find.text(title).first);
  await idle(tester);
  await tester.tap(find.byTooltip('Mode lecture'));
  await idle(tester);
}

void main() {
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

  testApp('couplet par couplet : sections une à une, puis cantique suivant', (
    tester,
    db,
  ) async {
    await settle(
      tester,
      PreferencesRepository(db)
          .save(const ReadingPreferences(readerByStanza: true)),
    );
    await openReader(tester, '2', 'L’Éternel est mon berger');

    // Couplet seul, puis le refrain, puis le cantique suivant.
    expect(find.text('L’Éternel est mon berger,'), findsOneWidget);
    expect(find.text('Alléluia, gloire à Dieu,'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Section suivante'));
    await idle(tester);
    expect(find.text('Alléluia, gloire à Dieu,'), findsOneWidget);
    expect(find.text('L’Éternel est mon berger,'), findsNothing);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Section suivante'));
    await idle(tester);
    expect(find.text('Mon cœur Te loue, Seigneur,'), findsOneWidget);

    // Retour : dernière section du cantique précédent.
    await tester.tap(find.byTooltip('Section précédente'));
    await idle(tester);
    expect(find.text('Alléluia, gloire à Dieu,'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
