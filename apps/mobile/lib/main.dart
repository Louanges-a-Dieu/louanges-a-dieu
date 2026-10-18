import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'app/licenses.dart';
import 'core/observability/crash_reporting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final env = Env.fromDefines();
  if (env.hasBackend) {
    // Seule la clé publishable est fournie à l'app (ADR-011).
    await Supabase.initialize(
      url: env.supabaseUrl,
      publishableKey: env.supabasePublishableKey,
    );
  }
  await runWithCrashReporting(
    dsn: env.sentryDsn,
    environment: env.environment.name,
    appRunner: () async => runApp(
      ProviderScope(
        overrides: [envProvider.overrideWithValue(env)],
        child: const LouangesApp(),
      ),
    ),
  );
}
