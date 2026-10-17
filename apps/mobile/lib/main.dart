import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Env.fromDefines();
  if (env.hasBackend) {
    // Seule la clé publishable est fournie à l'app (ADR-011).
    await Supabase.initialize(
      url: env.supabaseUrl,
      publishableKey: env.supabasePublishableKey,
    );
  }
  runApp(
    ProviderScope(
      overrides: [envProvider.overrideWithValue(env)],
      child: const LouangesApp(),
    ),
  );
}
