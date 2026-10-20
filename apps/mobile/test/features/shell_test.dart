import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/features/hymnal/hymnal_screen.dart';

import '../support/app_harness.dart';

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testApp('téléphone : barre de navigation inférieure', (tester, _) async {
    useSize(tester, const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testApp('tablette : navigation latérale, mêmes destinations', (
    tester,
    _,
  ) async {
    useSize(tester, const Size(1024, 768));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('Recueil'));
    await tester.pumpAndSettle();
    expect(find.byType(HymnalScreen), findsOneWidget);
  });

  testApp('grand écran : libellés et marque dans la navigation latérale', (
    tester,
    _,
  ) async {
    useSize(tester, const Size(1366, 900));
    await tester.pumpAndSettle();
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('LOUANGES À DIEU'), findsOneWidget);
  });
}
