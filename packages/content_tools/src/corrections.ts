import { fold } from '@lad/shared-contracts';

import type { Sheet } from './xlsx.ts';

/**
 * Tableurs de corrections linguistiques (Q-04, A-13) : rapprochement avec le
 * texte actuel du recueil.
 *
 * Les tableurs datent d'une numérotation antérieure : une proposition est
 * rattachée par son TEXTE (« extrait fautif » ou « correction »), jamais par
 * son numéro. Le titre du tableur départage seulement plusieurs passages.
 *
 * Pour chaque passage retrouvé, comparaison à trois branches (extrait d'origine,
 * texte actuel, correction proposée), mot à mot :
 *   - applied  : le texte actuel contient déjà la correction ;
 *   - pending  : le texte actuel contient encore l'extrait fautif, la correction
 *                peut être appliquée telle quelle (les retouches faites depuis
 *                ailleurs dans le passage sont conservées) ;
 *   - conflict : le passage a été retouché autrement depuis la relecture ;
 *                décision humaine ;
 *   - not_found: aucun passage correspondant.
 * Rien n'est jamais appliqué automatiquement : « pending » devient une
 * suggestion à valider une par une dans le back-office.
 */

export interface CorrectionRow {
  file: string;
  sheet: string;
  /** Ligne du tableur (1 = en-têtes). */
  row: number;
  /** Numéro dans l'ancienne numérotation (indicatif). */
  number: string | null;
  title: string | null;
  original: string;
  proposed: string;
  problem: string | null;
  confidence: string | null;
  /** Colonne « Validation » du tableur (« Oui », « Non » ou vide). */
  validation: string | null;
  comment: string | null;
}

/** Champ corrigé : titre, premier vers (affiché dans les listes) ou section. */
export type UnitKind = 'title' | 'opening_line' | 'section';

/** Texte cible : titre ou premier vers d'un cantique, ou texte d'une section. */
export interface TextUnit {
  hymnId: string;
  numberLabel: string;
  hymnTitle: string;
  unit: UnitKind;
  sectionId: string | null;
  text: string;
}

export interface Passage {
  unit: TextUnit;
  /** Position du passage dans le texte, en caractères Unicode (comme PostgreSQL). */
  offset: number;
  /** Passage tel qu'il est aujourd'hui, au caractère près. */
  current: string;
  /** Le titre du cantique correspond à celui du tableur. */
  titleMatches: boolean;
}

export type Match =
  | { status: 'pending'; passages: (Passage & { replacement: string })[] }
  | { status: 'applied'; passages: Passage[] }
  | { status: 'conflict'; passages: Passage[] }
  | { status: 'not_found'; passages: [] }
  | { status: 'declined'; passages: [] };

// ---------------------------------------------------------------------------
// Lecture des tableurs
// ---------------------------------------------------------------------------

const COLUMNS: Record<Exclude<keyof CorrectionRow, 'file' | 'sheet' | 'row'>, RegExp> = {
  number: /^(n|no|numero) (du )?cantique/,
  title: /^titre/,
  original: /^extrait/,
  problem: /^probleme/,
  proposed: /^correction/,
  confidence: /^confiance/,
  validation: /^validation/,
  comment: /^commentaire/,
};

/**
 * Lignes de corrections d'un classeur : feuille dont une des premières lignes
 * porte les en-têtes « Extrait … » et « Correction … ». Les lignes sans extrait
 * ou sans correction sont ignorées.
 */
export function parseCorrections(sheets: Sheet[], file: string): CorrectionRow[] {
  for (const sheet of sheets) {
    for (const header of sheet.rows.slice(0, 5)) {
      const col: Partial<Record<keyof typeof COLUMNS, number>> = {};
      header.cells.forEach((cell, i) => {
        const name = fold(cell);
        for (const [key, pattern] of Object.entries(COLUMNS)) {
          if (pattern.test(name) && col[key as keyof typeof COLUMNS] === undefined) {
            col[key as keyof typeof COLUMNS] = i;
          }
        }
      });
      if (col.original === undefined || col.proposed === undefined) continue;

      const cell = (cells: string[], key: keyof typeof COLUMNS) => {
        const i = col[key];
        const value = i === undefined ? '' : (cells[i] ?? '').trim();
        return value === '' ? null : value;
      };
      return sheet.rows
        .filter((r) => r.row > header.row)
        .flatMap((r) => {
          const original = cell(r.cells, 'original');
          const proposed = cell(r.cells, 'proposed');
          if (!original || !proposed) return [];
          return [
            {
              file,
              sheet: sheet.name,
              row: r.row,
              number: cell(r.cells, 'number'),
              title: cell(r.cells, 'title'),
              original,
              proposed,
              problem: cell(r.cells, 'problem'),
              confidence: cell(r.cells, 'confidence'),
              validation: cell(r.cells, 'validation'),
              comment: cell(r.cells, 'comment'),
            },
          ];
        });
    }
  }
  throw new Error(`${file} : aucune feuille avec les colonnes « Extrait » et « Correction »`);
}

