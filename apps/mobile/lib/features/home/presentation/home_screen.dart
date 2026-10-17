import 'package:flutter/material.dart';

import '../../../core/design_system/tokens.g.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Accueil provisoire (squelette Phase 1). L'accueil complet — recherche,
/// cantique du jour, raccourcis — est réalisé en Phase 5.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(LadSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.appTitle, style: text.displayLarge),
                const SizedBox(height: LadSpace.sm),
                Text(l10n.homeSubtitle, style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
