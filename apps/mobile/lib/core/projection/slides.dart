import 'package:flutter/foundation.dart';

import '../catalog/published_hymn.dart';
import '../catalog/sung_order.dart';

/// Contrat de projection (Phase 8) : découpe d'un cantique ou d'un programme en
/// diapositives. Implémenté à l'identique en TypeScript
/// (packages/shared_contracts/src/projection.ts) et vérifié par les mêmes
/// fixtures (packages/shared_contracts/fixtures/projection).
///
/// Diapositive de titre, puis une par section dans l'ordre chanté (Q-07,
/// désactivable) ; section trop longue découpée en parties équilibrées ;
/// sections « note » non projetées ; texte tel qu'imprimé (ADR-008).
@immutable
sealed class Slide {
  const Slide();

  Map<String, Object?> toJson();
}

final class TitleSlide extends Slide {
  const TitleSlide({required this.numberLabel, required this.title});

  final String numberLabel;
  final String title;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'title',
    'numberLabel': numberLabel,
    'title': title,
  };
}

final class LyricsSlide extends Slide {
  const LyricsSlide({
    required this.numberLabel,
    required this.sectionType,
    required this.sectionNumber,
    required this.part,
    required this.parts,
    required this.lines,
  });

  final String numberLabel;
  final SectionType sectionType;
  final int? sectionNumber;
  final int part;
  final int parts;
  final List<String> lines;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'lyrics',
    'numberLabel': numberLabel,
    'sectionType': sectionType.name,
    'sectionNumber': sectionNumber,
    'part': part,
    'parts': parts,
    'lines': lines,
  };
}

/// Moment libre d'un programme (accueil, prière…).
final class SectionSlide extends Slide {
  const SectionSlide(this.label);

  final String label;

  @override
  Map<String, Object?> toJson() => {'kind': 'section', 'label': label};
}

@immutable
final class ProjectionOptions {
  const ProjectionOptions({this.repeatRefrain = true, this.maxLines = 6})
    : assert(maxLines >= 1);

  /// Refrain répété après chaque couplet (Q-07).
  final bool repeatRefrain;

  /// Nombre maximal de vers par diapositive.
  final int maxLines;
}

/// Découpe équilibrée : les premières parties reçoivent le vers en trop.
List<List<String>> splitLines(List<String> lines, int maxLines) {
  final parts = lines.isEmpty ? 1 : (lines.length / maxLines).ceil();
  final base = lines.length ~/ parts;
  final extra = lines.length % parts;
  var start = 0;
  return [
    for (var i = 0; i < parts; i++)
      lines.sublist(start, start += base + (i < extra ? 1 : 0)),
  ];
}

List<Slide> hymnSlides(
  PublishedHymn hymn, [
  ProjectionOptions options = const ProjectionOptions(),
]) {
  final printed = [...hymn.sections]
    ..sort((a, b) => a.order.compareTo(b.order));
  final ordered = options.repeatRefrain ? sungOrder(printed) : printed;
  return [
    TitleSlide(numberLabel: hymn.numberLabel, title: hymn.title),
    for (final section in ordered)
      if (section.type != SectionType.note && section.lines.isNotEmpty)
        ...() {
          final chunks = splitLines([
            for (final l in section.lines) l.text,
          ], options.maxLines);
          return [
            for (var i = 0; i < chunks.length; i++)
              LyricsSlide(
                numberLabel: hymn.numberLabel,
                sectionType: section.type,
                sectionNumber: section.number,
                part: i + 1,
                parts: chunks.length,
                lines: chunks[i],
              ),
          ];
        }(),
  ];
}

/// Élément de programme : cantique (null s'il n'est plus publié) ou moment libre.
sealed class ProgramEntry {
  const ProgramEntry();
}

final class HymnEntry extends ProgramEntry {
  const HymnEntry(this.hymn);

  final PublishedHymn? hymn;
}

final class LabelEntry extends ProgramEntry {
  const LabelEntry(this.label);

  final String label;
}

List<Slide> programSlides(
  List<ProgramEntry> entries, [
  ProjectionOptions options = const ProjectionOptions(),
]) => [
  for (final entry in entries)
    ...switch (entry) {
      LabelEntry(:final label) => [SectionSlide(label)],
      HymnEntry(:final hymn) =>
        hymn == null ? const <Slide>[] : hymnSlides(hymn, options),
    },
];