// ---------------------------------------------------------------------------
// Mots et ponctuation
// ---------------------------------------------------------------------------

interface Token {
  text: string;
  start: number;
  end: number;
  word: boolean;
  /** Clé exacte : casse, accents et ponctuation comptent ; apostrophes et « œ » unifiés. */
  exact: string;
  /** Clé souple : ni casse ni accents (mots) ; signe lui-même (ponctuation). */
  loose: string;
}

const TOKEN = /[\p{L}\p{N}]+(?:['’\-][\p{L}\p{N}]+)*['’\-]?|[^\s\p{L}\p{N}]/gu;

function exactKey(text: string): string {
  return text.normalize('NFC').replace(/[’‘]/g, "'").replace(/œ/g, 'oe').replace(/Œ/g, 'Oe');
}

function tokenize(text: string): Token[] {
  return [...text.matchAll(TOKEN)].map((m) => {
    const word = /[\p{L}\p{N}]/u.test(m[0][0]!);
    const exact = exactKey(m[0]);
    return {
      text: m[0],
      start: m.index,
      end: m.index + m[0].length,
      word,
      exact,
      loose: word ? fold(m[0]) : exact,
    };
  });
}

/** Les tableurs notent un changement de vers « / » : on le retire. */
function excerpt(text: string): string {
  return text.replace(/\s+\/\s+/g, '\n');
}

/** Paires (i, j) de la plus longue sous-suite commune selon la clé donnée. */
function align(a: Token[], b: Token[], key: 'exact' | 'loose'): [number, number][] {
  const n = a.length;
  const m = b.length;
  const lcs = Array.from({ length: n + 1 }, () => new Array<number>(m + 1).fill(0));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      lcs[i]![j] =
        a[i]![key] === b[j]![key]
          ? lcs[i + 1]![j + 1]! + 1
          : Math.max(lcs[i + 1]![j]!, lcs[i]![j + 1]!);
    }
  }
  const pairs: [number, number][] = [];
  for (let i = 0, j = 0; i < n && j < m;) {
    if (a[i]![key] === b[j]![key]) {
      pairs.push([i, j]);
      i++;
      j++;
    } else if (lcs[i + 1]![j]! >= lcs[i]![j + 1]!) i++;
    else j++;
  }
  return pairs;
}

interface Hunk {
  /** Plage dans l'extrait d'origine [a, b). */
  a: number;
  b: number;
  /** Plage dans la correction [c, d). */
  c: number;
  d: number;
}

/** Changements de l'extrait d'origine vers la correction (mots alignés sans casse ni accents). */
function hunks(o: Token[], c: Token[]): Hunk[] {
  const out: Hunk[] = [];
  let i = 0;
  let j = 0;
  let open: Hunk | null = null;
  const close = () => {
    if (open) out.push(open);
    open = null;
  };
  for (const [pi, pj] of [...align(o, c, 'loose'), [o.length, c.length] as [number, number]]) {
    if (pi > i || pj > j) {
      open ??= { a: i, b: i, c: j, d: j };
      open.b = pi;
      open.d = pj;
    }
    if (pi === o.length) break;
    if (o[pi]!.exact === c[pj]!.exact) close();
    else {
      open ??= { a: pi, b: pi, c: pj, d: pj };
      open.b = pi + 1;
      open.d = pj + 1;
    }
    i = pi + 1;
    j = pj + 1;
  }
  close();
  // La correction ne cite souvent que la partie modifiée de l'extrait : mots
  // de l'extrait absents au début ou à la fin = contexte, pas suppression. Un
  // commentaire final entre parenthèses (« (harmoniser …) ») n'est pas du texte.
  return out.filter(
    (h) =>
      !(h.c === h.d && (h.a === 0 || h.b === o.length)) &&
      !(
        h.a === o.length &&
        h.d === c.length &&
        c[h.c]!.text === '(' &&
        c[h.d - 1]!.text === ')' &&
        c.slice(h.c, h.d).filter((t) => t.word).length >= 3
      ),
  );
}

const sameTokens = (x: Token[], y: Token[]) =>
  x.length === y.length && x.every((t, k) => t.exact === y[k]!.exact);

// ---------------------------------------------------------------------------
// Passages
// ---------------------------------------------------------------------------

