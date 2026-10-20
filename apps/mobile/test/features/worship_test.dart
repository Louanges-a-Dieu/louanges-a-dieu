import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/providers.dart';
import 'package:louanges_a_dieu/core/sync/user_sync.dart';

import '../support/app_harness.dart';
import '../support/fake_auth.dart';
import '../support/fake_services.dart';

/// Programme de culte et partage (Phase 7, T-006 et T-007 côté application).

Future<void> idle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await idle(tester);
}

Future<void> back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).last);
  await idle(tester);
}

Future<void> signIn(WidgetTester tester) async {
  await tapText(tester, 'Plus');
  await tapText(tester, 'Mon compte');
  await tester.enterText(find.byType(TextField), 'responsable@exemple.org');
  await tapText(tester, 'Recevoir le lien de connexion');
  await tester.enterText(find.byType(TextField), '12345678');
  await tapText(tester, 'Valider le code');
  await back(tester);
}

/// Crée un programme et ouvre son éditeur.
Future<void> newProgram(WidgetTester tester, String title) async {
  await tapText(tester, 'Culte');
  await tapText(tester, 'Nouveau programme');
  await tester.enterText(find.byType(TextField), title);
  await tapText(tester, 'Créer');
}

Future<void> addHymn(WidgetTester tester, String query, String title) async {
  await tapText(tester, 'Ajouter un cantique');
  await tester.enterText(find.byType(TextField), query);
  await idle(tester);
  await tapText(tester, title);
}

/// Menu « … » de la ligne portant [title] (et non celui de la barre du haut).
Future<void> openRowMenu(WidgetTester tester, String title) async {
  await tester.tap(
    find.descendant(
      of: find.widgetWithText(ListTile, title),
      matching: find.byType(PopupMenuButton<String>),
    ),
  );
  await idle(tester);
}

List<String?> rows(WidgetTester tester, List<String> candidates) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .where(candidates.contains)
    .toList();

