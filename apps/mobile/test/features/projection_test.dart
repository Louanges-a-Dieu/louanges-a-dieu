import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/providers.dart';
import 'package:louanges_a_dieu/core/preferences/preferences.dart';
import 'package:louanges_a_dieu/core/sync/user_sync.dart';

import '../support/app_harness.dart';
import '../support/catalog_fixtures.dart';
import '../support/fake_auth.dart';
import '../support/fake_services.dart';

/// Pilote de projection (8.3) avec un hôte simulé : on vérifie ce qui serait
/// envoyé à l'écran projeté. Le vrai serveur et le vrai navigateur sont testés
/// dans test/core/projection et test/integration/projection_browser_test.dart.

Future<void> idle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  // Bouton au bas d'un formulaire : on y fait défiler, comme l'utilisateur.
  await tester.ensureVisible(find.text(text).last);
  await idle(tester);
  await tester.tap(find.text(text).last);
  await idle(tester);
}

final hymns = [
  hymnJson(
    '12',
    'Cantique projeté',
    verses: [
      ['Premier couplet, vers un,', 'Premier couplet, vers deux.'],
      ['Second couplet, vers un,', 'Second couplet, vers deux.'],
    ],
    refrain: ['Refrain, vers un,', 'Refrain, vers deux.'],
  ),
];

Future<void> openProjection(WidgetTester tester) async {
  await tapText(tester, 'Recueil');
  await tapText(tester, 'Cantique projeté');
  await tester.tap(find.byTooltip('Projeter'));
  await idle(tester);
  await tapText(tester, 'Projeter sur un écran');
}

