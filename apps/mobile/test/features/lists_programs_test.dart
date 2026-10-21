import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/providers.dart';
import 'package:louanges_a_dieu/app/state.dart';
import 'package:louanges_a_dieu/core/user_data/user_data_models.dart';

import '../support/app_harness.dart';
import '../support/fake_auth.dart';
import 'worship_test.dart' show back, idle, newProgram, signIn, tapText;

/// Planche 4 : listes (icône, couleur, ajout multiple, lecture à la suite),
/// favoris récents, programmes (lieu, description, image, options, modèles,
/// historique, partage).
void main() {
  late FakeAuthService auth;
  setUp(() => auth = FakeAuthService());
  List<Override> withAuth() => [
    authServiceProvider.overrideWith((ref) => auth),
  ];

  testApp('liste : icône, couleur, ajout multiple, lecture à la suite', (
    tester,
    db,
  ) async {
    await signIn(tester);
    await tapText(tester, 'Favoris');
    await tapText(tester, 'Listes');
    await tapText(tester, 'Nouvelle liste');
    await tester.enterText(
      find.widgetWithText(TextField, 'Nom de la liste'),
      'Prière du soir',
    );
    await tester.tap(find.byTooltip('Prière'));
    await tester.tap(find.bySemanticsLabel('Bleu'));
    await idle(tester);
    await tapText(tester, 'Créer');
    expect(find.text('Prière du soir'), findsOneWidget);
    expect(find.text('Aucun cantique'), findsWidgets);

    await tapText(tester, 'Prière du soir');
    await tester.tap(find.byTooltip('Ajouter des cantiques'));
    await idle(tester);
    await tapText(tester, 'Ô jour heureux');
    await tapText(tester, 'Mon cœur Te loue');
    await tapText(tester, 'Ajouter (2)');
    expect(find.text('2 cantiques'), findsOneWidget);

    final rows = await settle(tester, db.select(db.playlists).get());
    expect(rows.single.icon, 'prayer');
    expect(rows.single.color, 'blue');

    await tapText(tester, 'Lire la liste');
    expect(find.text('Ô jour heureux, jour de bonheur,'), findsOneWidget);
    await tester.tap(find.byTooltip('Cantique suivant'));
    await idle(tester);
    // Le cantique suivant est celui de la liste (n° 3), pas le n° 2.
    expect(find.text('Mon cœur Te loue, Seigneur,'), findsOneWidget);
  }, overrides: withAuth());

  testApp('fiche : cases à cocher des listes', (tester, db) async {
    await signIn(tester);
    final repo = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).read(userDataRepositoryProvider);
    await settle(tester, repo.createPlaylist('Louange'));
    await settle(tester, repo.createPlaylist('Mariage'));

    await tapText(tester, 'Recueil');
    await tapText(tester, 'Au matin');
    await tester.tap(find.byTooltip('Actions'));
    await idle(tester);
    await tapText(tester, 'Ajouter à une liste');
    await tapText(tester, 'Louange');
    await tapText(tester, 'Mariage');
    await tapText(tester, 'Valider');
    expect(find.text('Ajouté à 2 listes'), findsOneWidget);

    // Décocher retire le cantique de la liste.
    await tester.tap(find.byTooltip('Actions'));
    await idle(tester);
    await tapText(tester, 'Ajouter à une liste');
    await tapText(tester, 'Mariage');
    await tapText(tester, 'Valider');
    expect(find.text('Listes mises à jour'), findsOneWidget);
    final items = await settle(tester, db.select(db.playlistItems).get());
    expect(items, hasLength(1));
  }, overrides: withAuth());

  testApp('favoris : par numéro ou du plus récent', (tester, _) async {
    for (final title in ['Mon cœur Te loue', 'Ô jour heureux']) {
      await tester.tap(find.text('Recueil').last);
      await idle(tester);
      await tester.tap(find.text(title));
      await idle(tester);
      await tester.tap(find.byTooltip('Ajouter aux favoris'));
      await idle(tester);
      await back(tester);
      // Les favoris sont horodatés à la milliseconde.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    await tester.tap(find.text('Favoris').last);
    await idle(tester);
    List<String?> order() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d == 'Mon cœur Te loue' || d == 'Ô jour heureux')
        .toList();
    expect(order(), ['Ô jour heureux', 'Mon cœur Te loue']);
    await tapText(tester, 'Récents');
    expect(order(), ['Ô jour heureux', 'Mon cœur Te loue']);
  });

  testApp('programme : lieu, description, image, options, modèle, historique', (
    tester,
    db,
  ) async {
    await signIn(tester);
    await tapText(tester, 'Culte');
    await tapText(tester, 'Nouveau programme');
    await tester.enterText(
      find.widgetWithText(TextField, 'Titre du programme'),
      'Culte de louange',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Lieu (facultatif)'),
      'Temple central',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Description (facultatif)'),
      'Louange et adoration.',
    );
    await tester.tap(find.bySemanticsLabel('Photo 1'));
    await idle(tester);
    await tapText(tester, 'Créer');
    expect(find.text('Temple central'), findsOneWidget);
    expect(find.text('Louange et adoration.'), findsOneWidget);

    // Options de projection.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await idle(tester);
    await tapText(tester, 'Options de projection');
    await tapText(tester, 'Transitions entre les cantiques');
    await tapText(tester, 'Clair');
    await tester.enterText(
      find.widgetWithText(TextField, 'Message de fin (facultatif)'),
      'Merci Seigneur !',
    );
    await tapText(tester, 'Enregistrer');
    var service = (await settle(
      tester,
      db.select(db.worshipServices).get(),
    )).single;
    expect(service.location, 'Temple central');
    expect(service.cover, 'hero_wheat_sunset');
    final options = ProgramOptions.decode(service.options);
    expect(options.transitions, isTrue);
    expect(options.background, 'light');
    expect(options.endMessage, 'Merci Seigneur !');

    // Modèle.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await idle(tester);
    await tapText(tester, 'Enregistrer comme modèle');
    expect(find.text('Enregistré dans les modèles.'), findsOneWidget);
    await back(tester);
    await tapText(tester, 'Modèles');
    expect(find.text('Culte de louange'), findsOneWidget);
    await tapText(tester, 'Utiliser');
    service = (await settle(
      tester,
      db.select(db.worshipServices).get(),
    )).where((s) => !s.isTemplate).last;
    expect(service.location, 'Temple central');
    expect(ProgramOptions.decode(service.options).transitions, isTrue);
  }, overrides: withAuth());

  testApp(
    'programme passé : dans l’historique ; partage en image ou en texte',
    (tester, _) async {
      await signIn(tester);
      await newProgram(tester, 'Culte de Noël 2025');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      final id = (await settle(
        tester,
        container.read(worshipServicesProvider.future),
      )).single.id;
      await settle(
        tester,
        container
            .read(userDataRepositoryProvider)
            .updateWorshipService(id, serviceDate: '2025-12-25'),
      );
      await tester.tap(find.byTooltip('Partager'));
      await idle(tester);
      expect(find.text('Lien en ligne'), findsOneWidget);
      expect(find.text('Partager en image'), findsOneWidget);
      expect(find.text('Partager le texte'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await idle(tester);
      await back(tester);
      expect(find.text('Culte de Noël 2025'), findsNothing);
      await tapText(tester, 'Historique');
      expect(find.text('Culte de Noël 2025'), findsOneWidget);
    },
    overrides: withAuth(),
  );
}