void main() {
  late FakeAuthService auth;
  late AcceptingUserRemote remote;
  late FakeShareLinks links;

  setUp(() {
    auth = FakeAuthService();
    remote = AcceptingUserRemote();
    links = FakeShareLinks();
  });

  List<Override> services() => [
    authServiceProvider.overrideWith((ref) => auth),
    shareLinksProvider.overrideWith((ref) => links),
    userSyncProvider.overrideWith(
      (ref) => UserSync(
        db: ref.watch(appDatabaseProvider),
        remote: remote,
        isSignedIn: () => auth.currentUser != null,
      ),
    ),
  ];
  const env = {
    'APP_ENV': 'dev',
    'PUBLIC_WEB_URL': 'https://louanges.exemple.org',
  };

  testApp(
    'visiteur : l’onglet Culte invite à se connecter',
    (tester, _) async {
      await tapText(tester, 'Culte');
      expect(
        find.text('Les programmes sont liés à votre compte'),
        findsOneWidget,
      );
    },
    overrides: services(),
    env: env,
  );

  testApp(
    'ajout par numéro imprimé, message si le numéro n’existe pas',
    (tester, _) async {
      await signIn(tester);
      await newProgram(tester, 'Culte du matin');
      final field = find.widgetWithText(TextField, 'N° (ex. 37bis)');

      await tester.enterText(field, '37 BIS');
      await tester.tap(find.byTooltip('Ajouter ce numéro'));
      await idle(tester);
      expect(find.text('Autre texte sur la même mélodie'), findsOneWidget);
      expect(find.text('Cantique 37bis ajouté au programme.'), findsOneWidget);

      await tester.enterText(field, '999');
      await tester.tap(find.byTooltip('Ajouter ce numéro'));
      await idle(tester);
      expect(
        find.text('Le numéro 999 n’existe pas dans le recueil.'),
        findsOneWidget,
      );
    },
    overrides: services(),
    env: env,
  );

  testApp(
    'T-006 : créer un programme, ajouter, ordonner, annoter, retrouver',
    (tester, _) async {
      await signIn(tester);
      await newProgram(tester, 'Culte de Pâques');
      expect(find.text('Programme vide'), findsOneWidget);

      await addHymn(tester, '37', 'Au matin');
      await tapText(tester, 'Ajouter un moment');
      // Boîte de dialogue : le champ « N° » de l'éditeur est aussi présent.
      await tester.enterText(find.byType(TextField).last, 'Accueil');
      await tapText(tester, 'Créer');
      expect(rows(tester, ['Au matin', 'Accueil']), ['Au matin', 'Accueil']);

      // « Monter » le moment d'accueil (commande accessible équivalente au glisser).
      await openRowMenu(tester, 'Accueil');
      await tapText(tester, 'Monter');
      expect(rows(tester, ['Au matin', 'Accueil']), ['Accueil', 'Au matin']);

      // Note sur le cantique.
      await openRowMenu(tester, 'Au matin');
      await tapText(tester, 'Modifier la note');
      // Boîte de dialogue : le champ « N° » de l'éditeur est aussi présent.
      await tester.enterText(find.byType(TextField).last, 'Couplets 1 et 3');
      await tapText(tester, 'Enregistrer');
      expect(find.text('Couplets 1 et 3'), findsOneWidget);

      // Retrouvé dans la liste des programmes, puis rouvert à l'identique.
      await back(tester);
      expect(find.text('Culte de Pâques'), findsOneWidget);
      await tapText(tester, 'Culte de Pâques');
      expect(rows(tester, ['Au matin', 'Accueil']), ['Accueil', 'Au matin']);
    },
    overrides: services(),
    env: env,
  );

  testApp(
    'T-007 : partager publie, envoie et donne toujours le même lien',
    (tester, _) async {
      await signIn(tester);
      await newProgram(tester, 'Culte du soir');
      await addHymn(tester, '37', 'Au matin');

      await tester.tap(find.byTooltip('Partager'));
      await idle(tester);
      const first =
          'https://louanges.exemple.org/programme/jeton000000000000000000000000001';
      expect(find.text(first), findsOneWidget);
      expect(
        remote.pushedServices.last.status,
        'published',
        reason: 'publié avant le partage',
      );
      expect(remote.pushedServices.last.items, hasLength(1));

      // Partager à nouveau : même lien (les liens déjà envoyés restent valides).
      await tester.tapAt(const Offset(10, 10));
      await idle(tester);
      await tester.tap(find.byTooltip('Partager'));
      await idle(tester);
      expect(find.text(first), findsOneWidget);

      // Désactiver puis recréer : nouveau lien.
      await tapText(tester, 'Désactiver le lien');
      expect(find.text(first), findsNothing);
      await tapText(tester, 'Créer un nouveau lien');
      expect(
        find.textContaining('jeton000000000000000000000000002'),
        findsOneWidget,
      );
    },
    overrides: services(),
    env: env,
  );

  testApp(
    'partage hors connexion : message, rien n’est perdu',
    (tester, _) async {
      await signIn(tester);
      await newProgram(tester, 'Culte sans réseau');
      remote.offline = true;
      await tester.tap(find.byTooltip('Partager'));
      await idle(tester);
      expect(
        find.text('Le partage nécessite une connexion Internet.'),
        findsOneWidget,
      );
    },
    overrides: services(),
    env: env,
  );

  testApp(
    'archiver : section « Archivés », lien inactif, puis désarchiver',
    (tester, _) async {
      await signIn(tester);
      await newProgram(tester, 'Culte de Noël');
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await idle(tester);
      await tapText(tester, 'Archiver');
      expect(
        find.text(
          'Programme archivé : son lien de partage ne fonctionne plus.',
        ),
        findsOneWidget,
      );
      await back(tester);
      expect(find.text('ARCHIVÉS'), findsOneWidget);
      expect(find.textContaining('Archivé'), findsWidgets);

      await tapText(tester, 'Culte de Noël');
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await idle(tester);
      await tapText(tester, 'Désarchiver');
      await back(tester);
      expect(find.text('ARCHIVÉS'), findsNothing);
      // Synchronisation regroupée 3 s après la dernière modification.
      await tester.pump(const Duration(seconds: 4));
      await idle(tester);
      expect(
        remote.pushedServices.map((s) => s.status),
        containsAllInOrder(['archived', 'draft']),
      );
    },
    overrides: services(),
    env: env,
  );
}
