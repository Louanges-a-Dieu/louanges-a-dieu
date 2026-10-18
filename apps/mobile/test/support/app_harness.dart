import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/app/app.dart';
import 'package:louanges_a_dieu/app/env.dart';
import 'package:louanges_a_dieu/app/providers.dart';
import 'package:louanges_a_dieu/app/state.dart';
import 'package:louanges_a_dieu/core/catalog/catalog_repository.dart';
import 'package:louanges_a_dieu/core/database/app_database.dart';

import 'catalog_fixtures.dart';

/// Test de l'application complète sur une base en mémoire, sans réseau ni
/// compte, avec le recueil synthétique (ou [hymns]) déjà installé.
///
/// - Les opérations Drift restent dans la zone du test (temps simulé) : les
///   mélanger avec `runAsync` (temps réel) interbloque le verrou de Drift.
/// - L'interface est démontée À L'INTÉRIEUR du test : les flux Drift se ferment
///   par un minuteur qui doit s'exécuter avant la vérification finale.
void testApp(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body, {
  List<Map<String, Object?>>? hymns,
  DateTime? today,
}) {
  testWidgets(description, (tester) async {
    final db = memoryDatabase();
    await settle(
      tester,
      CatalogRepository(db).replaceAll(snapshotOf(1, hymns ?? sampleHymns())),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          envProvider.overrideWithValue(Env.parse(const {'APP_ENV': 'dev'})),
          appDatabaseProvider.overrideWithValue(db),
          catalogBootstrapProvider.overrideWith((ref) async => true),
          todayProvider.overrideWithValue(today ?? DateTime(2026, 10, 18)),
        ],
        child: const LouangesApp(),
      ),
    );
    await tester.pumpAndSettle();
    try {
      await body(tester, db);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await settle(tester, db.close());
    }
  });
}

/// Attend [future] en faisant avancer le temps simulé : Drift utilise des
/// minuteurs qui, sinon, ne se déclencheraient jamais. Échoue au lieu de
/// bloquer si l'opération ne se termine pas.
Future<T> settle<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  T? result;
  Object? error;
  unawaited(
    future.then(
      (v) {
        result = v;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    ),
  );
  for (var i = 0; !done; i++) {
    if (i > 500) {
      throw StateError('Opération de base non terminée (5 s de temps simulé)');
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
  if (error != null) throw error!;
  return result as T;
}