/** Plages [début, fin] (indices de jetons du texte) où figurent les mots du motif. */
function locate(text: Token[], pattern: Token[]): [number, number][] {
  const words = pattern.filter((t) => t.word).map((t) => t.loose);
  if (words.length === 0) return [];
  const index = text.flatMap((t, k) => (t.word ? [k] : []));
  const lead = pattern.findIndex((t) => t.word);
  const trail = pattern.length - 1 - pattern.findLastIndex((t) => t.word);
  const out: [number, number][] = [];
  for (let i = 0; i + words.length <= index.length; i++) {
    if (!words.every((w, k) => text[index[i + k]!]!.loose === w)) continue;
    let from = index[i]!;
    let to = index[i + words.length - 1]!;
    for (let k = 0; k < lead && from > 0 && !text[from - 1]!.word; k++) from--;
    for (let k = 0; k < trail && to < text.length - 1 && !text[to + 1]!.word; k++) to++;
    out.push([from, to]);
  }
  return out;
}

type Verdict = 'applied' | 'pending' | 'conflict';

/**
 * Compare le passage actuel à l'extrait d'origine et à la correction. Renvoie
 * le verdict et, si la correction peut s'appliquer, le passage corrigé.
 */
function judge(
  unitText: string,
  current: Token[],
  o: Token[],
  c: Token[],
  cText: string,
): { verdict: Verdict; replacement?: string } {
  const changes = hunks(o, c);
  const segment = (k: number) =>
    k === 0 ? '' : unitText.slice(current[k - 1]!.end, current[k]!.start);

  if (changes.length === 0) {
    // Seuls des espaces diffèrent (« palais,Ton » → « palais, Ton »).
    const spacing = (tokens: Token[], text: string) =>
      tokens.map((t, k) =>
        k === 0 ? '' : text.slice(tokens[k - 1]!.end, t.start).replace(/\s+/g, ' '),
      );
    const now = current.map((_, k) => segment(k).replace(/\s+/g, ' '));
    if (now.join('|') === spacing(c, cText).join('|')) return { verdict: 'applied' };
    if (!sameTokens(current, o)) return { verdict: 'conflict' };
    const wanted = spacing(c, cText);
    const replacement = current
      .map((t, k) => (k === 0 ? '' : segment(k).includes('\n') ? segment(k) : wanted[k]!) + t.text)
      .join('');
    return { verdict: 'pending', replacement };
  }

  const map = new Map(align(o, current, 'loose'));
  const curly = (unitText.match(/’/g)?.length ?? 0) > (unitText.match(/'/g)?.length ?? 0);
  const replacements = new Map<number, { end: number; tokens: Token[] }>();
  let pending = false;

  for (const h of changes) {
    let left = -1;
    for (let i = h.a - 1; i >= 0; i--) {
      if (map.has(i)) {
        left = map.get(i)!;
        break;
      }
    }
    let right = current.length;
    for (let i = h.b; i < o.length; i++) {
      if (map.has(i)) {
        right = map.get(i)!;
        break;
      }
    }
    if (right <= left) return { verdict: 'conflict' };
    const before = o.slice(h.a, h.b);
    const after = c.slice(h.c, h.d);
    const region = current.slice(left + 1, right);
    // Ponctuation ajoutée depuis autour d'un mot corrigé : sans effet sur le verdict.
    const wordsOnly = [...before, ...after].every((t) => t.word);
    const view = (tokens: Token[]) => (wordsOnly ? tokens.filter((t) => t.word) : tokens);
    if (sameTokens(view(region), view(after))) continue;
    if (!sameTokens(region, before)) return { verdict: 'conflict' };
    pending = true;
    replacements.set(left + 1, { end: right, tokens: after });
  }
  if (!pending) return { verdict: 'applied' };

  let out = '';
  for (let k = 0; k < current.length;) {
    const r = replacements.get(k);
    if (!r) {
      out += segment(k) + current[k]!.text;
      k++;
      continue;
    }
    // Même nombre de mots : espaces actuels conservés (insécables, retours à la
    // ligne) ; sinon, espaces de la correction pour les mots ajoutés.
    const sameShape = r.end - k === r.tokens.length;
    r.tokens.forEach((t, n) => {
      const i = c.indexOf(t);
      const proposed = i > 0 ? cText.slice(c[i - 1]!.end, t.start).replace(/\s+/g, ' ') : ' ';
      const keep = (sameShape || n === 0) && k + n < r.end && current[k + n]!.word === t.word;
      const space = keep ? segment(k + n) : proposed;
      out += (out === '' ? '' : space) + (curly ? t.text.replace(/'/g, '’') : t.text);
    });
    k = r.end;
  }
  return { verdict: 'pending', replacement: out };
}

/** Le titre du tableur désigne-t-il ce cantique ? (titres = incipits, parfois tronqués) */
function sameTitle(a: string | null, b: string): boolean {
  if (!a) return false;
  const x = fold(a);
  const y = fold(b);
  if (x === y) return true;
  const [short, long] = x.length < y.length ? [x, y] : [y, x];
  return short.length >= 12 && long.startsWith(short);
}

function codePoints(text: string): number {
  return [...text].length;
}

/** Plus longue sous-suite commune de mots (clés souples), pour l'approximation. */
function similarity(a: string[], b: string[]): number {
  const lcs = Array.from({ length: a.length + 1 }, () => new Array<number>(b.length + 1).fill(0));
  for (let i = a.length - 1; i >= 0; i--) {
    for (let j = b.length - 1; j >= 0; j--) {
      lcs[i]![j] =
        a[i] === b[j] ? lcs[i + 1]![j + 1]! + 1 : Math.max(lcs[i + 1]![j]!, lcs[i]![j + 1]!);
    }
  }
  return lcs[0]![0]! / Math.max(a.length, b.length);
}

interface IndexedUnit {
  unit: TextUnit;
  tokens: Token[];
}

export class CorrectionMatcher {
  private readonly units: IndexedUnit[];

  constructor(units: TextUnit[]) {
    this.units = units.map((unit) => ({ unit, tokens: tokenize(unit.text) }));
  }

  match(row: CorrectionRow): Match {
    if (row.validation && fold(row.validation) === 'non')
      return { status: 'declined', passages: [] };
    const oText = excerpt(row.original);
    const cText = excerpt(row.proposed);
    const o = tokenize(oText);
    const c = tokenize(cText);

    type Found = Passage & { verdict: Verdict; replacement?: string | undefined };
    let found: Found[] = [];
    for (const { unit, tokens } of this.units) {
      const ranges = [...locate(tokens, o), ...locate(tokens, c)]
        .sort((x, y) => x[0] - y[0] || y[1] - x[1])
        .filter((r, k, all) => k === 0 || r[0] > all[k - 1]![1]);
      for (const [from, to] of ranges) {
        const current = tokens.slice(from, to + 1);
        const { verdict, replacement } = judge(unit.text, current, o, c, cText);
        const start = current[0]!.start;
        found.push({
          unit,
          offset: codePoints(unit.text.slice(0, start)),
          current: unit.text.slice(start, current.at(-1)!.end),
          titleMatches: sameTitle(row.title, unit.hymnTitle),
          verdict,
          replacement,
        });
      }
    }
    if (found.some((f) => f.titleMatches)) found = found.filter((f) => f.titleMatches);
    const strip = ({ verdict: _v, replacement: _r, ...p }: Found): Passage => p;

    const pending = found.filter((f) => f.verdict === 'pending');
    if (pending.length > 0) {
      return {
        status: 'pending',
        passages: pending.map((f) => ({ ...strip(f), replacement: f.replacement! })),
      };
    }
    const conflicts = found.filter((f) => f.verdict === 'conflict');
    if (conflicts.length > 0 && !found.some((f) => f.verdict === 'applied')) {
      return { status: 'conflict', passages: conflicts.map(strip) };
    }
    if (found.length > 0) {
      return {
        status: 'applied',
        passages: found.filter((f) => f.verdict === 'applied').map(strip),
      };
    }
    const near = this.nearest(row, o);
    return near ? { status: 'conflict', passages: [near] } : { status: 'not_found', passages: [] };
  }

  /** Passage le plus proche (60 % des mots au moins) dans le cantique désigné par le titre. */
  private nearest(row: CorrectionRow, o: Token[]): Passage | null {
    const words = o.filter((t) => t.word).map((t) => t.loose);
    if (words.length < 3) return null;
    let best: { score: number; unit: TextUnit; from: Token; to: Token } | null = null;
    for (const { unit, tokens } of this.units) {
      if (!sameTitle(row.title, unit.hymnTitle)) continue;
      const w = tokens.filter((t) => t.word);
      for (let len = Math.max(1, words.length - 2); len <= words.length + 2; len++) {
        for (let i = 0; i + len <= w.length; i++) {
          const slice = w.slice(i, i + len);
          const score = similarity(
            words,
            slice.map((t) => t.loose),
          );
          if (score >= 0.6 && (!best || score > best.score)) {
            best = { score, unit, from: slice[0]!, to: slice.at(-1)! };
          }
        }
      }
    }
    if (!best) return null;
    // Vers entiers, pour que l'éditeur voie le passage dans son contexte.
    const text = best.unit.text;
    const start = text.lastIndexOf('\n', best.from.start - 1) + 1;
    const lineEnd = text.indexOf('\n', best.to.end);
    return {
      unit: best.unit,
      offset: codePoints(text.slice(0, start)),
      current: text.slice(start, lineEnd < 0 ? text.length : lineEnd),
      titleMatches: true,
    };
  }
}
