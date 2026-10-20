import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/catalog/catalog_models.dart';
import '../core/catalog/hymn_of_the_day.dart';
import '../core/catalog/published_hymn.dart';
import '../core/database/app_database.dart';
import '../core/preferences/preferences.dart';
import '../core/search/search_service.dart';
import '../core/sync/catalog_sync.dart';
import '../core/user_data/reading_history.dart';
import 'providers.dart';

/// Recueil trié par numéro (mis à jour automatiquement après une synchronisation).
final hymnsByNumberProvider = StreamProvider<List<HymnSummary>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchByNumber(),
);

final hymnsAlphabeticalProvider = StreamProvider<List<HymnSummary>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchAlphabetical(),
);

final hymnProvider = FutureProvider.autoDispose.family<PublishedHymn?, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).hymnById(id),
);

final hymnByLabelProvider = FutureProvider.autoDispose
    .family<PublishedHymn?, String>(
      (ref, label) => ref.watch(catalogRepositoryProvider).hymnByLabel(label),
    );

final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, String>(
      (ref, query) => ref.watch(searchServiceProvider).search(query),
    );

final favoriteIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(userDataRepositoryProvider).watchFavoriteIds(),
);

final readingHistoryRepositoryProvider = Provider<ReadingHistoryRepository>(
  (ref) => ReadingHistoryRepository(ref.watch(appDatabaseProvider)),
);

/// Derniers cantiques ouverts encore présents dans le recueil, du plus récent
/// au plus ancien.
final recentHymnsProvider = StreamProvider<List<HymnSummary>>((ref) {
  final hymns = {
    for (final h
        in ref.watch(hymnsByNumberProvider).value ?? const <HymnSummary>[])
      h.id: h,
  };
  return ref
      .watch(readingHistoryRepositoryProvider)
      .watch()
      .map((ids) => [for (final id in ids) ?hymns[id]]);
});

/// Date du jour (surchargée dans les tests).
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

final hymnOfTheDayProvider = Provider<HymnSummary?>((ref) {
  final hymns = ref.watch(hymnsByNumberProvider).value ?? const [];
  return hymnOfTheDay(hymns, ref.watch(todayProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(appDatabaseProvider)),
);

class PreferencesNotifier extends AsyncNotifier<ReadingPreferences> {
  @override
  Future<ReadingPreferences> build() =>
      ref.watch(preferencesRepositoryProvider).load();

  /// Modifie et enregistre les préférences.
  Future<void> change(
    ReadingPreferences Function(ReadingPreferences) apply,
  ) async {
    final next = apply(state.value ?? const ReadingPreferences());
    state = AsyncData(next);
    await ref.read(preferencesRepositoryProvider).save(next);
  }
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesNotifier, ReadingPreferences>(
      PreferencesNotifier.new,
    );

/// État du catalogue local (écran « Hors connexion »).
final catalogStatusProvider =
    FutureProvider<({int? releaseId, int count, DateTime? lastCheck})>((
      ref,
    ) async {
      ref.watch(hymnsByNumberProvider);
      final repo = ref.watch(catalogRepositoryProvider);
      final db = ref.watch(appDatabaseProvider);
      final last = await (db.select(
        db.syncState,
      )..where((s) => s.key.equals('catalog.lastCheck'))).getSingleOrNull();
      return (
        releaseId: await repo.currentReleaseId(),
        count: await repo.count(),
        lastCheck: last == null
            ? null
            : DateTime.tryParse(last.value)?.toLocal(),
      );
    });

/// Vérification manuelle d'une mise à jour du catalogue.
Future<CatalogSyncOutcome> refreshCatalog(WidgetRef ref) async {
  final outcome = await ref.read(catalogSyncProvider).refresh(force: true);
  ref.invalidate(catalogStatusProvider);
  return outcome;
}

final playlistsProvider = StreamProvider<List<PlaylistRow>>(
  (ref) => ref.watch(userDataRepositoryProvider).watchPlaylists(),
);

final playlistHymnIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>(
      (ref, id) =>
          ref.watch(userDataRepositoryProvider).watchPlaylistHymnIds(id),
    );

final worshipServicesProvider = StreamProvider<List<WorshipServiceRow>>(
  (ref) => ref.watch(userDataRepositoryProvider).watchWorshipServices(),
);

final worshipItemsProvider = StreamProvider.autoDispose
    .family<List<WorshipServiceItemRow>, String>(
      (ref, id) =>
          ref.watch(userDataRepositoryProvider).watchWorshipServiceItems(id),
    );
