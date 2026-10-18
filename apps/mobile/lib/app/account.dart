import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_service.dart';
import '../core/sync/user_sync.dart';
import '../core/user_data/user_data_repository.dart';
import 'providers.dart';

/// Utilisateur connecté (null pour un visiteur).
final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final auth = ref.watch(authServiceProvider);
  yield auth.currentUser;
  yield* auth.watchUser();
});

@immutable
final class SyncStatus {
  const SyncStatus({
    this.syncing = false,
    this.pending = 0,
    this.lastSync,
    this.lastFailed = false,
  });

  final bool syncing;

  /// Modifications locales en attente d'envoi.
  final int pending;
  final DateTime? lastSync;
  final bool lastFailed;

  SyncStatus copyWith({
    bool? syncing,
    int? pending,
    DateTime? lastSync,
    bool? lastFailed,
  }) => SyncStatus(
    syncing: syncing ?? this.syncing,
    pending: pending ?? this.pending,
    lastSync: lastSync ?? this.lastSync,
    lastFailed: lastFailed ?? this.lastFailed,
  );
}

/// Pilote la synchronisation des données utilisateur : à la connexion, après
/// chaque modification (différée de quelques secondes) et à la demande.
class SyncRunner extends Notifier<SyncStatus> {
  Timer? _debounce;

  /// Délai entre une modification et l'envoi (regroupe les modifications rapprochées).
  static const delay = Duration(seconds: 3);

  @override
  SyncStatus build() {
    ref.onDispose(() => _debounce?.cancel());
    ref.listen(currentUserProvider, (previous, next) {
      final was = previous?.value;
      final now = next.value;
      if (now != null && was?.id != now.id) unawaited(syncNow());
    });
    return const SyncStatus();
  }

  /// Programme une synchronisation après une modification locale.
  void requestSync() {
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(syncNow()));
    unawaited(_refreshPending());
  }

  Future<UserSyncOutcome?> syncNow() async {
    final sync = ref.read(userSyncProvider);
    if (sync == null || state.syncing) return null;
    state = state.copyWith(syncing: true);
    final outcome = await sync.sync();
    state = state.copyWith(
      syncing: false,
      lastSync: outcome is UserSyncDone ? DateTime.now() : null,
      lastFailed: outcome is UserSyncPending,
    );
    await _refreshPending();
    return outcome;
  }

  Future<void> _refreshPending() async {
    final pending = await UserDataRepository(ref.read(appDatabaseProvider))
        .pendingCount();
    state = state.copyWith(pending: pending);
  }
}

final syncRunnerProvider = NotifierProvider<SyncRunner, SyncStatus>(
  SyncRunner.new,
);

/// Actions de compte qui touchent à la fois le serveur et l'appareil.
class AccountActions {
  AccountActions(this._ref);

  final Ref _ref;

  UserDataRepository get _local =>
      UserDataRepository(_ref.read(appDatabaseProvider));

  /// Modifications de listes/programmes qui seraient perdues à la déconnexion
  /// (après une dernière tentative d'envoi).
  Future<int> unsyncedBeforeSignOut() async {
    await _ref.read(syncRunnerProvider.notifier).syncNow();
    return _local.pendingAccountChanges();
  }

  Future<void> signOut({required bool keepFavorites}) async {
    await _ref.read(authServiceProvider).signOut();
    await _local.clearAccountData(keepFavorites: keepFavorites);
  }

  Future<void> deleteAccount() async {
    await _ref.read(authServiceProvider).deleteAccount();
    await _local.clearAccountData(keepFavorites: false);
  }
}

final accountActionsProvider = Provider<AccountActions>(AccountActions.new);
