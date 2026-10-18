import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Lit une ressource de l'app (page de l'écran, polices) ; null si absente.
typedef AssetLoader = Future<List<int>?> Function(String assetPath);

/// Serveur local de projection (ADR-013) : sert la page de l'écran projeté et
/// lui envoie l'état courant par WebSocket, sans Internet.
///
/// Sécurité : actif seulement pendant une session ; toutes les adresses sont
/// sous `/s/<code>/` (code de session aléatoire) ; toute autre requête
/// reçoit un 404 identique ; l'écran est en lecture seule (messages entrants
/// ignorés) ; aucune donnée de compte n'est servie.
/// Ce dont le pilote a besoin (remplacé par un faux dans les tests d'écran).
abstract interface class ProjectionHost {
  String get token;
  int get port;
  int get screens;
  Stream<int> get screenCountChanges;
  void publish(Map<String, Object?> message);
  Future<List<Uri>> screenUrls();
  Future<void> stop({bool endSession = true});
}

class ProjectionServer implements ProjectionHost {
  ProjectionServer._(this._server, this.token, this._assets) {
    _server.listen(_handle, onError: (_) {});
  }

  /// Démarre sur [preferredPort] (adresse stable d'un culte à l'autre), ou
  /// sur un port libre s'il est occupé.
  static Future<ProjectionServer> start({
    required AssetLoader assets,
    int preferredPort = 47100,
    InternetAddress? address,
    String? token,
  }) async {
    final bindTo = address ?? InternetAddress.anyIPv4;
    HttpServer server;
    try {
      server = await HttpServer.bind(bindTo, preferredPort);
    } on SocketException {
      server = await HttpServer.bind(bindTo, 0);
    }
    return ProjectionServer._(server, token ?? newSessionToken(), assets);
  }

  /// Code de session court, facile à taper sur l'ordinateur du projecteur :
  /// 8 caractères sans ambiguïté (ni 0/o, ni 1/l/i), environ 40 bits. Suffisant
  /// ici (ADR-013) : écran en lecture seule, contenu public, serveur actif
  /// seulement pendant la projection, sur le réseau local.
  static String newSessionToken() {
    const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(
        8,
        (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ),
    );
  }

  final HttpServer _server;
  @override
  final String token;
  final AssetLoader _assets;
  final _screens = <WebSocket>{};
  final _screenCount = StreamController<int>.broadcast();
  String? _lastMessage;
  bool _stopped = false;

  @override
  int get port => _server.port;
  @override
  int get screens => _screens.length;

  /// Nombre d'écrans connectés, à chaque changement.
  @override
  Stream<int> get screenCountChanges => _screenCount.stream;

  /// Chemin de la page de l'écran projeté.
  String get screenPath => '/s/$token/';

  static const _files = {
    '': ('assets/projection/screen.html', 'text/html; charset=utf-8'),
    'screen.js': (
      'assets/projection/screen.js',
      'text/javascript; charset=utf-8',
    ),
    'screen.css': ('assets/projection/screen.css', 'text/css; charset=utf-8'),
    'tokens.css': ('assets/projection/tokens.css', 'text/css; charset=utf-8'),
    'fonts/cormorant.ttf': (
      'assets/fonts/CormorantGaramond/CormorantGaramond-VF.ttf',
      'font/ttf',
    ),
    'fonts/literata.ttf': ('assets/fonts/Literata/Literata-VF.ttf', 'font/ttf'),
    'fonts/literata-italic.ttf': (
      'assets/fonts/Literata/Literata-Italic-VF.ttf',
      'font/ttf',
    ),
  };

  /// Envoie l'état à tous les écrans et le garde pour ceux qui se connectent
  /// (ou se reconnectent) ensuite.
  @override
  void publish(Map<String, Object?> message) {
    final encoded = jsonEncode(message);
    _lastMessage = encoded;
    for (final socket in _screens) {
      socket.add(encoded);
    }
  }

  /// Adresses à ouvrir depuis l'ordinateur (une par interface réseau).
  @override
  Future<List<Uri>> screenUrls() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final addresses = [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal)
            (name: i.name, address: a.address),
    ];
    // Wi-Fi et point d'accès d'abord (wlan, en, ap, bridge…), réseau mobile ensuite.
    int rank(String name) =>
        RegExp(r'^(wlan|en|ap|swlan|bridge|eth)').hasMatch(name)
        ? 0
        : RegExp(r'^(rmnet|pdp|ccmni|v4-rmnet)').hasMatch(name)
        ? 2
        : 1;
    addresses.sort((a, b) => rank(a.name).compareTo(rank(b.name)));
    return [
      for (final a in addresses)
        Uri(scheme: 'http', host: a.address, port: port, path: screenPath),
    ];
  }

  /// Arrête le serveur. Avec [endSession] (par défaut), les écrans affichent
  /// la fin de la projection ; sans, ils gardent la dernière diapositive et se
  /// reconnectent dès qu'un serveur redémarre avec le même port et le même
  /// jeton (app passée en arrière-plan sur iOS).
  @override
  Future<void> stop({bool endSession = true}) async {
    if (_stopped) return;
    _stopped = true;
    final end = jsonEncode({'type': 'end'});
    for (final socket in [..._screens]) {
      if (endSession) socket.add(end);
      await socket.close(
        endSession ? WebSocketStatus.normalClosure : WebSocketStatus.goingAway,
      );
    }
    _screens.clear();
    await _server.close(force: true);
    await _screenCount.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer')
      ..set('X-Robots-Tag', 'noindex, nofollow');
    final segments = request.uri.pathSegments;
    final authorized =
        request.method == 'GET' &&
        segments.length >= 2 &&
        segments[0] == 's' &&
        _sameToken(segments[1], token);
    if (!authorized) return _notFound(response);

    // « /s/<jeton> » → « /s/<jeton>/ » pour que les adresses relatives marchent.
    if (segments.length == 2 && !request.uri.path.endsWith('/')) {
      response
        ..statusCode = HttpStatus.movedPermanently
        ..headers.set(HttpHeaders.locationHeader, screenPath);
      return response.close();
    }

    final rest = segments.skip(2).join('/');
    if (rest == 'ws') {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        return _notFound(response);
      }
      final socket = await WebSocketTransformer.upgrade(request);
      return _attach(socket);
    }

    final file = _files[rest];
    final bytes = file == null ? null : await _assets(file.$1);
    if (file == null || bytes == null) return _notFound(response);
    response.headers
      ..set(HttpHeaders.contentTypeHeader, file.$2)
      ..set(
        'Content-Security-Policy',
        "default-src 'self'; connect-src 'self' ws: wss:; img-src 'self' data:; "
            "frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
      );
    response.add(bytes);
    await response.close();
  }

  void _attach(WebSocket socket) {
    socket.pingInterval = const Duration(seconds: 5);
    _screens.add(socket);
    _screenCount.add(_screens.length);
    if (_lastMessage != null) socket.add(_lastMessage);
    // Lecture seule : tout message de l'écran est ignoré.
    socket.listen(
      (_) {},
      onDone: () => _detach(socket),
      onError: (_) => _detach(socket),
      cancelOnError: true,
    );
  }

  void _detach(WebSocket socket) {
    if (_screens.remove(socket) && !_stopped) _screenCount.add(_screens.length);
  }

  Future<void> _notFound(HttpResponse response) {
    response
      ..statusCode = HttpStatus.notFound
      ..headers.contentType = ContentType.text;
    response.write('Introuvable');
    return response.close();
  }

  /// Comparaison en temps constant (pas d'indice sur le jeton par la durée).
  static bool _sameToken(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
