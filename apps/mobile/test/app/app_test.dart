import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/app.dart';
import 'package:louanges_a_dieu/app/env.dart';

void main() {
  testWidgets("l'app démarre sans compte ni réseau et affiche l'accueil", (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          envProvider.overrideWithValue(Env.parse(const {'APP_ENV': 'dev'})),
        ],
        child: const LouangesApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Louanges à Dieu'), findsOneWidget);
    expect(find.text('Recueil de cantiques'), findsOneWidget);
  });
}
