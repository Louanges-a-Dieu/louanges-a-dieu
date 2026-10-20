import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_models.dart';
import 'package:louanges_a_dieu/core/catalog/hymn_of_the_day.dart';

import '../support/app_harness.dart';
import '../support/catalog_fixtures.dart';

/// Laisse s'exécuter requêtes locales, minuteurs et animations.
Future<void> idle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.tap(find.text('Numéro, titre ou paroles'));
  await idle(tester);
  await tester.enterText(find.byType(TextField), text);
  await idle(tester);
}

void main() {
  testApp('accueil : identité, recherche et cantique du jour (F-ACC-001)', (
    tester,
    _,
  ) async {
    final expected = hymnOfTheDay([
      for (final h in sampleHymns())
        HymnSummary(
          id: h['id']! as String,
          numberLabel: h['numberLabel']! as String,
          numberNumeric: h['numberNumeric']! as int,
          title: h['title']! as String,
          openingLine: null,
        ),
    ], DateTime(2026, 10, 18))!;
    expect(find.text('Le cantique du jour'), findsOneWidget);
    expect(find.text(expected.title), findsOneWidget);
    expect(find.text('Numéro, titre ou paroles'), findsOneWidget);
  });

  testApp('parcours fidèle : recherche « 37bis » → fiche → favori → favoris', (
    tester,
    _,
  ) async {
    await search(tester, '37bis');
    expect(find.text('NUMÉRO'), findsOneWidget);
    await tester.tap(find.text('Autre texte sur la même mélodie').first);
    await idle(tester);

    // Fiche : numéro, titre, vers, lien vers la mélodie du n° 37.
    // Numéro affiché tel qu'imprimé, lu « 37 bis ».
    expect(find.text('37bis'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Cantique 37 bis')), findsOneWidget);
    expect(find.text('Le jour se lève.'), findsOneWidget);
    expect(find.text('Se chante sur la mélodie du n° 37'), findsOneWidget);
    // Actions réelles seulement : pas d'audio sans enregistrement.
    for (final label in ['Lire', 'Projeter', 'Partager', 'À une liste']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Écouter'), findsNothing);

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await idle(tester);
    expect(find.byTooltip('Retirer des favoris'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await idle(tester);
    await tester.tap(find.byType(BackButton));
    await idle(tester);
    await tester.tap(find.text('Favoris').last);
    await idle(tester);
    expect(find.text('Autre texte sur la même mélodie'), findsOneWidget);
  });

  testApp(
    'fiche : refrain distingué, répétition visible, aucune donnée inconnue affichée (T-010)',
    (tester, _) async {
      await search(tester, '2');
      await tester.tap(find.text('L’Éternel est mon berger').first);
      await idle(tester);
      expect(find.bySemanticsLabel(RegExp('^Refrain')), findsOneWidget);
      expect(find.textContaining('Inconnu'), findsNothing);
      expect(find.textContaining('Auteur'), findsNothing);
    },
  );

  testApp('recherche dans les paroles : extrait du vers trouvé (T-003)', (
    tester,
    _,
  ) async {
    await search(tester, 'epis dores');
    expect(find.text('PAROLES'), findsOneWidget);
    expect(find.text('Les épis sont dorés.'), findsOneWidget);
  });

  testApp('recherche sans résultat', (tester, _) async {
    await search(tester, 'zzzz introuvable');
    expect(find.text('Aucun cantique trouvé'), findsOneWidget);
  });

  testApp('recueil : ordre des numéros et « aller au numéro »', (
    tester,
    _,
  ) async {
    await tester.tap(find.text('Recueil').last);
    await idle(tester);
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d != null && RegExp(r'^\d+(bis)?$').hasMatch(d))
        .toList();
    expect(labels, ['1', '2', '3', '30', '37', '37bis']);

    await tester.tap(find.byTooltip('Aller au numéro'));
    await idle(tester);
    await tester.enterText(find.byType(TextField), '37 bis');
    await tester.tap(find.text('Ouvrir'));
    await idle(tester);
    expect(find.text('Le jour se lève.'), findsOneWidget);
  });

  testApp('« aller au numéro » inexistant : message', (tester, _) async {
    await tester.tap(find.text('Recueil').last);
    await idle(tester);
    await tester.tap(find.byTooltip('Aller au numéro'));
    await idle(tester);
    await tester.enterText(find.byType(TextField), '666');
    await tester.tap(find.text('Ouvrir'));
    await idle(tester);
    expect(
      find.text('Le numéro 666 n’existe pas dans le recueil.'),
      findsOneWidget,
    );
  });

  testApp('mode lecture : cantique suivant', (tester, _) async {
    await search(tester, '37');
    await tester.tap(find.text('Au matin').first);
    await idle(tester);
    await tester.tap(find.byTooltip('Mode lecture'));
    await idle(tester);
    expect(find.text('Au matin je Te cherche,'), findsOneWidget);
    await tester.tap(find.text('Cantique suivant'));
    await idle(tester);
    expect(find.text('Le jour se lève.'), findsOneWidget);
  });

  testApp('mode lecture : le favori porte sur le cantique affiché', (
    tester,
    _,
  ) async {
    await search(tester, '37');
    await tester.tap(find.text('Au matin').first);
    await idle(tester);
    await tester.tap(find.byTooltip('Mode lecture'));
    await idle(tester);
    await tester.tap(find.text('Cantique suivant'));
    await idle(tester);
    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await idle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(BackButton));
      await idle(tester);
    }
    await tester.tap(find.text('Favoris').last);
    await idle(tester);
    expect(find.text('Autre texte sur la même mélodie'), findsOneWidget);
    expect(find.text('Au matin'), findsNothing);
  });

  testApp(
    'à propos : note liminaire verbatim, sans la mention de la page 245',
    (tester, _) async {
      await tester.tap(find.text('Plus').last);
      await idle(tester);
      await tester.tap(find.text('À propos du recueil'));
      await idle(tester);
      expect(find.text('Note sur l’utilisation du recueil'), findsOneWidget);
      expect(find.textContaining('page 245'), findsNothing);
    },
  );
}
