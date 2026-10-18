import 'package:supabase_flutter/supabase_flutter.dart';

/// Liens publics de programmes (ADR-012). Nécessite une connexion réseau et
/// que le programme ait été envoyé au serveur.
abstract interface class ShareLinks {
  /// Lien actif du programme, ou nouveau lien s'il n'en a pas (le même lien
  /// est renvoyé à chaque partage).
  Future<String> ensure(String serviceId);

  /// Nouveau lien : l'ancien cesse de fonctionner.
  Future<String> regenerate(String serviceId);

  /// Désactive immédiatement le lien.
  Future<void> revoke(String serviceId);
}

class SupabaseShareLinks implements ShareLinks {
  SupabaseShareLinks(this._client);

  final SupabaseClient _client;
  static const _timeout = Duration(seconds: 20);

  @override
  Future<String> ensure(String serviceId) async =>
      (await _client
              .rpc<Object?>(
                'ensure_share_link',
                params: {'p_service_id': serviceId},
              )
              .timeout(_timeout))!
          as String;

  @override
  Future<String> regenerate(String serviceId) async =>
      (await _client
              .rpc<Object?>(
                'create_share_link',
                params: {'p_service_id': serviceId},
              )
              .timeout(_timeout))!
          as String;

  @override
  Future<void> revoke(String serviceId) => _client
      .rpc<void>('revoke_share_link', params: {'p_service_id': serviceId})
      .timeout(_timeout);
}
