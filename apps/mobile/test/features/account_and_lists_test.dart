import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/providers.dart';

import '../support/app_harness.dart';
import '../support/fake_auth.dart';

/// Compte et listes (Phase 6), sur l'application complète avec un service de
/// connexion simulé. Les données sont créées par l'interface, comme le ferait
/// un utilisateur.

Future<void> idle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await idle(tester);
}

Future<void> back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await idle(tester);
}

Future<void> openAccount(WidgetTester tester) async {
  await openTab(tester, 'Plus');
  await tester.tap(find.text('Mon compte'));
  await idle(tester);
}

/// Connexion par code (le service simulé accepte « 12345678 »), puis retour.
Future<void> signIn(WidgetTester tester) async {
  await openAccount(tester);
  await tester.enterText(find.byType(TextField), 'fidele@exemple.org');
  await tester.tap(find.text('Recevoir le lien de connexion'));
  await idle(tester);
  await tester.enterText(find.byType(TextField), '12345678');
  await tester.tap(find.text('Valider le code'));
  await idle(tester);
  await back(tester);
}

Future<void> openHymn(WidgetTester tester, String title) async {
  await openTab(tester, 'Recueil');
  await tester.tap(find.text(title));
  await idle(tester);
}

/// Ajoute [title] à [listName] depuis sa fiche (crée la liste au besoin), puis revient.
Future<void> addToList(
  WidgetTester tester,
  String title,
  String listName,
) async {
  await openHymn(tester, title);
  await tester.tap(find.byTooltip('Ajouter à une liste'));
  await idle(tester);
  if (find.text(listName).evaluate().isEmpty) {
    await tester.tap(find.text('Nouvelle liste'));
    await idle(tester);
    await tester.enterText(find.byType(TextField), listName);
    await tester.tap(find.text('Créer'));
  } else {
    await tester.tap(find.text(listName));
  }
  await idle(tester);
  expect(find.text('Ajouté à « $listName »'), findsOneWidget);
  await back(tester);
}

Future<void> favorite(WidgetTester tester, String title) async {
  await openHymn(tester, title);
  await tester.tap(find.byTooltip('Ajouter aux favoris'));
  await idle(tester);
  await back(tester);
}

void main() {
  late FakeAuthService auth;
  setUp(() => auth = FakeAuthService());
  List<Override> withAuth() => [
    authServiceProvider.overrideWith((ref) => auth),
  ];

  testApp('visiteur : les listes invitent à se connecter (Q-05)', (
    tester,
    _,
  ) async {
    await openTab(tester, 'Favoris');
    await tester.tap(find.text('Listes'));
    await idle(tester);
    expect(find.text('Les listes sont liées à votre compte'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  }, overrides: withAuth());

  testApp('connexion : e-mail invalide, code invalide, puis code valide', (
    tester,
    _,
  ) async {
    await openAccount(tester);
    await tester.enterText(find.byType(TextField), 'pas-une-adresse');
    await tester.tap(find.text('Recevoir le lien de connexion'));
    await idle(tester);
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fidele@exemple.org');
    await tester.tap(find.text('Recevoir le lien de connexion'));
    await idle(tester);
    expect(find.text('Vérifiez votre messagerie'), findsOneWidget);
    expect(auth.sentTo, ['fidele@exemple.org']);

    await tester.enterText(find.byType(TextField), '00000000');
    await tester.tap(find.text('Valider le code'));
    await idle(tester);
    expect(find.text('Code invalide ou expiré.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12345678');
    await tester.tap(find.text('Valider le code'));
    await idle(tester);
    expect(find.text('Connecté avec fidele@exemple.org'), findsOneWidget);
  }, overrides: withAuth());

  testApp(
    'listes : créer, ajouter depuis la fiche, réordonner, retirer (F-LST-001)',
    (tester, _) async {
      await signIn(tester);
      await addToList(tester, 'L’Éternel est mon berger', 'Culte du soir');
      await addToList(tester, 'Ô jour heureux', 'Culte du soir');

      await openTab(tester, 'Favoris');
      await tester.tap(find.text('Listes'));
      await idle(tester);
      await tester.tap(find.text('Culte du soir'));
      await idle(tester);

      List<String?> order() => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where(
            (d) => d == 'L’Éternel est mon berger' || d == 'Ô jour heureux',
          )
          .toList();
      expect(order(), ['L’Éternel est mon berger', 'Ô jour heureux']);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await idle(tester);
      await tester.tap(find.text('Descendre'));
      await idle(tester);
      expect(order(), ['Ô jour heureux', 'L’Éternel est mon berger']);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await idle(tester);
      await tester.tap(find.text('Retirer de la liste'));
      await idle(tester);
      expect(order(), ['L’Éternel est mon berger']);
    },
    overrides: withAuth(),
  );

  testApp(
    'déconnexion : listes retirées de l’appareil, favoris gardés au choix',
    (tester, _) async {
      await signIn(tester);
      await favorite(tester, 'Au matin');
      await addToList(tester, 'Mon cœur Te loue', 'Liste du compte');

      await openAccount(tester);
      await tester.tap(find.text('Se déconnecter'));
      await idle(tester);
      expect(find.text('Garder mes favoris sur cet appareil'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
      await idle(tester);
      expect(auth.currentUser, isNull);
      await back(tester);

      await openTab(tester, 'Favoris');
      expect(find.text('Au matin'), findsOneWidget, reason: 'favori gardé');
      await tester.tap(find.text('Listes'));
      await idle(tester);
      expect(find.text('Liste du compte'), findsNothing);
      expect(find.text('Les listes sont liées à votre compte'), findsOneWidget);
    },
    overrides: withAuth(),
  );

  testApp(
    'suppression de compte : confirmation, puis données locales effacées',
    (tester, _) async {
      await signIn(tester);
      await favorite(tester, 'Au matin');

      await openAccount(tester);
      await tester.tap(find.text('Supprimer mon compte'));
      await idle(tester);
      expect(
        find.text('Supprimer définitivement votre compte ?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await idle(tester);
      expect(auth.deleted, isTrue);
      await back(tester);

      await openTab(tester, 'Favoris');
      expect(find.text('Au matin'), findsNothing);
      expect(find.text('Aucun favori'), findsOneWidget);
    },
    overrides: withAuth(),
  );
}
