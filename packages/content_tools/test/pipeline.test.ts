import { CatalogDraft } from '@lad/shared-contracts';
import { describe, expect, it } from 'vitest';

import { extractParagraphs, readDocumentXml } from '../src/docx.ts';
import { checkFidelity } from '../src/fidelity.ts';
import { importDocx } from '../src/pipeline.ts';
import { renderReport } from '../src/report.ts';
import {
  classifyRepeatMarker,
  otherParentheticals,
  parseBibleReference,
  structure,
} from '../src/structure.ts';
import {
  docx,
  documentXml,
  number,
  p,
  sampleBook,
  separator,
  stanza,
  title,
} from './docx-builder.ts';

const options = { filename: 'test.docx', editionName: 'Édition de test', editionNumber: 1 };
const run = () => importDocx(docx(sampleBook()), options);
const hymn = (label: string) => run().draft.hymns.find((h) => h.numberLabel === label)!;
const issues = (code: string) => run().draft.issues.filter((i) => i.code === code);

describe('extraction .docx', () => {
  it('lit les paragraphes, la mise en forme et les sauts de ligne manuels', () => {
    const ps = extractParagraphs(readDocumentXml(docx(sampleBook())));
    const n = ps.find((x) => x.text === '1')!;
    expect(n).toMatchObject({ align: 'center', spacingBefore: 220, boldRatio: 1 });
    const manual = ps.find((x) => x.manualBreaks > 0)!;
    expect(manual.text).toBe('Chant deux, vers un,\nvers deux par saut manuel');
  });

  it('respecte w:val="0" (italique désactivé) et ignore la marque de paragraphe', () => {
    const [off, on] = extractParagraphs(
      documentXml([p('texte', { italic: 'off' }), p('texte', { italic: true })]),
    );
    expect(off!.italicRatio).toBe(0);
    expect(off!.boldRatio).toBe(0); // <w:b/> de la marque de paragraphe ignoré
    expect(on!.italicRatio).toBe(1);
  });

  it('ignore le texte supprimé en suivi des modifications', () => {
    const xml = documentXml([
      '<w:p><w:r><w:t>gardé</w:t></w:r><w:del><w:r><w:delText>supprimé</w:delText></w:r></w:del></w:p>',
    ]);
    expect(extractParagraphs(xml)[0]!.text).toBe('gardé');
  });

  it('refuse un fichier qui n’est pas un .docx', () => {
    expect(() => readDocumentXml(new Uint8Array([1, 2, 3]))).toThrow();
  });
});

describe('structuration', () => {
  it('produit un catalogue conforme au contrat', () => {
    expect(() => CatalogDraft.parse(run().draft)).not.toThrow();
    expect(run().draft.hymns.map((h) => h.numberLabel)).toEqual(['1', '2', '2bis', '4']);
  });

  it('distingue strophes et refrain, dans l’ordre imprimé', () => {
    expect(hymn('1').sections.map((s) => [s.type, s.text])).toEqual([
      ['verse', 'Premier vers du chant un,\nDeuxième vers. (bis)'],
      ['refrain', 'Vers de refrain,\nRefrain final. (ter)'],
      ['verse', 'Second couplet, vers un,\nSecond couplet, vers deux.'],
    ]);
  });

  it('conserve les marqueurs de répétition dans le texte (verbatim)', () => {
    expect(hymn('1').sections[0]!.text).toContain('(bis)');
  });

  it('gère le régime de strophes à retrait gauche', () => {
    expect(hymn('2bis').sections).toHaveLength(2);
    expect(issues('A-03')[0]!.details).toMatchObject({ count: 1, first: '2bis' });
  });

  it('sépare les vers d’un saut de ligne manuel', () => {
    expect(hymn('2').sections[0]!.text.split('\n')).toHaveLength(2);
    expect(issues('A-04').map((i) => i.numberLabel)).toEqual(['2']);
  });

  it('relie un numéro « bis » à son cantique principal', () => {
    expect(hymn('2bis')).toMatchObject({
      numberNumeric: 2,
      numberSuffix: 'bis',
      relations: [{ type: 'bis_of', relatedNumberLabel: '2' }],
    });
  });

  it('extrait les références bibliques', () => {
    expect(hymn('1').bibleReferences).toEqual([
      {
        displayText: 'Psaumes 150',
        book: 'Psaumes',
        chapterStart: 150,
        verseStart: null,
        chapterEnd: null,
        verseEnd: null,
      },
    ]);
  });

  it('n’invente rien : titre et premier vers tels qu’imprimés, aucune métadonnée', () => {
    const h = hymn('4');
    expect(h.title).toBe('O chant quatre');
    expect(h.openingLine).toBe('Ô chant quatre, vers un,');
    expect(Object.keys(h)).not.toEqual(expect.arrayContaining(['people', 'themes', 'author']));
  });

  it('s’arrête à l’index et ne prend pas l’index pour du texte', () => {
    const last = hymn('4');
    expect(last.sections.flatMap((s) => s.text.split('\n'))).toEqual([
      'Ô chant quatre, vers un,',
      'vers deux.',
    ]);
  });
});

