import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_service.dart';
import '../core/catalog/bundled_catalog.dart';
import '../core/catalog/catalog_repository.dart';
import '../core/database/app_database.dart';
import '../core/network/supabase_remotes.dart';
import '../core/search/search_service.dart';
import '../core/sharing/share_links.dart';
import '../core/sync/catalog_sync.dart';
import '../core/sync/user_sync.dart';
import '../core/user_data/user_data_repository.dart';
import 'account.dart';
import 'env.dart';

/// Base locale de l'appareil.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    driftDatabase(
      name: 'louanges_a_dieu',
      // Aperçu web (développement uniquement) : SQLite en WebAssembly.
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );
  ref.onDispose(db.close);
  return db;
});

/// Client Supabase, ou null si aucun backend n'est configuré (mode hors ligne).
final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => ref.watch(envProvider).hasBackend ? Supabase.instance.client : null,
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(appDatabaseProvider)),
);

final searchServiceProvider = Provider<SearchService>(
  (ref) => SearchService(ref.watch(appDatabaseProvider)),
);

final userDataRepositoryProvider = Provider<UserDataRepository>(
  (ref) => UserDataRepository(
    ref.watch(appDatabaseProvider),
    onChanged: () => ref.read(syncRunnerProvider.notifier).requestSync(),
  ),
);

/// Adresse de retour du lien de connexion : schéma de l'app sur mobile,
/// origine de la page pour l'aperçu web. À autoriser dans Supabase
/// (Authentication → URL Configuration).
const mobileAuthRedirect = 'org.louangesadieu.app://login-callback/';

final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const NoBackendAuthService();
  return SupabaseAuthService(
    client,
    redirectTo: kIsWeb ? Uri.base.origin : mobileAuthRedirect,
  );
});

final catalogSyncProvider = Provider<CatalogSync>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CatalogSync(
    db: ref.watch(appDatabaseProvider),
    remote: client == null
        ? const NoBackendCatalogRemote()
        : SupabaseCatalogRemote(client),
    bundled: AssetBundledCatalogSource(),
  );
});

final userSyncProvider = Provider<UserSync?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return UserSync(
    db: ref.watch(appDatabaseProvider),
    remote: SupabaseUserDataRemote(client),
    isSignedIn: () => ref.read(authServiceProvider).currentUser != null,
  );
});

/// Démarrage du catalogue : installation de l'instantané embarqué si besoin
/// (hors connexion), puis recherche d'une mise à jour en arrière-plan.
/// Renvoie vrai si un catalogue local est disponible.
final catalogBootstrapProvider = FutureProvider<bool>((ref) async {
  final sync = ref.watch(catalogSyncProvider);
  final available = await sync.ensureLocalCatalog();
  if (available) {
    // Ne bloque pas l'affichage : la mise à jour se fait en tâche de fond.
    sync.refresh().ignore();
    return true;
  }
  final outcome = await sync.refresh(force: true);
  return outcome is CatalogUpdated;
});

/// Liens de partage, ou null sans backend.
final shareLinksProvider = Provider<ShareLinks?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseShareLinks(client);
});
