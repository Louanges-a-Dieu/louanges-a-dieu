import 'package:supabase_flutter/supabase_flutter.dart';

import '../catalog/catalog_models.dart';
import '../sync/catalog_sync.dart';
import '../sync/user_sync.dart';
import '../user_data/user_data_models.dart';

const _timeout = Duration(seconds: 30);

Map<String, Object?> _object(Object? value, String rpc) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('$rpc : réponse inattendue');
}

/// Catalogue publié via les RPC publiques (clé publishable, sans compte).
class SupabaseCatalogRemote implements CatalogRemote {
  SupabaseCatalogRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<CatalogManifest?> manifest() async {
    final result = await _client
        .rpc<Object?>('get_catalog_manifest')
        .timeout(_timeout);
    return result == null
        ? null
        : CatalogManifest.fromJson(_object(result, 'get_catalog_manifest'));
  }

  @override
  Future<CatalogSnapshot> snapshot() async {
    final result = await _client
        .rpc<Object?>('get_catalog_snapshot')
        .timeout(_timeout);
    return CatalogSnapshot.fromJson(_object(result, 'get_catalog_snapshot'));
  }

  @override
  Future<CatalogDelta> delta(int fromRelease) async {
    final result = await _client
        .rpc<Object?>(
          'get_catalog_delta',
          params: {'p_from_release': fromRelease},
        )
        .timeout(_timeout);
    return CatalogDelta.fromJson(_object(result, 'get_catalog_delta'));
  }
}

/// Données utilisateur via les RPC sync_* (session de l'utilisateur, RLS).
class SupabaseUserDataRemote implements UserDataRemote {
  SupabaseUserDataRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> pushFavorites(List<FavoriteChange> changes) => _client
      .rpc<void>(
        'sync_push_favorites',
        params: {'p_changes': changes.map((c) => c.toJson()).toList()},
      )
      .timeout(_timeout);

  @override
  Future<void> pushPlaylist(PlaylistDto playlist) => _client
      .rpc<void>(
        'sync_push_playlist',
        params: {'p_playlist': playlist.toJson()},
      )
      .timeout(_timeout);

  @override
  Future<void> pushWorshipService(WorshipServiceDto service) => _client
      .rpc<void>(
        'sync_push_worship_service',
        params: {'p_service': service.toJson()},
      )
      .timeout(_timeout);

  @override
  Future<UserChanges> pull(int since) async {
    final result = await _client
        .rpc<Object?>('sync_pull', params: {'p_since': since})
        .timeout(_timeout);
    return UserChanges.fromJson(_object(result, 'sync_pull'));
  }
}

/// Utilisé quand aucun backend n'est configuré : se comporte comme une
/// absence de réseau (l'app reste pleinement utilisable hors connexion).
class NoBackendCatalogRemote implements CatalogRemote {
  const NoBackendCatalogRemote();

  static Never _offline() => throw StateError('Aucun backend configuré');

  @override
  Future<CatalogManifest?> manifest() async => _offline();

  @override
  Future<CatalogSnapshot> snapshot() async => _offline();

  @override
  Future<CatalogDelta> delta(int fromRelease) async => _offline();
}
