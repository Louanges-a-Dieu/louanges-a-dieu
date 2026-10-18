import 'dart:async';
import 'dart:io';

import 'package:louanges_a_dieu/core/projection/projection_server.dart';
import 'package:louanges_a_dieu/core/sharing/share_links.dart';
import 'package:louanges_a_dieu/core/sync/user_sync.dart';
import 'package:louanges_a_dieu/core/user_data/user_data_models.dart';

/// Serveur de synchronisation qui accepte tout (ou simule une coupure).
class AcceptingUserRemote implements UserDataRemote {
  bool offline = false;
  final pushedServices = <WorshipServiceDto>[];

  void _check() {
    if (offline) throw const SocketException('Hors connexion');
  }

  @override
  Future<void> pushFavorites(List<FavoriteChange> changes) async => _check();

  @override
  Future<void> pushPlaylist(PlaylistDto playlist) async => _check();

  @override
  Future<void> pushWorshipService(WorshipServiceDto service) async {
    _check();
    pushedServices.add(service);
  }

  @override
  Future<UserChanges> pull(int since) async {
    _check();
    return const UserChanges(
      revision: 0,
      favorites: [],
      playlists: [],
      worshipServices: [],
    );
  }
}

/// Liens de partage simulés, fidèles aux RPC : même lien tant qu'il n'est pas
/// désactivé, nouveau lien après régénération.
class FakeShareLinks implements ShareLinks {
  final _active = <String, String>{};
  var _counter = 0;

  String _newToken() => 'jeton${(++_counter).toString().padLeft(27, '0')}';

  @override
  Future<String> ensure(String serviceId) async =>
      _active[serviceId] ??= _newToken();

  @override
  Future<String> regenerate(String serviceId) async =>
      _active[serviceId] = _newToken();

  @override
  Future<void> revoke(String serviceId) async => _active.remove(serviceId);
}

/// Hôte de projection simulé : enregistre ce qui serait envoyé aux écrans.
class FakeProjectionHost implements ProjectionHost {
  final messages = <Map<String, Object?>>[];
  final _counts = StreamController<int>.broadcast();
  bool? stoppedWithEndSession;
  var _screens = 0;

  Map<String, Object?> get last => messages.last;

  void connectScreens(int count) {
    _screens = count;
    _counts.add(count);
  }

  @override
  String get token => 'k7mx2qpa';

  @override
  int get port => 47100;

  @override
  int get screens => _screens;

  @override
  Stream<int> get screenCountChanges => _counts.stream;

  @override
  void publish(Map<String, Object?> message) => messages.add(message);

  @override
  Future<List<Uri>> screenUrls() async => [
    Uri.parse('http://192.168.43.1:47100/s/k7mx2qpa/'),
    Uri.parse('http://10.0.0.5:47100/s/k7mx2qpa/'),
  ];

  @override
  Future<void> stop({bool endSession = true}) async {
    stoppedWithEndSession = endSession;
  }
}
