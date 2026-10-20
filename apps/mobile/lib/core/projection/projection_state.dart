import 'package:flutter/foundation.dart';

import '../catalog/published_hymn.dart';
import 'slides.dart';

/// État d'une projection : diapositives, position, écran noir. Immuable ;
/// chaque commande du pilote renvoie un nouvel état.
@immutable
final class ProjectionState {
  const ProjectionState({
    required this.slides,
    this.index = 0,
    this.blank = false,
  }) : assert(index >= 0);

  final List<Slide> slides;
  final int index;

  /// Écran noir : le contenu reste en place mais n'est plus affiché.
  final bool blank;

  Slide? get current => slides.isEmpty ? null : slides[index];
  Slide? get next => index + 1 < slides.length ? slides[index + 1] : null;
  bool get canGoBack => index > 0;
  bool get canGoForward => index + 1 < slides.length;

  ProjectionState goTo(int target) => ProjectionState(
    slides: slides,
    index: slides.isEmpty ? 0 : target.clamp(0, slides.length - 1),
    blank: blank,
  );

  ProjectionState forward() => goTo(index + 1);
  ProjectionState back() => goTo(index - 1);
  ProjectionState toggleBlank() =>
      ProjectionState(slides: slides, index: index, blank: !blank);

  /// Remplace les diapositives (option « refrain répété » changée) en restant
  /// au même endroit du cantique autant que possible.
  ProjectionState withSlides(List<Slide> next, {int? index}) => ProjectionState(
    slides: next,
    index: next.isEmpty ? 0 : (index ?? this.index).clamp(0, next.length - 1),
    blank: blank,
  );

  /// Message envoyé aux écrans (contrat partagé avec screen.js).
  Map<String, Object?> toMessage() => {
    'type': 'state',
    'v': 1,
    'index': index,
    'count': slides.length,
    'blank': blank,
    'slide': current?.toJson(),
  };
}

/// Libellé court d'une diapositive pour le pilote (« Couplet 2 (1/2) »).
String slideLabel(Slide slide) => switch (slide) {
  TitleSlide(:final numberLabel, :final title) => '$numberLabel — $title',
  SectionSlide(:final label) => label,
  LyricsSlide(
    :final sectionType,
    :final sectionNumber,
    :final part,
    :final parts,
  ) =>
    [
      sectionName(sectionType, sectionNumber),
      if (parts > 1) '($part/$parts)',
    ].join(' '),
};
