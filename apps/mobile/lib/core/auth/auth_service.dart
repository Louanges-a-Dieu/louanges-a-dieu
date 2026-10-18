import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Utilisateur connecté (seules les informations nécessaires à l'app).
@immutable
final class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String? email;
}

/// Erreur d'authentification présentable à l'utilisateur.
final class AuthFailure implements Exception {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;

  @override
  String toString() => 'AuthFailure($kind)';
}

enum AuthFailureKind {
  invalidEmail,
  rateLimited,
  invalidCode,
  network,
  unavailable,
  unknown,
}

/// Connexion par e-mail, sans mot de passe (Q-13) : l'e-mail contient un lien
/// qui rouvre l'application et, si le modèle d'e-mail le permet, un code.
abstract interface class AuthService {
  AppUser? get currentUser;
  Stream<AppUser?> watchUser();
  Future<void> sendSignInEmail(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();

  /// Supprime définitivement le compte et toutes ses données serveur.
  Future<void> deleteAccount();
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool isValidEmail(String value) => _email.hasMatch(value.trim());

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client, {required this.redirectTo});

  final SupabaseClient _client;

  /// Adresse vers laquelle le lien de l'e-mail renvoie (schéma de l'app,
  /// ou origine de l'aperçu web). Doit figurer dans la liste autorisée de Supabase.
  final String redirectTo;

  static AppUser? _map(User? u) =>
      u == null ? null : AppUser(id: u.id, email: u.email);

  @override
  AppUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<AppUser?> watchUser() =>
      _client.auth.onAuthStateChange.map((s) => _map(s.session?.user));

  @override
  Future<void> sendSignInEmail(String email) => _guard(() {
    if (!isValidEmail(email)) {
      throw const AuthFailure(AuthFailureKind.invalidEmail);
    }
    return _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: redirectTo,
    );
  });

  @override
  Future<void> verifyCode(String email, String code) => _guard(
    () => _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.email,
    ),
  );

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);

  @override
  Future<void> deleteAccount() => _guard(() async {
    await _client.rpc<void>('delete_my_account');
    await _client.auth.signOut(scope: SignOutScope.local);
  });

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      final code = '${e.code ?? ''} ${e.statusCode ?? ''} ${e.message}'
          .toLowerCase();
      if (code.contains('rate') || code.contains('429')) {
        throw const AuthFailure(AuthFailureKind.rateLimited);
      }
      if (code.contains('otp') ||
          code.contains('token') ||
          code.contains('expired')) {
        throw const AuthFailure(AuthFailureKind.invalidCode);
      }
      throw const AuthFailure(AuthFailureKind.unknown);
    } on Exception catch (e) {
      final text = '$e'.toLowerCase();
      if (text.contains('socket') ||
          text.contains('network') ||
          text.contains('timeout')) {
        throw const AuthFailure(AuthFailureKind.network);
      }
      throw const AuthFailure(AuthFailureKind.unknown);
    }
  }
}

/// Sans backend configuré : la connexion est indisponible, l'app reste
/// pleinement utilisable hors compte.
class NoBackendAuthService implements AuthService {
  const NoBackendAuthService();

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> watchUser() => const Stream.empty();

  static Never _unavailable() =>
      throw const AuthFailure(AuthFailureKind.unavailable);

  @override
  Future<void> sendSignInEmail(String email) async => _unavailable();

  @override
  Future<void> verifyCode(String email, String code) async => _unavailable();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async => _unavailable();
}
