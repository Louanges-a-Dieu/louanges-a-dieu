import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';
import 'package:louanges_a_dieu/core/projection/projection_state.dart';
import 'package:louanges_a_dieu/core/projection/slides.dart';

void main() {
  const slides = <Slide>[
    TitleSlide(numberLabel: '12', title: 'Cantique'),
    LyricsSlide(
      numberLabel: '12',
      sectionType: SectionType.verse,
      sectionNumber: 1,
      part: 1,
      parts: 2,
      lines: ['a'],
    ),
    LyricsSlide(
      numberLabel: '12',
      sectionType: SectionType.refrain,
      sectionNumber: null,
      part: 1,
      parts: 1,
      lines: ['b'],
    ),
  ];

  test('séquencement : suivant, précédent, bornes, saut', () {
    var s = const ProjectionState(slides: slides);
    expect(s.canGoBack, isFalse);
    s = s.back();
    expect(s.index, 0);
    s = s.forward().forward();
    expect(s.index, 2);
    expect(s.canGoForward, isFalse);
    expect(s.forward().index, 2);
    expect(s.next, isNull);
    expect(s.goTo(1).current, slides[1]);
    expect(s.goTo(99).index, 2);
  });

  test('écran noir indépendant de la position', () {
    final s = const ProjectionState(slides: slides).toggleBlank().forward();
    expect(s.blank, isTrue);
    expect(s.index, 1);
    expect(s.toggleBlank().blank, isFalse);
  });

  test('message envoyé aux écrans', () {
    final s = const ProjectionState(slides: slides).forward();
    expect(s.toMessage(), {
      'type': 'state',
      'v': 1,
      'index': 1,
      'count': 3,
      'blank': false,
      'slide': slides[1].toJson(),
    });
    expect(const ProjectionState(slides: []).toMessage()['slide'], isNull);
  });

  test('libellés du pilote', () {
    expect(slides.map(slideLabel), [
      '12 — Cantique',
      'Couplet 1 (1/2)',
      'Refrain',
    ]);
    expect(slideLabel(const SectionSlide('Prière')), 'Prière');
  });
}