describe('anomalies', () => {
  it('A-01 : numéro manquant', () => {
    expect(issues('A-01')[0]!.details).toEqual({ missing: [3] });
  });

  it('A-02 : lit les lignes d’index à plusieurs numéros (« 1, 4 »)', () => {
    const ps = extractParagraphs(readDocumentXml(docx(sampleBook())));
    const labels = structure(ps).indexEntries.map((e) => e.numberLabel);
    expect(labels).toEqual(expect.arrayContaining(['1', '4', '2', '2bis']));
    expect(issues('A-02').map((i) => i.numberLabel)).toEqual(['4']); // titre différent dans l'index
  });

  it('A-08 : titre différent du premier vers (« O » / « Ô »)', () => {
    expect(issues('A-08').map((i) => i.numberLabel)).toEqual(['4']);
  });

  it('A-09 / A-10 : marqueur non standard et parenthèse conservée', () => {
    expect(issues('A-09').map((i) => i.details.marker)).toEqual(['(4 x)']);
    expect(issues('A-10').map((i) => i.details.text)).toEqual(['(amen !)']);
  });

  it('A-12 : détecte un texte en double', () => {
    const lines = [
      'Une suite de mots assez longue pour comparer,',
      'encore des mots pour former des triplets,',
      'et une fin commune à ces deux chants.',
    ];
    const book = [
      number('1'),
      title('Un'),
      ...stanza(lines),
      separator(),
      number('2'),
      title('Deux'),
      ...stanza(lines),
      separator(),
    ];
    const dup = importDocx(docx(book), options).draft.issues.filter((i) => i.code === 'A-12');
    expect(dup).toHaveLength(1);
    expect(dup[0]).toMatchObject({
      severity: 'warning',
      numberLabel: '1',
      details: { other: '2' },
    });
  });

  it('A-16 : numéro en double (bloquant)', () => {
    const book = [
      number('1'),
      title('Un'),
      ...stanza(['a b c.']),
      number('1'),
      title('Un'),
      ...stanza(['d e f.']),
    ];
    const dup = importDocx(docx(book), options).draft.issues.filter((i) => i.code === 'A-16');
    expect(dup[0]).toMatchObject({ severity: 'blocking', numberLabel: '1' });
  });

  it('A-19 : titre introuvable (bloquant), le cantique reste importé avec son premier vers', () => {
    const book = [number('1'), ...stanza(['Premier vers sans titre,', 'suite.'])];
    const r = importDocx(docx(book), options);
    expect(r.draft.issues.find((i) => i.code === 'A-19')?.severity).toBe('blocking');
    expect(r.draft.hymns[0]!.title).toBe('Premier vers sans titre,');
  });
});

describe('fidélité aller-retour', () => {
  it('est conforme sur le recueil synthétique', () => {
    const r = run();
    expect(r.fidelity.paragraphCountMatches).toBe(true);
    expect(r.fidelity.mismatches).toEqual([]);
  });

  it('détecte un vers perdu ou modifié', () => {
    const bytes = docx(sampleBook());
    const xml = readDocumentXml(bytes);
    const ps = extractParagraphs(xml);
    const { hymns } = structure(ps);
    const tampered = structuredClone(hymns);
    tampered[0]!.sections[0]!.text = tampered[0]!.sections[0]!.text.replace('Deuxième', 'Second');
    const end = ps.findIndex((x) => x.text === 'Index des cantiques');
    expect(
      checkFidelity(xml, ps.length, tampered, end).mismatches.map((m) => m.numberLabel),
    ).toEqual(['1']);
  });
});

describe('utilitaires', () => {
  it.each([
    [
      'Psaumes 47',
      { book: 'Psaumes', chapterStart: 47, verseStart: null, chapterEnd: null, verseEnd: null },
    ],
    [
      'Jean 3.16',
      { book: 'Jean', chapterStart: 3, verseStart: 16, chapterEnd: null, verseEnd: null },
    ],
    [
      '1 Jean 4.8-10',
      { book: '1 Jean', chapterStart: 4, verseStart: 8, chapterEnd: null, verseEnd: 10 },
    ],
    [
      'Psaumes 1-3',
      { book: 'Psaumes', chapterStart: 1, verseStart: null, chapterEnd: 3, verseEnd: null },
    ],
    [
      'Romains 8.38-9.2',
      { book: 'Romains', chapterStart: 8, verseStart: 38, chapterEnd: 9, verseEnd: 2 },
    ],
  ])('analyse la référence « %s »', (text, expected) => {
    expect(parseBibleReference(text)).toMatchObject(expected);
  });

  it('refuse une référence sans chapitre', () => {
    expect(parseBibleReference('Psaumes')).toBeNull();
  });

  it.each([
    ['C’est en mon cœur. (bis)', 'standard'],
    ['Alléluia (4x)', 'standard'],
    ['Gloire (4 x)', 'variant'],
    ['Saint (x4)', 'variant'],
    ['Ligne (2)', 'ambiguous'],
    ['Jésus revient (bis), Il vient', 'midline'],
  ])('classe le marqueur de « %s »', (line, kind) => {
    expect(classifyRepeatMarker(line)?.kind).toBe(kind);
  });

  it('ne voit pas de marqueur dans une réponse chantée', () => {
    expect(classifyRepeatMarker('Louez-Le (alléluia !)')).toBeNull();
    expect(otherParentheticals('Louez-Le (alléluia !) (bis)')).toEqual(['(alléluia !)']);
  });
});

describe('rapport', () => {
  it('est autonome et échappe le contenu', () => {
    const html = renderReport(run());
    expect(html).toContain('<!doctype html>');
    expect(html).not.toMatch(/<script|https?:\/\//u);
    expect(html).toContain('Conforme : 4 cantiques');
  });
});

describe('provenance', () => {
  it('enregistre l’empreinte SHA-256 du fichier source, stable d’une exécution à l’autre', () => {
    expect(run().draft.source.sha256).toMatch(/^[0-9a-f]{64}$/u);
    expect(run().draft.source.sha256).toBe(run().draft.source.sha256);
  });
});