void main() {
  late FakeProjectionHost host;
  setUp(() => host = FakeProjectionHost());

  List<Override> overrides({bool failing = false}) => [
    projectionHostFactoryProvider.overrideWithValue(
      ({token, port}) async =>
          failing ? throw StateError('pas de réseau') : host,
    ),
  ];

  testApp(
    'télécommande : refrain, relancer, masquer, apparence, défilement auto',
    (tester, db) async {
      await openProjection(tester);
      await tapText(tester, 'Suivante');
      expect(host.last['index'], 1);

      await tester.tap(find.byTooltip('Refrain'));
      await idle(tester);
      expect(host.last['index'], 2, reason: 'prochain refrain');
      await tester.tap(find.byTooltip('Relancer'));
      await idle(tester);
      expect(host.last['index'], 0, reason: 'début du cantique');

      await tester.tap(find.byTooltip('Masquer'));
      await idle(tester);
      expect(host.last['mask'], isTrue);
      expect(host.last['blank'], isFalse);
      await tester.tap(find.byTooltip('Masquer'));
      await idle(tester);
      expect(host.last['mask'], isFalse);

      await tester.tap(find.byTooltip('Mode d’affichage'));
      await idle(tester);
      await tapText(tester, 'Clair');
      await tapText(tester, 'Afficher le numéro');
      expect(host.last['display'], containsPair('background', 'light'));
      expect(host.last['display'], containsPair('showNumber', false));
      final prefs = await settle(tester, PreferencesRepository(db).load());
      expect(prefs.projectionBackground, 'light');
      expect(prefs.projectionShowNumber, isFalse);
      await tester.tapAt(const Offset(10, 10));
      await idle(tester);

      await tester.tap(find.byTooltip('Défilement auto'));
      await tester.pump(const Duration(seconds: 9));
      await idle(tester);
      expect(host.last['index'], 1);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump(const Duration(seconds: 20));
      expect(host.last['index'], 1);
    },
    hymns: hymns,
    overrides: overrides(),
  );

  testApp(
    'connexion : adresse de l’écran retour',
    (tester, _) async {
      await openProjection(tester);
      await tester.tap(find.byTooltip('Connecter un écran'));
      await idle(tester);
      expect(
        find.text('http://192.168.43.1:47100/s/k7mx2qpa/?role=retour'),
        findsOneWidget,
      );
    },
    hymns: hymns,
    overrides: overrides(),
  );

  testApp(
    'T-008 : le pilote envoie chaque changement à l’écran',
    (tester, _) async {
      await openProjection(tester);
      expect(find.text('Projection'), findsOneWidget);
      expect(find.text('Aucun écran connecté'), findsOneWidget);
      expect(host.last['index'], 0);
      expect(
        host.last['count'],
        5,
        reason: 'titre + C1, R, C2, R (refrain répété, Q-07)',
      );
      expect((host.last['slide']! as Map)['kind'], 'title');
      expect(find.text('Ensuite : Couplet'), findsOneWidget);

      await tapText(tester, 'Suivante');
      expect(host.last['index'], 1);
      expect((host.last['slide']! as Map)['lines'], [
        'Premier couplet, vers un,',
        'Premier couplet, vers deux.',
      ]);

      // Saut direct depuis la liste (2e refrain).
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await idle(tester);
      await tester.tap(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.text('Refrain'),
            )
            .last,
      );
      await idle(tester);
      expect(host.last['index'], 4);
      expect(find.text('Dernière diapositive'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Suivante'))
            .onPressed,
        isNull,
      );

      await tapText(tester, 'Précédente');
      expect(host.last['index'], 3);

      // Écran noir puis retour, sans perdre la position.
      await tester.tap(find.byTooltip('Écran noir'));
      await idle(tester);
      expect(host.last['blank'], isTrue);
      expect(host.last['index'], 3);
      expect(find.text('Écran noir activé'), findsOneWidget);
      await tester.tap(find.byTooltip('Écran noir'));
      await idle(tester);
      expect(host.last['blank'], isFalse);
    },
    hymns: hymns,
    overrides: overrides(),
  );

  testApp(
    'option : refrain non répété, en restant sur la même section',
    (tester, _) async {
      await openProjection(tester);
      await tapText(tester, 'Suivante');
      await tester.tap(find.byType(PopupMenuButton<String>));
      await idle(tester);
      await tester.tap(find.byType(CheckedPopupMenuItem<String>));
      await idle(tester);
      expect(host.last['count'], 4, reason: 'ordre imprimé : titre, C1, R, C2');
      expect(host.last['index'], 1, reason: 'toujours sur le couplet 1');
    },
    hymns: hymns,
    overrides: overrides(),
  );

  testApp(
    'connexion d’un écran : adresse, code QR, compteur',
    (tester, _) async {
      await openProjection(tester);
      await tester.tap(find.byTooltip('Connecter un écran'));
      await idle(tester);
      expect(
        find.text('http://192.168.43.1:47100/s/k7mx2qpa/'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('http://192.168.43.1:47100/s/k7mx2qpa/'),
        findsOneWidget,
      );
      expect(find.text('Autres adresses possibles'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await idle(tester);

      host.connectScreens(1);
      await idle(tester);
      expect(find.text('1 écran connecté'), findsOneWidget);
    },
    hymns: hymns,
    overrides: overrides(),
  );

  testApp(
    'quitter avec un écran connecté : confirmation, puis fin de session',
    (tester, _) async {
      await openProjection(tester);
      host.connectScreens(1);
      await idle(tester);
      await tester.tap(find.byType(BackButton));
      await idle(tester);
      expect(find.text('Arrêter la projection ?'), findsOneWidget);
      await tapText(tester, 'Arrêter');
      expect(find.text('Projection'), findsNothing);
      expect(host.stoppedWithEndSession, isTrue);
    },
    hymns: hymns,
    overrides: overrides(),
  );

  testApp(
    'serveur impossible à démarrer : message clair',
    (tester, _) async {
      await openProjection(tester);
      expect(
        find.text('La projection n’a pas pu démarrer sur ce téléphone.'),
        findsOneWidget,
      );
    },
    hymns: hymns,
    overrides: overrides(failing: true),
  );

  testApp(
    'programme de culte : moments libres et cantiques à la suite',
    (tester, _) async {
      final auth = FakeAuthService();
      // Connexion, création d'un programme : « Accueil » puis le cantique 12.
      await tapText(tester, 'Plus');
      await tapText(tester, 'Mon compte');
      await tester.enterText(find.byType(TextField), 'responsable@exemple.org');
      await tapText(tester, 'Recevoir le lien de connexion');
      await tester.enterText(find.byType(TextField), '12345678');
      await tapText(tester, 'Valider le code');
      await tester.tap(find.byType(BackButton).last);
      await idle(tester);
      await tapText(tester, 'Culte');
      await tapText(tester, 'Nouveau programme');
      await tester.enterText(
        find.widgetWithText(TextField, 'Titre du programme'),
        'Culte du soir',
      );
      await tapText(tester, 'Créer');
      await tapText(tester, 'Ajouter un moment');
      // Boîte de dialogue : le champ « N° » de l'éditeur est aussi présent.
      await tester.enterText(find.byType(TextField).last, 'Accueil');
      await tapText(tester, 'Créer');
      await tapText(tester, 'Ajouter un cantique');
      await tester.enterText(find.byType(TextField), '12');
      await idle(tester);
      await tapText(tester, 'Cantique projeté');

      await tester.tap(find.byTooltip('Projeter'));
      await idle(tester);
      expect(
        host.last['count'],
        6,
        reason: 'Accueil + 5 diapositives du cantique',
      );
      expect(host.last['slide'], {'kind': 'section', 'label': 'Accueil'});
      await tapText(tester, 'Suivante');
      expect((host.last['slide']! as Map)['title'], 'Cantique projeté');
      expect(
        auth.currentUser,
        isNull,
        reason: 'le faux service de ce test n’est pas utilisé',
      );
    },
    hymns: hymns,
    overrides: [
      ...overrides(),
      authServiceProvider.overrideWith((ref) => _auth),
      userSyncProvider.overrideWith(
        (ref) => UserSync(
          db: ref.watch(appDatabaseProvider),
          remote: AcceptingUserRemote(),
          isSignedIn: () => _auth.currentUser != null,
        ),
      ),
    ],
  );
}

final _auth = FakeAuthService();
