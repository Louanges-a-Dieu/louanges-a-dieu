import 'published_hymn.dart';

/// Ordre chanté (ADR-009, note liminaire du recueil) : « le refrain, quand il
/// existe, est imprimé après le premier couplet ; il se chante après chaque
/// couplet suivant ».
///
/// Règle appliquée uniquement si le cantique a exactement UN refrain et que
/// toutes ses autres sections sont des couplets ; sinon l'ordre imprimé est
/// conservé tel quel (aucune supposition).
List<HymnSection> sungOrder(List<HymnSection> printed) {
  final refrains = printed.where((s) => s.type == SectionType.refrain).toList();
  final verses = printed.where((s) => s.type == SectionType.verse).toList();
  if (refrains.length != 1 ||
      verses.length + 1 != printed.length ||
      verses.length < 2) {
    return printed;
  }
  final refrain = refrains.single;
  final startsWithRefrain = printed.first.type == SectionType.refrain;
  return [
    if (startsWithRefrain) refrain,
    for (final verse in verses) ...[verse, refrain],
  ];
}
