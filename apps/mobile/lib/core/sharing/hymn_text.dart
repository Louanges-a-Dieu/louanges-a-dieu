import '../catalog/published_hymn.dart';

/// Texte d'un cantique pour le partage : numéro, titre, paroles verbatim dans
/// l'ordre imprimé (chaque section précédée de son nom), puis la source.
String hymnShareText(PublishedHymn hymn) {
  final text = StringBuffer('${hymn.numberLabel} — ${hymn.title}\n');
  for (final section in hymn.sections) {
    text
      ..writeln()
      ..writeln(sectionName(section.type, section.number));
    for (final line in section.lines) {
      text.writeln(line.text);
    }
  }
  text
    ..writeln()
    ..write('Louanges à Dieu, n° ${hymn.numberLabel}');
  return text.toString();
}
