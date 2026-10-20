import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/state.dart';
import '../../core/design_system/components.dart';
import '../../core/design_system/tokens.g.dart';
import '../../l10n/generated/app_localizations.dart';

/// Cœur « favori » d'un cantique : sans compte, hors connexion, mis à jour
/// immédiatement (F-FAV-001).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.hymnId, this.color});

  final String hymnId;

  /// Couleur de l'icône (par défaut : or du thème).
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isFavorite =
        ref.watch(favoriteIdsProvider).value?.contains(hymnId) ?? false;
    return IconButton(
      tooltip: isFavorite ? l10n.removeFavorite : l10n.addFavorite,
      isSelected: isFavorite,
      color: color ?? context.lad.gold,
      icon: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : LadDurations.fast,
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(isFavorite),
        ),
      ),
      onPressed: () => ref
          .read(userDataRepositoryProvider)
          .setFavorite(hymnId, isFavorite: !isFavorite),
    );
  }
}
