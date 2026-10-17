import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/database/app_database.dart';

import 'generated/schema.dart';

/// Le schéma créé par l'application doit être exactement l'instantané figé de
/// sa version (drift_schemas/). Modifier une table sans incrémenter
/// schemaVersion ni écrire de migration fait échouer ce test (tâche 4.7).
/// Les tests de migration v(n) → v(n+1) sont générés par
/// `dart run drift_dev make-migrations` dès la version 2.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('le schéma courant correspond à l’instantané de sa version', () async {
    final connection = await verifier.startAt(AppDatabase.currentSchemaVersion);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    // Base créée depuis l'instantané figé ; le code doit attendre exactement ce schéma.
    await db.validateDatabaseSchema();
  });
}
