import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/network/supabase_remotes.dart';
import 'package:louanges_a_dieu/core/sync/user_sync.dart';
import 'package:louanges_a_dieu/core/user_data/user_data_models.dart';
import 'package:louanges_a_dieu/core/user_data/user_data_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/catalog_fixtures.dart';

/// Synchronisation et suppression de compte avec une VRAIE session Supabase,
/// sur la base de DÉVELOPPEMENT. Prérequis (non versionnés) : config/dev.json
/// et config/dev-test-user.json, créé par
/// `node tools/pgtap/create-test-user.ts`. Le test supprime ce compte à la
/// fin : relancer le script avant chaque exécution. Sauté sans ces fichiers.
void main() {
  final config = File('config/dev.json');
  final user = File('config/dev-test-user.json');
  final skip = config.existsSync() && user.existsSync()
      ? false
      : 'compte de test absent (node tools/pgtap/create-test-user.ts)';

  test(
    'deux appareils, un compte : favoris, liste, programme, retrait, puis suppression du compte',
    () async {
      final c = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
      final u = jsonDecode(user.readAsStringSync()) as Map<String, Object?>;
      final client = SupabaseClient(
        c['SUPABASE_URL']! as String,
        c['SUPABASE_PUBLISHABLE_KEY']! as String,
      );
      await client.auth.signInWithPassword(
        email: u['email']! as String,
        password: u['password']! as String,
      );
      expect(client.auth.currentSession, isNotNull);

      // Deux cantiques réellement publiés.
      final snapshot = await SupabaseCatalogRemote(client).snapshot();
      final h1 = snapshot.hymns[0].hymn.id;
      final h2 = snapshot.hymns[1].hymn.id;

      final remote = SupabaseUserDataRemote(client);
      final dbA = memoryDatabase();
      final dbB = memoryDatabase();
      addTearDown(() async {
        await dbA.close();
        await dbB.close();
      });
      final a = UserDataRepository(dbA);
      final b = UserDataRepository(dbB);
      final syncA = UserSync(db: dbA, remote: remote, isSignedIn: () => true);
      final syncB = UserSync(db: dbB, remote: remote, isSignedIn: () => true);

      await a.setFavorite(h1, isFavorite: true);
      final listId = await a.createPlaylist('Liste d’intégration');
      await a.setPlaylistHymns(listId, [h2, h1]);
      final serviceId = await a.createWorshipService(
        'Culte d’intégration',
        serviceDate: '2027-01-03',
      );
      await a.setWorshipServiceItems(serviceId, [
        const WorshipItemDto(
          id: '00000000-0000-4000-a000-00000000aa01',
          hymnId: null,
          label: 'Accueil',
          notes: null,
        ),
        WorshipItemDto(
          id: '00000000-0000-4000-a000-00000000aa02',
          hymnId: h1,
          label: null,
          notes: null,
        ),
      ]);

      expect(
        await syncA.sync(),
        isA<UserSyncDone>().having((o) => o.pushed, 'envoyés', 3),
      );
      expect(await a.pendingCount(), 0);

      expect(await syncB.sync(), isA<UserSyncDone>());
      expect(await b.watchFavoriteIds().first, {h1});
      expect(await b.playlistHymnIds(listId), [h2, h1]);
      final items = await b.worshipServiceItems(serviceId);
      expect(items.map((i) => i.label ?? i.hymnId), ['Accueil', h1]);

      // Retrait sur B, propagé à A (pierre tombale).
      await b.setFavorite(h1, isFavorite: false);
      await syncB.sync();
      await syncA.sync();
      expect(await a.watchFavoriteIds().first, isEmpty);

      // Suppression réelle du compte : plus aucune connexion possible.
      await client.rpc<void>('delete_my_account');
      await client.auth.signOut(scope: SignOutScope.local);
      await expectLater(
        client.auth.signInWithPassword(
          email: u['email']! as String,
          password: u['password']! as String,
        ),
        throwsA(isA<AuthException>()),
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
