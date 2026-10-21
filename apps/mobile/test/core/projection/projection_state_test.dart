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
      'mask': false,
      'display': {'background': 'dark', 'showNumber': true, 'scale': 1.0},
      'slide': slides[1].toJson(),
      'next': slides[2].toJson(),
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

  test('masquer, apparence, refrain, relancer, cantique suivant', () {
    const program = <Slide>[
      ...slides,
      TitleSlide(numberLabel: '13', title: 'Autre'),
      LyricsSlide(
        numberLabel: '13',
        sectionType: SectionType.refrain,
        sectionNumber: null,
        part: 1,
        parts: 1,
        lines: ['c'],
      ),
    ];
    var s = const ProjectionState(slides: program).goTo(1);
    expect(s.toggleMask().mask, isTrue);
    expect(s.nextRefrain, 2);
    expect(s.nextHymn, 3);
    expect(s.goTo(2).hymnStart, 0);
    expect(s.goTo(2).nextRefrain, isNull, reason: 'pas au-delà du cantique');
    s = s.goTo(4);
    expect(s.hymnStart, 3);
    expect(s.nextHymn, isNull);

    final display = const ProjectionDisplay().copyWith(
      background: 'image:hero_wheat_sunset',
      showNumber: false,
      scale: 5,
    );
    expect(display.scale, ProjectionDisplay.maxScale);
    expect(s.withDisplay(display).toMessage()['display'], {
      'background': 'image',
      'image': 'images/hero_wheat_sunset.jpg',
      'showNumber': false,
      'scale': ProjectionDisplay.maxScale,
    });
  });

  test('programme : transitions entre cantiques et message de fin', () {
    const a = TitleSlide(numberLabel: '1', title: 'Un');
    const b = TitleSlide(numberLabel: '2', title: 'Deux');
    const section = SectionSlide('Prière');
    final result = withProgramExtras(
      const [section, a, b],
      transitions: true,
      endMessage: '  Merci !  ',
    );
    expect(result.map((s) => s.toJson()['kind']), [
      'section',
      'title',
      'transition',
      'title',
      'end',
    ]);
    expect((result.last as EndSlide).message, 'Merci !');
    expect(withProgramExtras(const [a, b], endMessage: ' '), [a, b]);
  });
}
