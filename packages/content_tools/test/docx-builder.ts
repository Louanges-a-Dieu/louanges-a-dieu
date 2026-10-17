import { strToU8, zipSync } from 'fflate';

/**
 * Générateur de .docx SYNTHÉTIQUES reproduisant la mise en forme du recueil
 * (aucun texte réel dans le dépôt). Chaque fonction renvoie un <w:p>.
 */

const escape = (s: string): string =>
  s.replace(/&/gu, '&amp;').replace(/</gu, '&lt;').replace(/>/gu, '&gt;');

interface ParagraphOptions {
  jc?: string;
  before?: number;
  after?: number;
  firstLine?: number;
  left?: number;
  border?: boolean;
  italic?: boolean | 'off';
  bold?: boolean;
}

export function p(text: string, o: ParagraphOptions = {}): string {
  const ppr: string[] = [];
  if (o.border) ppr.push('<w:pBdr><w:left w:val="single" w:sz="4"/></w:pBdr>');
  if (o.before !== undefined || o.after !== undefined) {
    ppr.push(
      `<w:spacing${o.before !== undefined ? ` w:before="${o.before}"` : ''}${o.after !== undefined ? ` w:after="${o.after}"` : ''}/>`,
    );
  }
  if (o.firstLine !== undefined || o.left !== undefined) {
    ppr.push(
      `<w:ind${o.left !== undefined ? ` w:left="${o.left}"` : ''}${o.firstLine !== undefined ? ` w:firstLine="${o.firstLine}"` : ''}/>`,
    );
  }
  if (o.jc) ppr.push(`<w:jc w:val="${o.jc}"/>`);
  const rpr: string[] = [];
  if (o.italic === true) rpr.push('<w:i/>');
  if (o.italic === 'off') rpr.push('<w:i w:val="0"/>');
  if (o.bold) rpr.push('<w:b/>');
  const runs = text
    .split('\n')
    .map((line, i) => `${i > 0 ? '<w:br/>' : ''}<w:t xml:space="preserve">${escape(line)}</w:t>`)
    .join('');
  return `<w:p><w:pPr>${ppr.join('')}<w:rPr><w:b/></w:rPr></w:pPr><w:r><w:rPr>${rpr.join('')}</w:rPr>${runs}</w:r></w:p>`;
}

export const number = (label: string): string =>
  p(label, { jc: 'center', before: 220, after: 10, bold: true });
export const title = (text: string): string => p(text, { jc: 'center', after: 90, italic: true });
export const separator = (): string => p('✤', { jc: 'center', before: 110, after: 110 });
export const reference = (text: string): string =>
  p(`— ${text} —`, { jc: 'right', before: 60, after: 30, italic: true });
export const indexHeading = (): string =>
  p('Index des cantiques', { jc: 'center', before: 100, after: 260 });

/** Strophe, régime 1 : retrait de 1ʳᵉ ligne, espacement après sur le dernier vers. */
export function stanza(lines: string[]): string[] {
  return lines.map((line, i) =>
    p(line, {
      jc: 'both',
      ...(i === 0 ? { firstLine: 160 } : {}),
      ...(i === lines.length - 1 ? { after: 80 } : {}),
    }),
  );
}

/** Strophe, régime 2 : retrait gauche. */
export function stanzaLeft(lines: string[]): string[] {
  return lines.map((line, i) =>
    p(line, {
      jc: 'both',
      ...(i === 0 ? { left: 142 } : {}),
      ...(i === lines.length - 1 ? { after: 80 } : {}),
    }),
  );
}

/** Refrain encadré, en italique. */
export function refrain(lines: string[], italic = true): string[] {
  return lines.map((line, i) =>
    p(line, { border: true, left: 160, italic, ...(i === lines.length - 1 ? { after: 100 } : {}) }),
  );
}

export function documentXml(paragraphs: string[]): string {
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${paragraphs.join('')}</w:body></w:document>`;
}

export function docx(paragraphs: string[]): Uint8Array {
  return zipSync({
    '[Content_Types].xml': strToU8('<?xml version="1.0"?><Types/>'),
    'word/document.xml': strToU8(documentXml(paragraphs)),
  });
}

/** Petit recueil synthétique couvrant les cas du vrai document. */
export function sampleBook(): string[] {
  return [
    p('RECUEIL DE TEST', { jc: 'center', bold: true }),
    p('Note liminaire synthétique.'),
    number('1'),
    title('Premier vers du chant un'),
    ...stanza(['Premier vers du chant un,', 'Deuxième vers. (bis)']),
    ...refrain(['Vers de refrain,', 'Refrain final. (ter)']),
    ...stanza(['Second couplet, vers un,', 'Second couplet, vers deux.']),
    reference('Psaumes 150'),
    separator(),
    number('2'),
    title('Chant deux'),
    p('Chant deux, vers un,\nvers deux par saut manuel', { jc: 'both', firstLine: 160, after: 80 }),
    separator(),
    number('2bis'),
    title('Autre texte même mélodie'),
    ...stanzaLeft(['Autre texte même mélodie,', 'avec une réponse (amen !)']),
    ...stanzaLeft(['Deuxième strophe à retrait gauche,', 'fin. (4 x)']),
    separator(),
    number('4'),
    title('O chant quatre'),
    ...stanza(['Ô chant quatre, vers un,', 'vers deux.']),
    separator(),
    indexHeading(),
    p('A', { border: true }),
    p('Autre texte même mélodie\t2bis'),
    p('Chant deux\t2'),
    p('Premier vers du chant un\t1, 4'),
    p('Achevé d’imprimer en test', { jc: 'center' }),
  ];
}
