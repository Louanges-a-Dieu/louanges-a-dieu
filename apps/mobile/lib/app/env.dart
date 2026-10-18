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
    this.publicWebUrl = '',
    this.sentryDsn = '',
  });

  /// Lit les valeurs fournies au build.
  factory Env.fromDefines() => Env.parse(const {
    'APP_ENV': String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    'PUBLIC_WEB_URL': String.fromEnvironment('PUBLIC_WEB_URL'),
    'SENTRY_DSN': String.fromEnvironment('SENTRY_DSN'),
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
    final web = (values['PUBLIC_WEB_URL'] ?? '').replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    if (environment != AppEnvironment.dev) {
      if (!url.startsWith('https://')) {
        throw FormatException('SUPABASE_URL doit être en HTTPS en $name');
      }
      if (key.isEmpty) {
        throw FormatException('SUPABASE_PUBLISHABLE_KEY manquant en $name');
      }
      if (!web.startsWith('https://')) {
        throw FormatException('PUBLIC_WEB_URL doit être en HTTPS en $name');
      }
    }
    return Env(
      environment: environment,
      supabaseUrl: url,
      supabasePublishableKey: key,
      publicWebUrl: web,
      sentryDsn: values['SENTRY_DSN'] ?? '',
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Site public (pages des programmes partagés), sans « / » final.
  final String publicWebUrl;

  /// Suivi des plantages (Sentry) ; vide = désactivé.
  final String sentryDsn;

  /// Vrai si un backend est configuré. Sans backend, l'app reste pleinement
  /// utilisable hors connexion (lecture et recherche).
  bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Adresse publique d'un programme partagé.
  String sharedProgramUrl(String token) => '$publicWebUrl/programme/$token';
}

/// Fourni par `main()` via un override.
final envProvider = Provider<Env>(
  (ref) => throw UnimplementedError('envProvider doit être surchargé'),
);
