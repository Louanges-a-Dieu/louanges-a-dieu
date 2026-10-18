/**
 * Contrat de projection (Phase 8, ADR-009, ADR-013) : découpe d'un cantique ou
 * d'un programme en diapositives. Implémenté à l'identique en Dart
 * (apps/mobile/lib/core/projection/slides.dart) et vérifié par les mêmes
 * fixtures (fixtures/projection).
 *
 * - Diapositive de titre (numéro et titre), puis une diapositive par section.
 * - Ordre chanté (Q-07) : refrain répété après chaque couplet, désactivable ;
 *   même règle prudente que l'application (sinon ordre imprimé).
 * - Section trop longue : découpée en parties équilibrées (7 vers → 4 + 3).
 * - Sections « note » : non projetées (indications, pas des paroles chantées).
 * - Texte projeté tel qu'imprimé, marqueurs « (bis) » compris (ADR-008).
 */
import type { HymnSection, PublishedHymn } from './hymn.ts';

export type ProjectedSectionType = Exclude<HymnSection['type'], 'note'>;

export type Slide =
  | { kind: 'title'; numberLabel: string; title: string }
  | {
      kind: 'lyrics';
      numberLabel: string;
      sectionType: ProjectedSectionType;
      sectionNumber: number | null;
      part: number;
      parts: number;
      lines: string[];
    }
  | { kind: 'section'; label: string };

export interface ProjectionOptions {
  /** Refrain répété après chaque couplet (Q-07). */
  repeatRefrain: boolean;
  /** Nombre maximal de vers par diapositive. */
  maxLines: number;
}

export const defaultProjectionOptions: ProjectionOptions = { repeatRefrain: true, maxLines: 6 };

/** Même règle que `sungOrder` (Dart) : un seul refrain, que des couplets, au moins deux. */
export function sungOrder(printed: HymnSection[]): HymnSection[] {
  const refrains = printed.filter((s) => s.type === 'refrain');
  const verses = printed.filter((s) => s.type === 'verse');
  if (refrains.length !== 1 || verses.length + 1 !== printed.length || verses.length < 2) {
    return printed;
  }
  const refrain = refrains[0]!;
  return [
    ...(printed[0]!.type === 'refrain' ? [refrain] : []),
    ...verses.flatMap((verse) => [verse, refrain]),
  ];
}

/** Découpe équilibrée : les premières parties reçoivent le vers en trop. */
export function splitLines(lines: string[], maxLines: number): string[][] {
  if (maxLines < 1) throw new RangeError('maxLines doit être ≥ 1');
  const parts = Math.max(1, Math.ceil(lines.length / maxLines));
  const base = Math.floor(lines.length / parts);
  const extra = lines.length % parts;
  const result: string[][] = [];
  let start = 0;
  for (let i = 0; i < parts; i++) {
    const size = base + (i < extra ? 1 : 0);
    result.push(lines.slice(start, start + size));
    start += size;
  }
  return result;
}

export function hymnSlides(
  hymn: PublishedHymn,
  options: ProjectionOptions = defaultProjectionOptions,
): Slide[] {
  const printed = [...hymn.sections].sort((a, b) => a.order - b.order);
  const ordered = options.repeatRefrain ? sungOrder(printed) : printed;
  const slides: Slide[] = [{ kind: 'title', numberLabel: hymn.numberLabel, title: hymn.title }];
  for (const section of ordered) {
    if (section.type === 'note' || section.lines.length === 0) continue;
    const chunks = splitLines(
      section.lines.map((l) => l.text),
      options.maxLines,
    );
    chunks.forEach((lines, i) =>
      slides.push({
        kind: 'lyrics',
        numberLabel: hymn.numberLabel,
        sectionType: section.type as ProjectedSectionType,
        sectionNumber: section.number,
        part: i + 1,
        parts: chunks.length,
        lines,
      }),
    );
  }
  return slides;
}

/** Élément de programme : cantique (null s'il n'est plus publié) ou moment libre. */
export type ProgramEntry = { hymn: PublishedHymn | null } | { label: string };

export function programSlides(
  entries: ProgramEntry[],
  options: ProjectionOptions = defaultProjectionOptions,
): Slide[] {
  return entries.flatMap((entry): Slide[] => {
    if ('label' in entry) return [{ kind: 'section', label: entry.label }];
    return entry.hymn ? hymnSlides(entry.hymn, options) : [];
  });
}

/** État d'une projection (équivalent de `ProjectionState` côté Dart). */
export interface ProjectionState {
  slides: Slide[];
  index: number;
  /** Écran noir : le contenu reste en place mais n'est plus affiché. */
  blank: boolean;
}

export function goTo(state: ProjectionState, index: number): ProjectionState {
  const max = Math.max(0, state.slides.length - 1);
  return { ...state, index: Math.min(Math.max(0, index), max) };
}

/** Message envoyé aux écrans (même contrat que le téléphone, docs/architecture/projection.md). */
export function stateMessage(state: ProjectionState) {
  return {
    type: 'state' as const,
    v: 1,
    index: state.index,
    count: state.slides.length,
    blank: state.blank,
    slide: state.slides[state.index] ?? null,
  };
}

const SECTION_NAMES: Record<ProjectedSectionType, string> = {
  verse: 'Couplet',
  refrain: 'Refrain',
  bridge: 'Pont',
  intro: 'Introduction',
  outro: 'Conclusion',
};

/** Libellé court d'une diapositive (« Couplet 2 (1/2) »), comme dans l'app. */
export function slideLabel(slide: Slide): string {
  switch (slide.kind) {
    case 'title':
      return `${slide.numberLabel} — ${slide.title}`;
    case 'section':
      return slide.label;
    case 'lyrics':
      return [
        SECTION_NAMES[slide.sectionType],
        slide.sectionNumber ?? undefined,
        slide.parts > 1 ? `(${slide.part}/${slide.parts})` : undefined,
      ]
        .filter((part) => part !== undefined)
        .join(' ');
  }
}
