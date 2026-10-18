import 'package:sentry_flutter/sentry_flutter.dart';

/// Suivi des plantages (10.5, Q-16 : Sentry). Activé seulement si un DSN est
/// fourni au build (`SENTRY_DSN`) ; sinon l'app démarre sans aucun envoi.
///
/// Aucune donnée personnelle : ni utilisateur, ni requête, ni capture d'écran,
/// ni arborescence d’écran (désactivée par défaut), ni session ; adresses e-mail et jetons retirés des
/// messages ; données des fils d'Ariane (adresses appelées…) supprimées.
Future<void> runWithCrashReporting({
  required String dsn,
  required String environment,
  required Future<void> Function() appRunner,
}) async {
  if (dsn.isEmpty) {
    await appRunner();
    return;
  }
  await SentryFlutter.init(
    (options) => configureSentry(options, dsn: dsn, environment: environment),
    appRunner: appRunner,
  );
}

void configureSentry(
  SentryFlutterOptions options, {
  required String dsn,
  required String environment,
}) {
  options
    ..dsn = dsn
    ..environment = environment
    ..sendDefaultPii = false
    ..attachScreenshot = false
    ..enableAutoSessionTracking = false
    ..tracesSampleRate = null
    ..beforeSend = scrubEvent
    ..beforeBreadcrumb = scrubBreadcrumb;
}

final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
final _programme = RegExp(r'''/programme/[^\s/?#'"]+''');
final _token = RegExp(r'\b[A-Za-z0-9_-]{32,}\b');

/// Adresses e-mail, liens de programme et jetons longs retirés d'un texte.
String scrubText(String text) => text
    .replaceAll(_email, '[adresse]')
    .replaceAll(_programme, '/programme/[jeton]')
    .replaceAll(_token, '[jeton]');

SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
  event
    ..user = null
    ..request = null
    ..serverName = null;
  final message = event.message;
  if (message != null) {
    event.message = SentryMessage(scrubText(message.formatted));
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    final value = exception.value;
    if (value != null) exception.value = scrubText(value);
  }
  for (final crumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
    scrubBreadcrumb(crumb, hint);
  }
  return event;
}

Breadcrumb? scrubBreadcrumb(Breadcrumb? crumb, Hint hint) {
  if (crumb == null) return null;
  crumb.data = null;
  final message = crumb.message;
  if (message != null) crumb.message = scrubText(message);
  return crumb;
}
