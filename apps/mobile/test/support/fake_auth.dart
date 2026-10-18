import 'dart:async';

import 'package:louanges_a_dieu/core/auth/auth_service.dart';

/// Service de connexion simulé : le code « 12345678 » est accepté.
class FakeAuthService implements AuthService {
  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();
  final sentTo = <String>[];
  bool deleted = false;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchUser() => _changes.stream;

  void _set(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Future<void> sendSignInEmail(String email) async {
    if (!isValidEmail(email)) {
      throw const AuthFailure(AuthFailureKind.invalidEmail);
    }
    sentTo.add(email.trim());
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code.trim() != '12345678') {
      throw const AuthFailure(AuthFailureKind.invalidCode);
    }
    _set(AppUser(id: '00000000-0000-4000-8000-0000000a11ce', email: email));
  }

  @override
  Future<void> signOut() async => _set(null);

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    _set(null);
  }
}
