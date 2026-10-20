import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import 'faithful_journey_test.dart' show idle;

void main() {
  testApp('hors connexion : état réel, vérification sans fausse progression', (
    tester,
    _,
  ) async {
    await tester.tap(find.text('Plus').last);
    await idle(tester);
    await tester.tap(find.text('Hors connexion'));
    await idle(tester);

    expect(find.text('Recueil sur cet appareil'), findsOneWidget);
    expect(find.text('Cantiques'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Rechercher une mise à jour'));
    await idle(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    // Résultat réel affiché sur place (sans backend : aucune vérification).
    const outcomes = [
      'Le recueil est à jour.',
      'Recueil mis à jour.',
      'Pas de connexion : le recueil local reste disponible.',
      'La mise à jour reçue était invalide ; le recueil local est conservé.',
      'Aucune mise à jour disponible.',
    ];
    expect(
      outcomes.where((t) => find.text(t).evaluate().isNotEmpty),
      hasLength(1),
    );
  });
}
