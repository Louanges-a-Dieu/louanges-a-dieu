import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Lien vers la politique de confidentialité (exigence des stores, 10.7).
Future<void> openMore(WidgetTester tester) async {
  await tester.tap(find.text('Plus').last);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.tap(find.text('Confidentialité'));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testApp(
    'Plus → Confidentialité : lien vers la politique quand le site est configuré',
    (tester, _) async {
      await openMore(tester);
      expect(find.text('Politique de confidentialité'), findsOneWidget);
    },
    env: const {
      'APP_ENV': 'dev',
      'PUBLIC_WEB_URL': 'https://louanges.exemple.org',
    },
  );

  testApp('Plus → Confidentialité : pas de lien sans site configuré', (
    tester,
    _,
  ) async {
    await openMore(tester);
    expect(find.text('Politique de confidentialité'), findsNothing);
  });
}
