import 'package:flutter/foundation.dart';

import '../catalog/published_hymn.dart';
import 'slides.dart';

/// Apparence de l'écran projeté (planche 5, écran 3) : fond, numéro,
/// taille du texte.
@immutable
final class ProjectionDisplay {
  const ProjectionDisplay({
    this.background = 'dark',
    this.showNumber = true,
    this.scale = 1,
  });

  /// `dark`, `light` ou `image:<photo de l'app>`.
  final String background;
  final bool showNumber;

  /// Taille du texte relative (0,7 à 1,3) : le texte s'ajuste toujours à
  /// l'écran, ceci en règle le maximum.
  final double scale;

  static const minScale = 0.7;
  static const maxScale = 1.3;

  /// Photo de fond, ou null.
  String? get image =>
      background.startsWith('image:') ? background.substring(6) : null;

  ProjectionDisplay copyWith({
    String? background,
    bool? showNumber,
    double? scale,
  }) => ProjectionDisplay(
    background: background ?? this.background,
    showNumber: showNumber ?? this.showNumber,
    scale: (scale ?? this.scale).clamp(minScale, maxScale),
  );

  Map<String, Object?> toJson() => {
    'background': image != null ? 'image' : background,
    if (image != null) 'image': 'images/$image.jpg',
    'showNumber': showNumber,
    'scale': scale,
  };

  @override
  bool operator ==(Object other) =>
      other is ProjectionDisplay &&
      other.background == background &&
      other.showNumber == showNumber &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(background, showNumber, scale);
}

/// État d'une projection : diapositives, position, écran noir ou masqué,
/// apparence. Immuable ; chaque commande du pilote renvoie un nouvel état.
@immutable
final class ProjectionState {
  const ProjectionState({
    required this.slides,
    this.index = 0,
    this.blank = false,
    this.mask = false,
    this.display = const ProjectionDisplay(),
  }) : assert(index >= 0);

  final List<Slide> slides;
  final int index;

  /// Écran noir : le contenu reste en place mais n'est plus affiché.
  final bool blank;

  /// Écran masqué : fond et logo seulement (annonces, prière).
  final bool mask;
  final ProjectionDisplay display;

  Slide? get current => slides.isEmpty ? null : slides[index];
  Slide? get next => index + 1 < slides.length ? slides[index + 1] : null;
  bool get canGoBack => index > 0;
  bool get canGoForward => index + 1 < slides.length;

  ProjectionState _copy({
    List<Slide>? slides,
    int? index,
    bool? blank,
    bool? mask,
    ProjectionDisplay? display,
  }) => ProjectionState(
    slides: slides ?? this.slides,
    index: index ?? this.index,
    blank: blank ?? this.blank,
    mask: mask ?? this.mask,
    display: display ?? this.display,
  );

  ProjectionState goTo(int target) =>
      _copy(index: slides.isEmpty ? 0 : target.clamp(0, slides.length - 1));

  ProjectionState forward() => goTo(index + 1);
  ProjectionState back() => goTo(index - 1);
  ProjectionState toggleBlank() => _copy(blank: !blank);
  ProjectionState toggleMask() => _copy(mask: !mask);
  ProjectionState withDisplay(ProjectionDisplay display) =>
      _copy(display: display);

  /// Début du cantique en cours (sa diapositive de titre).
  int get hymnStart {
    for (var i = index; i >= 0; i--) {
      if (slides[i] is TitleSlide) return i;
    }
    return 0;
  }

  /// Prochain refrain du cantique en cours, s'il y en a un.
  int? get nextRefrain {
    for (var i = index + 1; i < slides.length; i++) {
      final slide = slides[i];
      if (slide is TitleSlide) return null;
      if (slide is LyricsSlide &&
          slide.sectionType == SectionType.refrain &&
          slide.part == 1) {
        return i;
      }
    }
    return null;
  }

  /// Titre du cantique suivant, s'il y en a un.
  int? get nextHymn {
    for (var i = index + 1; i < slides.length; i++) {
      if (slides[i] is TitleSlide) return i;
    }
    return null;
  }

  /// Remplace les diapositives (option « refrain répété » changée) en restant
  /// au même endroit du cantique autant que possible.
  ProjectionState withSlides(List<Slide> next, {int? index}) => _copy(
    slides: next,
    index: next.isEmpty ? 0 : (index ?? this.index).clamp(0, next.length - 1),
  );

  /// Message envoyé aux écrans (contrat partagé avec screen.js). `mask`,
  /// `display` et `next` (écran retour) sont facultatifs pour l'écran.
  Map<String, Object?> toMessage() => {
    'type': 'state',
    'v': 1,
    'index': index,
    'count': slides.length,
    'blank': blank,
    'mask': mask,
    'display': display.toJson(),
    'slide': current?.toJson(),
    'next': next?.toJson(),
  };
}

/// Libellé court d'une diapositive pour le pilote (« Couplet 2 (1/2) »).
String slideLabel(Slide slide) => switch (slide) {
  TitleSlide(:final numberLabel, :final title) => '$numberLabel — $title',
  SectionSlide(:final label) => label,
  TransitionSlide() => 'Transition',
  EndSlide(:final message) => message,
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
