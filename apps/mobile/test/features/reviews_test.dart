import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/providers.dart';
import 'package:louanges_a_dieu/core/community/community.dart';

import '../core/community/community_test.dart' show FakeCommunity;
import '../support/app_harness.dart';
import '../support/fake_auth.dart';
import 'worship_test.dart' show signIn, tapText;

/// Avis sur un cantique (planche 8, choix du propriétaire) et réglage des
/// statistiques anonymes.
void main() {
  late FakeCommunity community;
  late FakeAuthService auth;
  setUp(() {
    community = FakeCommunity()
      ..reviewsResult = HymnReviews(
        enabled: true,
        count: 1,
        average: 5,
        reviews: [
          Review(
            rating: 5,
            body: 'Un chant qui console.',
            reply: 'Merci pour votre message.',
            createdAt: DateTime.utc(2026, 10, 20),
          ),
        ],
        mine: null,
      );
    auth = FakeAuthService();
  });

  testApp(
    'fiche : onglet Avis, puis donner son avis une fois connecté',
    (tester, _) async {
      await signIn(tester);
      await tapText(tester, 'Recueil');
      await tapText(tester, 'Au matin');
      await tapText(tester, 'Avis');
      expect(find.text('Un chant qui console.'), findsOneWidget);
      expect(
        find.text('Réponse de l’équipe : Merci pour votre message.'),
        findsOneWidget,
      );
      expect(find.text('1 avis'), findsOneWidget);

      await tapText(tester, 'Donner mon avis');
      await tester.tap(find.byTooltip('4 étoiles'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Commentaire (facultatif)'),
        'Très beau',
      );
      await tapText(tester, 'Envoyer');
      expect(community.submitted.single.$2, 4);
      expect(community.submitted.single.$3, 'Très beau');
      expect(find.text('En attente de validation'), findsOneWidget);
    },
    overrides: [
      authServiceProvider.overrideWith((ref) => auth),
      communityRemoteProvider.overrideWith((ref) => community),
    ],
  );

  testApp('sans backend : pas d’onglet Avis', (tester, _) async {
    await tapText(tester, 'Recueil');
    await tapText(tester, 'Au matin');
    expect(find.text('Avis'), findsNothing);
  });

  testApp('confidentialité : statistiques anonymes désactivables', (
    tester,
    _,
  ) async {
    await tapText(tester, 'Plus');
    await tapText(tester, 'Confidentialité');
    await tapText(tester, 'Statistiques anonymes');
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Statistiques anonymes'),
          )
          .value,
      isFalse,
    );
  }, overrides: [communityRemoteProvider.overrideWith((ref) => community)]);
}
