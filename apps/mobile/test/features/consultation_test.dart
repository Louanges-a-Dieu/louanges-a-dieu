import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/preferences/preferences.dart';
import 'package:louanges_a_dieu/features/hymn/share_hymn.dart';

import '../support/app_harness.dart';
import '../support/real_fonts.dart';
import 'faithful_journey_test.dart' show idle, search;

/// Recherche et consultation (planche 2) : filtres et tri des résultats,
/// onglets de la fiche, feuille d'actions, partage, mode lecture.

List<String?> hymnTitles(WidgetTester tester, List<String> candidates) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .where(candidates.contains)
    .toList();

void main() {
  setUpAll(loadRealFonts);

  testApp('recherche : nombre, filtres Titres / Paroles et tri', (
    tester,
    _,
  ) async {
    // « matin » : titre du n° 37, paroles du n° 37 aussi (même cantique, une
    // seule fois), « mon » : titre du n° 3, paroles du n° 1 ou 2.
    await search(tester, 'mon');
    final titles = find.textContaining(RegExp(r'^Titres \('));
    final lyrics = find.textContaining(RegExp(r'^Paroles \('));
    expect(titles, findsOneWidget);
    expect(lyrics, findsOneWidget);
    expect(find.textContaining(RegExp(r'^Tous \(')), findsOneWidget);
    expect(find.textContaining(RegExp(r'résultats?$')), findsOneWidget);

    await tester.tap(titles);
    await idle(tester);
    expect(find.text('Mon cœur Te loue'), findsOneWidget);
    // Un seul groupe : pas d'intertitre.
    expect(find.text('TITRES ET PREMIERS VERS'), findsNothing);

    await tester.tap(find.byTooltip('Trier les résultats'));
    await idle(tester);
    await tester.tap(find.text('Numéro').last);
    await idle(tester);
    expect(find.text('Numéro'), findsOneWidget);
  });

  testApp('fiche : onglet Détails sans donnée inconnue, feuille Actions', (
    tester,
    _,
  ) async {
    await search(tester, '2');
    await tester.tap(find.text('L’Éternel est mon berger').first);
    await idle(tester);

    await tester.tap(find.text('Détails'));
    await idle(tester);
    expect(find.text('Numéro'), findsOneWidget);
    expect(find.text('Structure'), findsOneWidget);
    expect(find.textContaining('avec refrain'), findsOneWidget);
    expect(find.text('Auteur'), findsNothing);
    expect(find.text('THÈMES'), findsNothing);

    await tester.tap(find.byTooltip('Actions'));
    await idle(tester);
    for (final label in [
      'Lire',
      'Projeter',
      'Ajouter aux favoris',
      'Ajouter à une liste',
      'Ajouter à un programme',
      'Partager',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    // Sans enregistrement : ni écoute, ni karaoké, ni téléchargement.
    expect(find.text('Écouter'), findsNothing);
    expect(find.text('Chanter'), findsNothing);
    expect(find.text('Télécharger'), findsNothing);
  });

  testApp('partage : aperçu de l’image, texte, copie', (tester, _) async {
    await search(tester, '37');
    await tester.tap(find.text('Au matin').first);
    await idle(tester);
    await tester.tap(find.byTooltip('Partager le cantique'));
    await idle(tester);
    expect(find.byType(ShareCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ShareCard),
        matching: find.text('Au matin je Te cherche,'),
      ),
      findsOneWidget,
    );
    for (final label in [
      'Partager en image',
      'Partager le texte',
      'Copier les paroles',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testApp('mode lecture : liste des strophes, aller au refrain, sombre', (
    tester,
    db,
  ) async {
    await search(tester, '2');
    await tester.tap(find.text('L’Éternel est mon berger').first);
    await idle(tester);
    await tester.tap(find.byTooltip('Mode lecture'));
    await idle(tester);

    await tester.tap(find.byTooltip('Strophes'));
    await idle(tester);
    expect(find.text('Refrain'), findsWidgets);
    await tester.tap(find.text('Aller au refrain'));
    await idle(tester);
    expect(find.text('Alléluia, gloire à Dieu,'), findsOneWidget);

    expect(
      Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
      Brightness.light,
    );
    await tester.tap(find.byTooltip('Lecture sombre'));
    await idle(tester);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
      Brightness.dark,
    );
    final prefs = await settle(tester, PreferencesRepository(db).load());
    expect(prefs.readerTheme, ThemeMode.dark);
  });
}
