import 'package:flutter/foundation.dart';

import '../catalog/catalog_models.dart';
import '../catalog/catalog_repository.dart';
import '../database/app_database.dart';

/// Source distante du catalogue publié (RPC Supabase en production).
abstract interface class CatalogRemote {
  /// Dernière release, ou `null` si rien n'est publié.
  Future<CatalogManifest?> manifest();
  Future<CatalogSnapshot> snapshot();
  Future<CatalogDelta> delta(int fromRelease);
}

/// Instantané embarqué dans l'application (null s'il est absent du build).
abstract interface class BundledCatalogSource {
  Future<CatalogSnapshot?> load();
}

sealed class CatalogSyncOutcome {
  const CatalogSyncOutcome();
}

/// Le catalogue local est la dernière release.
final class CatalogUpToDate extends CatalogSyncOutcome {
  const CatalogUpToDate(this.releaseId);
  final int releaseId;
}

/// Une nouvelle release a été appliquée.
final class CatalogUpdated extends CatalogSyncOutcome {
  const CatalogUpdated({
    required this.fromRelease,
    required this.toRelease,
    required this.viaDelta,
    required this.changed,
    required this.removed,
  });
  final int? fromRelease;
  final int toRelease;
  final bool viaDelta;
  final int changed;
  final int removed;
}

/// Vérification non faite (contrôle récent, ou aucune release publiée).
final class CatalogCheckSkipped extends CatalogSyncOutcome {
  const CatalogCheckSkipped(this.reason);
  final String reason;
}

/// Réseau ou serveur indisponible : le catalogue local reste utilisable.
final class CatalogOffline extends CatalogSyncOutcome {
  const CatalogOffline(this.error);
  final Object error;
}

/// Contenu reçu invalide ou incohérent : mise à jour annulée, catalogue intact.
final class CatalogUpdateRejected extends CatalogSyncOutcome {
  const CatalogUpdateRejected(this.error);
  final Object error;
}

/// Synchronisation du catalogue (ADR-005). Ne lève jamais d'exception vers
/// l'interface : chaque issue est décrite par un [CatalogSyncOutcome].
class CatalogSync {
  CatalogSync({
    required AppDatabase db,
    required this._remote,
    required this._bundled,
    DateTime Function()? now,
    this.minInterval = const Duration(hours: 1),
    this.deltaLimit = 300,
  }) : _db = db,
       _repo = CatalogRepository(db),
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final CatalogRepository _repo;
  final CatalogRemote _remote;
  final BundledCatalogSource _bundled;
  final DateTime Function() _now;

  /// Intervalle minimal entre deux vérifications automatiques.
  final Duration minInterval;

  /// Au-delà de ce nombre de cantiques modifiés, un instantané complet est préféré.
  final int deltaLimit;

  static const _lastCheckKey = 'catalog.lastCheck';

  /// Garantit qu'un catalogue local existe, à partir de l'instantané embarqué.
  /// Renvoie vrai si un catalogue est disponible (fonctionnement hors connexion).
  Future<bool> ensureLocalCatalog() async {
    if (await _repo.currentReleaseId() != null) return true;
    final snapshot = await _bundled.load();
    if (snapshot == null) return false;
    await _repo.replaceAll(snapshot);
    return true;
  }

  /// Cherche une nouvelle release et l'applique. [force] ignore l'intervalle minimal.
  Future<CatalogSyncOutcome> refresh({bool force = false}) async {
    if (!force && !await _checkDue()) {
      return const CatalogCheckSkipped('Vérification récente');
    }

    final CatalogManifest? manifest;
    try {
      manifest = await _remote.manifest();
    } on Object catch (error) {
      return CatalogOffline(error);
    }
    await _markChecked();
    if (manifest == null) {
      return const CatalogCheckSkipped('Aucune release publiée');
    }

    final current = await _repo.currentReleaseId();
    if (current == manifest.releaseId) return CatalogUpToDate(current!);

    try {
      if (current != null) {
        final delta = await _remote.delta(current);
        if (!delta.fullSnapshotRequired && delta.upserts.length <= deltaLimit) {
          await _repo.applyDelta(
            delta,
            contentHash: manifest.contentHash,
            expectedCount: manifest.hymnCount,
          );
          return CatalogUpdated(
            fromRelease: current,
            toRelease: delta.toRelease,
            viaDelta: true,
            changed: delta.upserts.length,
            removed: delta.removedIds.length,
          );
        }
      }
      final snapshot = await _remote.snapshot();
      await _repo.replaceAll(snapshot, expectedCount: manifest.hymnCount);
      return CatalogUpdated(
        fromRelease: current,
        toRelease: snapshot.releaseId,
        viaDelta: false,
        changed: snapshot.hymns.length,
        removed: 0,
      );
    } on FormatException catch (error) {
      return CatalogUpdateRejected(error);
    } on StateError catch (error) {
      return CatalogUpdateRejected(error);
    } on Object catch (error) {
      return CatalogOffline(error);
    }
  }

  Future<bool> _checkDue() async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(_lastCheckKey))).getSingleOrNull();
    if (row == null) return true;
    final last = DateTime.tryParse(row.value);
    return last == null || _now().difference(last) >= minInterval;
  }

  Future<void> _markChecked() => _db
      .into(_db.syncState)
      .insertOnConflictUpdate(
        SyncStateCompanion.insert(
          key: _lastCheckKey,
          value: _now().toUtc().toIso8601String(),
        ),
      );

  @visibleForTesting
  CatalogRepository get repository => _repo;
}
