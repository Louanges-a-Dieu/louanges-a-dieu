import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testApp("l'app démarre sans compte ni réseau et affiche l'accueil", (
    tester,
    _,
  ) async {
    expect(find.text('Louanges à Dieu'), findsOneWidget);
    expect(find.text('Recueil de cantiques'), findsOneWidget);
  });
}
