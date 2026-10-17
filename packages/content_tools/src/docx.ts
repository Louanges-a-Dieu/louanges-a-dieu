import { strFromU8, unzipSync } from 'fflate';
import { SaxesParser } from 'saxes';

/**
 * Paragraphe extrait de word/document.xml, avec la mise en forme directe qui
 * porte la structure du recueil (le document n'utilise aucun style).
 */
export interface Paragraph {
  /** Position dans le document (ordre d'ouverture des <w:p>). */
  index: number;
  /** Texte Unicode NFC ; <w:br/> et <w:cr/> → « \n », <w:tab/> → « \t ». */
  text: string;
  align: string | null;
  spacingBefore: number | null;
  spacingAfter: number | null;
  indentFirstLine: number | null;
  indentLeft: number | null;
  border: boolean;
  keepNext: boolean;
  /** Part des caractères visibles en italique (0 à 1). */
  italicRatio: number;
  /** Part des caractères visibles en gras (0 à 1). */
  boldRatio: number;
  /** Nombre de sauts de ligne manuels dans le paragraphe. */
  manualBreaks: number;
}

interface ParagraphState extends Paragraph {
  visible: number;
  italic: number;
  bold: number;
}

interface RunState {
  italic: boolean;
  bold: boolean;
}

/** Valeur d'un attribut booléen OOXML (absence = vrai ; « 0 », « false », « off » = faux). */
function toggle(attributes: Record<string, string>): boolean {
  const value = attributes['w:val'];
  return value === undefined || !['0', 'false', 'off'].includes(value.toLowerCase());
}

function twips(value: string | undefined): number | null {
  if (value === undefined) return null;
  const n = Number.parseInt(value, 10);
  return Number.isNaN(n) ? null : n;
}

/** Lit le fichier .docx et renvoie le XML du corps du document. */
export function readDocumentXml(docx: Uint8Array): string {
  const files = unzipSync(docx, { filter: (file) => file.name === 'word/document.xml' });
  const xml = files['word/document.xml'];
  if (!xml) {
    throw new Error('Fichier .docx invalide : word/document.xml introuvable');
  }
  return strFromU8(xml);
}

/** Extrait les paragraphes du corps du document, dans l'ordre. */
export function extractParagraphs(documentXml: string): Paragraph[] {
  const parser = new SaxesParser();
  const out: ParagraphState[] = [];
  const stack: ParagraphState[] = [];
  let run: RunState | null = null;
  let inParagraphProperties = 0;
  let inRunProperties = false;
  let inText = false;

  parser.on('opentag', (tag) => {
    const attrs = tag.attributes as Record<string, string>;
    const paragraph = stack.at(-1);

    switch (tag.name) {
      case 'w:p': {
        const p: ParagraphState = {
          index: out.length,
          text: '',
          align: null,
          spacingBefore: null,
          spacingAfter: null,
          indentFirstLine: null,
          indentLeft: null,
          border: false,
          keepNext: false,
          italicRatio: 0,
          boldRatio: 0,
          manualBreaks: 0,
          visible: 0,
          italic: 0,
          bold: 0,
        };
        out.push(p);
        stack.push(p);
        return;
      }
      case 'w:pPr':
        inParagraphProperties++;
        return;
      case 'w:r':
        run = { italic: false, bold: false };
        return;
      case 'w:rPr':
        // Les propriétés de la marque de paragraphe (w:pPr/w:rPr) ne concernent pas le texte.
        inRunProperties = run !== null && inParagraphProperties === 0;
        return;
      case 'w:t':
        inText = true;
        return;
    }

    if (!paragraph) return;

    if (inRunProperties && run) {
      if (tag.name === 'w:i') run.italic = toggle(attrs);
      if (tag.name === 'w:b') run.bold = toggle(attrs);
      return;
    }

    if (inParagraphProperties > 0) {
      switch (tag.name) {
        case 'w:jc':
          paragraph.align = attrs['w:val'] ?? null;
          break;
        case 'w:spacing':
          paragraph.spacingBefore = twips(attrs['w:before']);
          paragraph.spacingAfter = twips(attrs['w:after']);
          break;
        case 'w:ind':
          paragraph.indentFirstLine = twips(attrs['w:firstLine']);
          paragraph.indentLeft = twips(attrs['w:left'] ?? attrs['w:start']);
          break;
        case 'w:pBdr':
          paragraph.border = true;
          break;
        case 'w:keepNext':
          paragraph.keepNext = toggle(attrs);
          break;
      }
      return;
    }

    if (run) {
      if (tag.name === 'w:tab') paragraph.text += '\t';
      if (tag.name === 'w:cr') {
        paragraph.text += '\n';
        paragraph.manualBreaks++;
      }
      if (tag.name === 'w:br') {
        const type = attrs['w:type'];
        if (type === undefined || type === 'textWrapping') {
          paragraph.text += '\n';
          paragraph.manualBreaks++;
        }
      }
    }
  });

  parser.on('text', (text) => {
    const paragraph = stack.at(-1);
    if (!inText || !paragraph) return;
    paragraph.text += text;
    const visible = text.replace(/\s/gu, '').length;
    paragraph.visible += visible;
    if (run?.italic) paragraph.italic += visible;
    if (run?.bold) paragraph.bold += visible;
  });

  parser.on('closetag', (tag) => {
    switch (tag.name) {
      case 'w:p':
        stack.pop();
        return;
      case 'w:pPr':
        inParagraphProperties--;
        return;
      case 'w:r':
        run = null;
        return;
      case 'w:rPr':
        inRunProperties = false;
        return;
      case 'w:t':
        inText = false;
        return;
    }
  });

  parser.write(documentXml).close();

  return out.map(({ visible, italic, bold, ...p }) => ({
    ...p,
    text: p.text.normalize('NFC'),
    italicRatio: visible === 0 ? 0 : italic / visible,
    boldRatio: visible === 0 ? 0 : bold / visible,
  }));
}
