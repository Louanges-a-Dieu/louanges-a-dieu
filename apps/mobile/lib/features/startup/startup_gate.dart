import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/theme.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Affiche l'app une fois le catalogue local prêt (instantané embarqué ou
/// premier téléchargement). Sans catalogue ni réseau : message et nouvel essai.
class StartupGate extends ConsumerWidget {
  const StartupGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ready = ref.watch(catalogBootstrapProvider);
    return ready.when(
      data: (available) => available
          ? child
          : _Frame(
              child: MessageState(
                title: l10n.startupNoCatalogTitle,
                message: l10n.startupNoCatalogMessage,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(catalogBootstrapProvider),
              ),
            ),
      loading: () => _Frame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WheatEar(size: 56),
            const SizedBox(height: LadSpace.xl),
            Text(
              l10n.appTitle,
              style: LadTheme.textStyle(LadTypeScale.display, context.lad.text),
            ),
            const SizedBox(height: LadSpace.sm),
            Text(
              l10n.startupLoading,
              style: LadTheme.textStyle(
                LadTypeScale.body,
                context.lad.textSecondary,
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => _Frame(
        child: MessageState(
          title: l10n.startupNoCatalogTitle,
          message: '$error',
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(catalogBootstrapProvider),
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: child)),
  );
}
