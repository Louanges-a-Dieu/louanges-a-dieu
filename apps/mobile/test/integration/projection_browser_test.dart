@Tags(['browser'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';
import 'package:louanges_a_dieu/core/projection/projection_server.dart';
import 'package:louanges_a_dieu/core/projection/projection_state.dart';
import 'package:louanges_a_dieu/core/projection/slides.dart';

/// Écran projeté dans un VRAI navigateur (Chrome sans interface), servi par le
/// serveur local de l'app (8.0 sur ordinateur, T-008, coupure puis reprise,
/// aucun accès Internet). Ignoré si Chrome est absent.
final chromePath = [
  Platform.environment['CHROME_PATH'],
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
].whereType<String>().where((p) => File(p).existsSync()).firstOrNull;

/// Client minimal du protocole DevTools.
class Cdp {
  Cdp._(this._socket) {
    _socket.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, Object?>;
      final id = msg['id'];
      if (id is int) {
        _pending.remove(id)?.complete(msg);
      } else {
        events.add(msg);
      }
    });
  }

  static Future<Cdp> connect(int port) async {
    for (var i = 0; i < 100; i++) {
      try {
        final client = HttpClient();
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/json'),
        );
        final body = await (await req.close()).transform(utf8.decoder).join();
        client.close();
        final page = (jsonDecode(body) as List)
            .cast<Map<String, Object?>>()
            .firstWhere((t) => t['type'] == 'page');
        return Cdp._(
          await WebSocket.connect(page['webSocketDebuggerUrl']! as String),
        );
      } on Object {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw StateError('Chrome ne répond pas');
  }

  final WebSocket _socket;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  final events = <Map<String, Object?>>[];
  var _id = 0;

  Future<Map<String, Object?>> send(
    String method, [
    Map<String, Object?>? params,
  ]) {
    final id = ++_id;
    final c = _pending[id] = Completer();
    _socket.add(
      jsonEncode({'id': id, 'method': method, 'params': params ?? {}}),
    );
    return c.future;
  }

  Future<Object?> eval(String expression) async {
    final r = await send('Runtime.evaluate', {
      'expression': expression,
      'returnByValue': true,
    });
    return ((r['result']! as Map)['result']! as Map)['value'];
  }

  /// Attend que [expression] soit vraie ; renvoie le temps écoulé.
  Future<Duration> waitFor(
    String expression, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed < timeout) {
      if (await eval(expression) == true) return watch.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw TimeoutException('Condition jamais vraie : $expression');
  }

  Future<void> close() => _socket.close();
}

void main() {
  test(
    'écran projeté dans Chrome : affichage, changement sans rechargement, écran noir, coupure et reprise, sans Internet',
    () async {
      Future<List<int>?> assets(String path) async {
        final f = File(path);
        return f.existsSync() ? f.readAsBytes() : null;
      }

      var server = await ProjectionServer.start(
        assets: assets,
        address: InternetAddress.loopbackIPv4,
        preferredPort: 0,
      );
      final token = server.token;
      final port = server.port;

      final fixture = jsonDecode(
        File(
          '../../packages/shared_contracts/fixtures/projection/refrain-repete.json',
        ).readAsStringSync(),
      ) as Map<String, Object?>;
      final hymn = PublishedHymn.fromJson(
        fixture['hymn']! as Map<String, Object?>,
      );
      var state = ProjectionState(slides: hymnSlides(hymn));
      server.publish(state.toMessage());

      final profile = await Directory.systemTemp.createTemp('lad-chrome');
      final debugPort = await (() async {
        final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final p = s.port;
        await s.close();
        return p;
      })();
      final chrome = await Process.start(chromePath!, [
        '--headless=new',
        '--disable-gpu',
        '--no-first-run',
        '--remote-debugging-port=$debugPort',
        '--user-data-dir=${profile.path}',
        'about:blank',
      ]);
      final cdp = await Cdp.connect(debugPort);
      try {
        await cdp.send('Network.enable');
        await cdp.send('Runtime.enable');
        await cdp.send('Emulation.setDeviceMetricsOverride', {
          'width': 1280,
          'height': 720,
          'deviceScaleFactor': 1,
          'mobile': false,
        });
        await cdp.send('Page.navigate', {
          'url': 'http://127.0.0.1:$port/s/$token/',
        });

        // Diapositive de titre reçue à la connexion.
        await cdp.waitFor("document.body.innerText.includes('Cantique A')");
        await cdp.eval('window.__chargement = 42');

        // T-008 : changement de diapositive sans rechargement de la page.
        state = state.forward();
        server.publish(state.toMessage());
        final latency = await cdp.waitFor(
          "document.body.innerText.includes('Couplet 1, vers 4')",
        );
        expect(
          await cdp.eval('window.__chargement'),
          42,
          reason: 'aucun rechargement',
        );
        // Latence : médiane de plusieurs changements (une mesure isolée est
        // trop sensible à la charge de la machine de test).
        final samples = <Duration>[latency];
        for (var i = 0; i < 6; i++) {
          final back = i.isEven;
          state = back ? state.back() : state.forward();
          server.publish(state.toMessage());
          samples.add(
            await cdp.waitFor(
              back
                  ? "document.body.innerText.includes('Cantique A') && !document.body.innerText.includes('Couplet 1, vers 4')"
                  : "document.body.innerText.includes('Couplet 1, vers 4')",
            ),
          );
        }
        samples.sort();
        final median = samples[samples.length ~/ 2];
        // ignore: avoid_print
        print(
          'Latence téléphone → navigateur (boucle locale) : médiane ${median.inMilliseconds} ms, '
          'max ${samples.last.inMilliseconds} ms',
        );
        expect(median, lessThan(const Duration(milliseconds: 300)));
        expect(
          await cdp.eval("document.body.innerText.includes('12 · COUPLET 1')"),
          isTrue,
        );

        // Le texte occupe l'écran (ajustement automatique) sans déborder.
        final fontSize = await cdp.eval(
          "parseFloat(getComputedStyle(document.querySelector('.content')).fontSize)",
        );
        expect(fontSize as num, greaterThan(40));
        expect(
          await cdp.eval(
            "(() => { const c = document.querySelector('.content'); "
            "const s = document.getElementById('stage'); "
            'return c.scrollHeight <= s.clientHeight && c.scrollWidth <= s.clientWidth; })()',
          ),
          isTrue,
        );

        // Écran noir, puis retour.
        state = state.toggleBlank();
        server.publish(state.toMessage());
        await cdp.waitFor("document.body.classList.contains('blank')");
        state = state.toggleBlank().forward();
        server.publish(state.toMessage());
        await cdp.waitFor(
          "!document.body.classList.contains('blank') && document.body.innerText.includes('Refrain, vers 1')",
        );

        // Planche 5 : écran masqué (logo seul), fond clair, photo voilée,
        // numéro masqué, transition et message de fin.
        state = state.toggleMask();
        server.publish(state.toMessage());
        await cdp.waitFor(
          "document.querySelector('.content.masked') !== null && !document.body.innerText.includes('Refrain, vers 1')",
        );
        state = state.toggleMask().withDisplay(
          const ProjectionDisplay(background: 'light', showNumber: false),
        );
        server.publish(state.toMessage());
        await cdp.waitFor(
          "document.documentElement.dataset.theme === 'light' && document.body.innerText.includes('Refrain, vers 1')",
        );
        expect(
          await cdp.eval("document.body.innerText.includes('12 · ')"),
          isFalse,
          reason: 'numéro masqué',
        );
        state = state.withDisplay(
          const ProjectionDisplay(background: 'image:hero_wheat_sunset'),
        );
        server.publish(state.toMessage());
        await cdp.waitFor(
          "document.body.classList.contains('photo') && document.documentElement.dataset.theme === 'projection'",
        );
        await cdp.waitFor(
          "getComputedStyle(document.body).backgroundImage.includes('images/hero_wheat_sunset.jpg')",
        );
        final extras = ProjectionState(
          slides: withProgramExtras(
            [...hymnSlides(hymn), ...hymnSlides(hymn)],
            transitions: true,
            endMessage: 'Merci pour ce temps de louange !',
          ),
        );
        final transition = extras.slides.indexWhere(
          (s) => s is TransitionSlide,
        );
        server.publish(extras.goTo(transition).toMessage());
        await cdp.waitFor(
          "document.querySelector('.content.transition') !== null",
        );
        server.publish(extras.goTo(extras.slides.length - 1).toMessage());
        await cdp.waitFor(
          "document.body.innerText.includes('Merci pour ce temps de louange !')",
        );
        state = state.withDisplay(const ProjectionDisplay());
        server.publish(state.toMessage());
        await cdp.waitFor(
          "!document.body.classList.contains('photo') && document.body.innerText.includes('Refrain, vers 1')",
        );

        // Karaoké en famille : l'écran fait avancer l'horloge lui-même ; le
        // vers chanté se remplit sans nouveau message.
        server.publish({
          'type': 'karaoke',
          'v': 1,
          'numberLabel': '12',
          'title': 'Cantique A',
          'position': 1000,
          'playing': true,
          'lines': [
            for (final (i, text) in [
              'Premier vers',
              'Deuxième vers',
              'Troisième vers',
            ].indexed)
              {
                'text': text,
                'start': i * 4000,
                'end': i * 4000 + 4000,
                'section': 's1',
                'sectionName': 'Couplet 1',
              },
          ],
        });
        await cdp.waitFor(
          "document.querySelector('.k-sung')?.innerText === 'Premier vers'",
        );
        final fill = await cdp.eval(
          "parseFloat(document.querySelector('.k-fill').style.getPropertyValue('--fill'))",
        ) as num;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final later = await cdp.eval(
          "parseFloat(document.querySelector('.k-fill').style.getPropertyValue('--fill'))",
        ) as num;
        expect(later, greaterThan(fill), reason: 'remplissage continu');
        if (Platform.environment['KARAOKE_SHOT'] case final out?) {
          final shot = await cdp.send('Page.captureScreenshot', {
            'format': 'png',
          });
          File(out).writeAsBytesSync(
            base64Decode((shot['result']! as Map)['data']! as String),
          );
        }
        expect(
          await cdp.eval("document.body.innerText.includes('Deuxième vers')"),
          isTrue,
          reason: 'vers suivants visibles',
        );
        // Pause : l'horloge s'arrête.
        server.publish({
          'type': 'karaoke',
          'v': 1,
          'numberLabel': '12',
          'title': 'Cantique A',
          'position': 4500,
          'playing': false,
          'lines': [
            {
              'text': 'Premier vers',
              'start': 0,
              'end': 4000,
              'section': 's1',
              'sectionName': 'Couplet 1',
            },
            {
              'text': 'Deuxième vers',
              'start': 4000,
              'end': 8000,
              'section': 's1',
              'sectionName': 'Couplet 1',
            },
          ],
        });
        await cdp.waitFor(
          "document.querySelector('.k-sung')?.innerText === 'Deuxième vers'",
        );
        // Retour à la projection classique.
        server.publish(state.toMessage());
        await cdp.waitFor(
          "document.querySelector('.karaoke') === null && document.body.innerText.includes('Refrain, vers 1')",
        );

        // Coupure : la dernière diapositive reste affichée, « Reconnexion… ».
        await server.stop(endSession: false);
        await cdp.waitFor("!document.getElementById('status').hidden");
        expect(
          await cdp.eval("document.body.innerText.includes('Refrain, vers 1')"),
          isTrue,
        );

        // Reprise (même port, même jeton) : reconnexion automatique.
        server = await ProjectionServer.start(
          assets: assets,
          address: InternetAddress.loopbackIPv4,
          preferredPort: port,
          token: token,
        );
        expect(server.port, port);
        state = state.forward();
        server.publish(state.toMessage());
        await cdp.waitFor(
          "document.getElementById('status').hidden && document.body.innerText.includes('Couplet 2, vers 1')",
          timeout: const Duration(seconds: 15),
        );
        expect(
          await cdp.eval('window.__chargement'),
          42,
          reason: 'reprise sans rechargement',
        );

        // Polices servies localement et chargées.
        expect(await cdp.eval("document.fonts.check('16px Literata')"), isTrue);

        if (Platform.environment['PROJECTION_SHOT'] case final out?) {
          final shot = await cdp.send('Page.captureScreenshot', {
            'format': 'png',
          });
          File(out).writeAsBytesSync(
            base64Decode((shot['result']! as Map)['data']! as String),
          );
        }

        // Aucune requête hors du serveur local, aucune erreur de script.
        final urls = [
          for (final e in cdp.events)
            if (e['method'] == 'Network.requestWillBeSent')
              ((e['params']! as Map)['request']! as Map)['url']! as String
            else if (e['method'] == 'Network.webSocketCreated')
              (e['params']! as Map)['url']! as String,
        ];
        expect(urls, isNotEmpty);
        expect(
          urls.where(
            (u) =>
                !u.startsWith('http://127.0.0.1:$port/') &&
                !u.startsWith('ws://127.0.0.1:$port/'),
          ),
          isEmpty,
        );
        expect(
          cdp.events.where((e) => e['method'] == 'Runtime.exceptionThrown'),
          isEmpty,
        );

        // Fin de session.
        await server.stop();
        await cdp.waitFor(
          "document.body.textContent.includes('Louanges à Dieu') && !document.body.textContent.includes('Couplet 2')",
        );
      } finally {
        await cdp.close();
        chrome.kill();
        await chrome.exitCode;
        await server.stop();
        await profile.delete(recursive: true);
      }
    },
    skip: chromePath == null ? 'Chrome introuvable' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
