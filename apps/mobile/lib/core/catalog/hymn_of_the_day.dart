import 'catalog_models.dart';

/// Cantique du jour (Q-10) : choix automatique et déterministe — la même date
/// donne le même cantique sur tous les appareils ayant la même release, sans
/// réseau. Le multiplicateur premier répartit les jours consécutifs dans tout
/// le recueil plutôt que de suivre l'ordre des numéros.
HymnSummary? hymnOfTheDay(List<HymnSummary> byNumber, DateTime date) {
  if (byNumber.isEmpty) return null;
  final day = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(2000)).inDays;
  return byNumber[(day * 7919) % byNumber.length];
}
