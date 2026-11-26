import { strFromU8, unzipSync } from 'fflate';
import { SaxesParser } from 'saxes';

/** Feuille d'un classeur : lignes de cellules texte (« » pour une cellule vide). */
export interface Sheet {
  name: string;
  /** Numéro de ligne Excel (1 = première ligne) → cellules, colonne A en premier. */
  rows: { row: number; cells: string[] }[];
}

interface Tag {
  name: string;
  attributes: Record<string, string>;
}

function parse(
  xml: string,
  handlers: {
    open?: (tag: Tag) => void;
    close?: (tag: Tag) => void;
    text?: (text: string) => void;
  },
) {
  const parser = new SaxesParser();
  if (handlers.open) parser.on('opentag', (tag) => handlers.open!(tag as unknown as Tag));
  if (handlers.close) parser.on('closetag', (tag) => handlers.close!(tag as unknown as Tag));
  if (handlers.text) parser.on('text', handlers.text);
  parser.write(xml).close();
}

/** Chaînes partagées : texte de chaque <si>, runs enrichis concaténés, phonétique ignorée. */
function sharedStrings(xml: string | undefined): string[] {
  if (!xml) return [];
  const out: string[] = [];
  let current: string | null = null;
  let inText = false;
  let inPhonetic = false;
  parse(xml, {
    open: (tag) => {
      if (tag.name === 'si') current = '';
      else if (tag.name === 'rPh') inPhonetic = true;
      else if (tag.name === 't' && !inPhonetic) inText = true;
    },
    close: (tag) => {
      if (tag.name === 'si') {
        out.push(current ?? '');
        current = null;
      } else if (tag.name === 'rPh') inPhonetic = false;
      else if (tag.name === 't') inText = false;
    },
    text: (text: string) => {
      if (inText && current !== null) current += text;
    },
  });
  return out;
}

/** « AB12 » → 27 (index de colonne à partir de 0). */
function columnIndex(ref: string): number {
  const letters = /^[A-Z]+/.exec(ref)?.[0] ?? 'A';
  let n = 0;
  for (const c of letters) n = n * 26 + (c.charCodeAt(0) - 64);
  return n - 1;
}

function readSheet(xml: string, strings: string[]): Sheet['rows'] {
  const rows: Sheet['rows'] = [];
  let cells: string[] | null = null;
  let rowNumber = 0;
  let cell: { col: number; type: string; value: string } | null = null;
  let capture = false;
  parse(xml, {
    open: (tag) => {
      if (tag.name === 'row') {
        rowNumber = Number(tag.attributes.r ?? rowNumber + 1);
        cells = [];
      } else if (tag.name === 'c' && cells) {
        cell = {
          col: tag.attributes.r ? columnIndex(tag.attributes.r) : cells.length,
          type: tag.attributes.t ?? 'n',
          value: '',
        };
      } else if (cell && (tag.name === 'v' || tag.name === 't')) capture = true;
    },
    close: (tag) => {
      if (tag.name === 'v' || tag.name === 't') capture = false;
      else if (tag.name === 'c' && cell && cells) {
        const value = cell.type === 's' ? (strings[Number(cell.value)] ?? '') : cell.value;
        while (cells.length < cell.col) cells.push('');
        cells[cell.col] = value;
        cell = null;
      } else if (tag.name === 'row' && cells) {
        rows.push({ row: rowNumber, cells });
        cells = null;
      }
    },
    text: (text: string) => {
      if (capture && cell) cell.value += text;
    },
  });
  return rows;
}

/**
 * Lit les feuilles d'un classeur .xlsx (valeurs telles qu'enregistrées : pour
 * une formule, son dernier résultat calculé). Texte normalisé en NFC.
 */
export function readXlsx(file: Uint8Array): Sheet[] {
  const files = unzipSync(file, {
    filter: (f) =>
      (f.name.startsWith('xl/') && f.name.endsWith('.xml')) || f.name.endsWith('.rels'),
  });
  const text = (name: string) => (files[name] ? strFromU8(files[name]) : undefined);
  const workbook = text('xl/workbook.xml');
  if (!workbook) throw new Error('Fichier .xlsx invalide : xl/workbook.xml introuvable');

  const targets = new Map<string, string>();
  parse(text('xl/_rels/workbook.xml.rels') ?? '<Relationships/>', {
    open: (tag) => {
      if (tag.name === 'Relationship' && tag.attributes.Id && tag.attributes.Target) {
        const target = tag.attributes.Target.replace(/^\/?xl\//, '').replace(/^\//, '');
        targets.set(tag.attributes.Id, `xl/${target}`);
      }
    },
  });

  const strings = sharedStrings(text('xl/sharedStrings.xml'));
  const sheets: Sheet[] = [];
  parse(workbook, {
    open: (tag) => {
      if (tag.name !== 'sheet') return;
      const path = targets.get(tag.attributes['r:id'] ?? '');
      const xml = path ? text(path) : undefined;
      if (!xml) return;
      sheets.push({
        name: tag.attributes.name ?? '',
        rows: readSheet(xml, strings).map((r) => ({
          row: r.row,
          cells: r.cells.map((c) => c.normalize('NFC')),
        })),
      });
    },
  });
  return sheets;
}
