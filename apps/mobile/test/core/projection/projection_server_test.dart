import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/projection/projection_server.dart';

/// Serveur de projection avec de vraies connexions (boucle locale).
void main() {
  Future<List<int>?> assets(String path) async {
    final file = File(path);
    return file.existsSync() ? file.readAsBytes() : null;
  }

  late ProjectionServer server;
  late HttpClient http;

  setUp(() async {
    server = await ProjectionServer.start(
      assets: assets,
      address: InternetAddress.loopbackIPv4,
      preferredPort: 0,
    );
    http = HttpClient();
  });

  tearDown(() async {
    http.close(force: true);
    await server.stop();
  });

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<(int, String, HttpHeaders)> get(
    String path, {
    String method = 'GET',
  }) async {
    final request = await http.openUrl(method, url(path));
    request.followRedirects = false;
    final response = await request.close();
    final body = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    return (response.statusCode, body, response.headers);
  }

  Future<WebSocket> screen() =>
      WebSocket.connect('ws://127.0.0.1:${server.port}${server.screenPath}ws');

  test('code de session : 8 caractères sans ambiguïté, aléatoire', () {
    final a = ProjectionServer.newSessionToken();
    expect(a, matches(RegExp(r'^[a-hjkmnp-z2-9]{8}$')));
    final many = {
      for (var i = 0; i < 1000; i++) ProjectionServer.newSessionToken(),
    };
    expect(many.length, 1000);
    expect(ProjectionServer.newSessionToken(), isNot(a));
  });

  test('sert la page, ses styles, son script et ses polices avec le bon jeton', () async {
    final (status, body, headers) = await get(server.screenPath);
    expect(status, 200);
    expect(body, contains('<script src="screen.js">'));
    expect(
      headers.value('content-security-policy'),
      contains("default-src 'self'"),
    );
    expect(headers.value('cache-control'), 'no-store');
    expect(headers.value('referrer-policy'), 'no-referrer');
    for (final file in [
      'screen.js',
      'screen.css',
      'tokens.css',
      'fonts/cormorant.ttf',
    ]) {
      expect((await get('${server.screenPath}$file')).$1, 200, reason: file);
    }
    // Sans « / » final : redirection pour que les adresses relatives marchent.
    final (redirect, _, redirectHeaders) = await get('/s/${server.token}');
    expect(redirect, 301);
    expect(redirectHeaders.value('location'), server.screenPath);
  });

  test('mauvais jeton, autre chemin, autre méthode : même 404', () async {
    final wrong = ProjectionServer.newSessionToken();
    final responses = [
      await get('/s/$wrong/'),
      await get('/s/$wrong/screen.js'),
      await get('/'),
      await get('/s/${server.token}/../../etc/passwd'),
      await get('${server.screenPath}inconnu'),
      await get(server.screenPath, method: 'POST'),
    ];
    for (final (status, body, _) in responses) {
      expect(status, 404);
      expect(body, 'Introuvable');
    }
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:${server.port}/s/$wrong/ws'),
      throwsA(isA<WebSocketException>()),
    );
  });

  test('l’écran reçoit l’état courant à la connexion puis chaque changement (< 300 ms)', () async {
    server.publish({'type': 'state', 'index': 0});
    final socket = await screen();
    final messages = StreamIterator(socket);
    expect(await messages.moveNext(), isTrue);
    expect(jsonDecode(messages.current as String), {
      'type': 'state',
      'index': 0,
    });

    final latencies = <int>[];
    for (var i = 1; i <= 20; i++) {
      final watch = Stopwatch()..start();
      server.publish({'type': 'state', 'index': i});
      expect(await messages.moveNext(), isTrue);
      latencies.add(watch.elapsedMicroseconds);
      expect((jsonDecode(messages.current as String) as Map)['index'], i);
    }
    latencies.sort();
    final median = latencies[latencies.length ~/ 2];
    // ignore: avoid_print
    print(
      'Latence locale : médiane ${median / 1000} ms, max ${latencies.last / 1000} ms',
    );
    expect(latencies.last, lessThan(300000));
    await socket.close();
  });

  test('reconnexion : l’écran retrouve la diapositive courante', () async {
    final first = await screen();
    server.publish({'type': 'state', 'index': 4});
    await first.close();
    server.publish({'type': 'state', 'index': 5});
    final again = await screen();
    final message = await again.first;
    expect((jsonDecode(message as String) as Map)['index'], 5);
  });

  test('l’écran est en lecture seule ; plusieurs écrans comptés', () async {
    final counts = <int>[];
    final sub = server.screenCountChanges.listen(counts.add);
    final a = await screen();
    final b = await screen();
    a.add('{"type":"state","index":99}');
    a.add('pas du JSON');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.screens, 2);
    server.publish({'type': 'state', 'index': 1});
    expect((jsonDecode(await b.first as String) as Map)['index'], 1);
    await a.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.screens, 1);
    expect(counts, [1, 2, 1]);
    await sub.cancel();
  });

  test(
    'fin de session : les écrans sont prévenus et le port est libéré',
    () async {
      final socket = await screen();
      final received = socket.toList();
      final port = server.port;
      await server.stop();
      expect((await received).map((m) => jsonDecode(m as String)), [
        {'type': 'end'},
      ]);
      final reuse = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      await reuse.close();
    },
  );

  test('port préféré occupé : un autre port est choisi', () async {
    final busy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final other = await ProjectionServer.start(
      assets: assets,
      address: InternetAddress.loopbackIPv4,
      preferredPort: busy.port,
    );
    expect(other.port, isNot(busy.port));
    await other.stop();
    await busy.close();
  });
}
