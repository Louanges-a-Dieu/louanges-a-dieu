import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_system/theme.dart';
import '../core/preferences/preferences.dart';
import '../features/startup/startup_gate.dart';
import '../l10n/generated/app_localizations.dart';
import 'router.dart';
import 'state.dart';

class LouangesApp extends ConsumerWidget {
  const LouangesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance =
        ref.watch(preferencesProvider).value?.appearance ??
        LadAppearance.system;
    return MaterialApp.router(
      builder: (context, child) =>
          _UsageFlush(child: StartupGate(child: child!)),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // Sépia : thème clair à part ; sinon clair, sombre ou celui de l'appareil.
      theme: appearance == LadAppearance.sepia
          ? LadTheme.sepia
          : LadTheme.light,
      darkTheme: LadTheme.dark,
      themeMode: switch (appearance) {
        LadAppearance.system => ThemeMode.system,
        LadAppearance.dark => ThemeMode.dark,
        LadAppearance.light || LadAppearance.sepia => ThemeMode.light,
      },
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Envoie les statistiques anonymes en attente quand l'app passe en
/// arrière-plan.
class _UsageFlush extends ConsumerStatefulWidget {
  const _UsageFlush({required this.child});

  final Widget child;

  @override
  ConsumerState<_UsageFlush> createState() => _UsageFlushState();
}

class _UsageFlushState extends ConsumerState<_UsageFlush> {
  late final AppLifecycleListener _listener = AppLifecycleListener(
    onHide: () => ref.read(usageRecorderProvider).flush().ignore(),
  );

  @override
  void initState() {
    super.initState();
    _listener;
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
