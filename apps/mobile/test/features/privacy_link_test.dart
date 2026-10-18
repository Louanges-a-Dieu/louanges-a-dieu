import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Lien vers la politique de confidentialité (exigence des stores, 10.7).
Future<void> openMore(WidgetTester tester) async {
  await tester.tap(find.text('Plus').last);
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testApp(
    'Plus : lien « Confidentialité » quand le site est configuré',
    (tester, _) async {
      await openMore(tester);
      expect(find.text('Confidentialité'), findsOneWidget);
    },
    env: const {
      'APP_ENV': 'dev',
      'PUBLIC_WEB_URL': 'https://louanges.exemple.org',
    },
  );

  testApp('Plus : pas de lien sans site configuré', (tester, _) async {
    await openMore(tester);
    expect(find.text('Confidentialité'), findsNothing);
  });
}
