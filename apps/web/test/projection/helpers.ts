import { PublishedHymn } from '@lad/shared-contracts';

let counter = 0;
const uuid = () => `00000000-0000-4000-8000-${String(++counter).padStart(12, '0')}`;

/** Cantique conforme au contrat, pour les tests. */
export function hymn(numberLabel: string, title: string, lines: string[] = [title]): PublishedHymn {
  const match = /^(\d+)(bis|ter)?$/.exec(numberLabel)!;
  return PublishedHymn.parse({
    id: uuid(),
    numberLabel,
    numberNumeric: Number(match[1]),
    numberSuffix: match[2] ?? null,
    title,
    openingLine: lines[0],
    languageCode: 'fr',
    sections: [
      {
        id: uuid(),
        type: 'verse',
        number: 1,
        order: 0,
        lines: lines.map((text) => ({ text, repeat: null })),
      },
    ],
    bibleReferences: [],
    relations: [],
    people: [],
    themes: [],
  });
}
