import 'package:flutter_test/flutter_test.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';
import 'package:louanges_a_dieu/core/catalog/sung_order.dart';

HymnSection s(SectionType type, int order) => HymnSection(
  id: '00000000-0000-4000-8000-${order.toString().padLeft(12, '0')}',
  type: type,
  number: null,
  order: order,
  lines: const [HymnLine(text: 'vers', repeat: null)],
);

String names(List<HymnSection> list) => list
    .map((x) => x.type == SectionType.verse ? 'C${x.order}' : 'R')
    .join(' ');

void main() {
  const v = SectionType.verse;
  const r = SectionType.refrain;

  test(
    'refrain imprimé après le 1ᵉʳ couplet : chanté après chaque couplet',
    () {
      expect(
        names(sungOrder([s(v, 0), s(r, 1), s(v, 2), s(v, 3)])),
        'C0 R C2 R C3 R',
      );
    },
  );

  test('cantique commençant par le refrain : refrain d’abord, puis après chaque couplet', () {
    expect(names(sungOrder([s(r, 0), s(v, 1), s(v, 2)])), 'R C1 R C2 R');
  });

  test('sans refrain : ordre imprimé', () {
    expect(names(sungOrder([s(v, 0), s(v, 1)])), 'C0 C1');
  });

  test('plusieurs refrains : ordre imprimé (aucune supposition)', () {
    expect(names(sungOrder([s(v, 0), s(r, 1), s(v, 2), s(r, 3)])), 'C0 R C2 R');
  });

  test('un seul couplet : ordre imprimé', () {
    expect(names(sungOrder([s(v, 0), s(r, 1)])), 'C0 R');
  });
}
