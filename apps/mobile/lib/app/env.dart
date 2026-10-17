import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Environnement d'exécution, injecté au build par
/// `--dart-define-from-file=config/<env>.json`.
enum AppEnvironment { dev, staging, prod }

/// Configuration d'environnement. Ne contient que des valeurs publiques :
/// aucune clé serveur privilégiée n'est jamais injectée dans l'app (ADR-011).
final class Env {
  const Env({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  /// Lit les valeurs fournies au build.
  factory Env.fromDefines() => Env.parse(const {
    'APP_ENV': String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
  });

  /// Valide une configuration brute. Lève [FormatException] si elle est
  /// incohérente.
  factory Env.parse(Map<String, String> values) {
    final name = values['APP_ENV'] ?? 'dev';
    final environment = AppEnvironment.values.asNameMap()[name];
    if (environment == null) {
      throw FormatException('APP_ENV inconnu : $name');
    }
    final url = values['SUPABASE_URL'] ?? '';
    final key = values['SUPABASE_PUBLISHABLE_KEY'] ?? '';
    if (environment != AppEnvironment.dev) {
      if (!url.startsWith('https://')) {
        throw FormatException('SUPABASE_URL doit être en HTTPS en $name');
      }
      if (key.isEmpty) {
        throw FormatException('SUPABASE_PUBLISHABLE_KEY manquant en $name');
      }
    }
    return Env(
      environment: environment,
      supabaseUrl: url,
      supabasePublishableKey: key,
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Vrai si un backend est configuré. Sans backend, l'app reste pleinement
  /// utilisable hors connexion (lecture et recherche).
  bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}

/// Fourni par `main()` via un override.
final envProvider = Provider<Env>(
  (ref) => throw UnimplementedError('envProvider doit être surchargé'),
);
