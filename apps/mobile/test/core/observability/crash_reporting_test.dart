import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/observability/crash_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('sans DSN : l’app démarre, aucun suivi', () async {
    var started = false;
    await runWithCrashReporting(
      dsn: '',
      environment: 'test',
      appRunner: () async => started = true,
    );
    expect(started, isTrue);
    expect(Sentry.isEnabled, isFalse);
  });

  test(
    'options : aucune donnée personnelle, ni capture d’écran, ni session',
    () {
      final options = SentryFlutterOptions();
      configureSentry(
        options,
        dsn: 'https://cle@exemple.invalid/1',
        environment: 'prod',
      );
      expect(options.sendDefaultPii, isFalse);
      expect(options.attachScreenshot, isFalse);
      expect(options.enableAutoSessionTracking, isFalse);
      expect(options.tracesSampleRate, isNull);
      expect(options.environment, 'prod');
    },
  );

  test('événement filtré : utilisateur, requête, adresses, jetons, données de fil d’Ariane', () {
    final event = SentryEvent(
      user: SentryUser(email: 'marie@exemple.org', id: 'abc'),
      request: SentryRequest(
        url: 'https://x/programme/AbCdEfGhIjKlMnOpQrStUvWxYz012345',
      ),
      serverName: 'appareil',
      message: SentryMessage('Échec pour marie@exemple.org'),
      exceptions: [
        SentryException(
          type: 'StateError',
          value: 'Lien /programme/AbCdEfGhIjKlMnOpQrStUvWxYz012345 refusé',
        ),
      ],
      breadcrumbs: [
        Breadcrumb(
          message: 'GET https://exemple.supabase.co',
          data: {'url': 'x', 'status': 200},
        ),
      ],
    );
    final scrubbed = scrubEvent(event, Hint())!;
    expect(scrubbed.user, isNull);
    expect(scrubbed.request, isNull);
    expect(scrubbed.serverName, isNull);
    expect(scrubbed.message!.formatted, 'Échec pour [adresse]');
    expect(scrubbed.exceptions!.single.value, 'Lien /programme/[jeton] refusé');
    expect(scrubbed.breadcrumbs!.single.data, isNull);
  });

  test('normalisation du texte', () {
    expect(scrubText('a@b.fr'), '[adresse]');
    expect(scrubText('code k7mx2qpa'), 'code k7mx2qpa');
  });
}
