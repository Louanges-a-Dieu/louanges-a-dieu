import { PublishedHymn } from '@lad/shared-contracts';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import { HymnPreview } from '../src/components/hymn-preview';
import {
  formatClock,
  formatSegments,
  parseClock,
  parseDuration,
  parseSegments,
} from '../src/lib/audio';
import { normalizeSectionText, sectionName, themeSlug } from '../src/lib/text';
import { transitions } from '../src/lib/transitions';
import { OptionalInt, OptionalText, ReturnPath } from '../src/lib/validation';

describe('validation des formulaires', () => {
  it('chemin de retour : interne uniquement (pas de redirection vers un autre site)', () => {
    expect(ReturnPath.parse('/cantiques?statut=draft')).toBe('/cantiques?statut=draft');
    for (const bad of [
      '//evil.example',
      'https://evil.example',
      '/\\evil.example',
      'javascript:alert(1)',
      '',
      null,
    ]) {
      expect(ReturnPath.parse(bad)).toBe('/');
    }
  });

  it('texte et nombre facultatifs : vide → null (jamais de valeur fictive)', () => {
    expect(OptionalText.parse('  ')).toBeNull();
    expect(OptionalText.parse(' Psaume 23 ')).toBe('Psaume 23');
    expect(OptionalInt.parse('')).toBeNull();
    expect(OptionalInt.parse('12')).toBe(12);
    expect(() => OptionalInt.parse('-1')).toThrow();
  });
});

describe('texte des sections', () => {
  it('normalise les fins de ligne et retire seulement les espaces de fin de vers', () => {
    expect(normalizeSectionText('\r\n Premier vers,  \r\nSecond (bis)\t\n\n')).toBe(
      ' Premier vers,\nSecond (bis)',
    );
  });

  it('identifiant de thème stable, sans accents', () => {
    expect(themeSlug('  Saint-Esprit ')).toBe('saint-esprit');
    expect(themeSlug('Noël & Pâques')).toBe('noel-paques');
  });

  it('nomme les sections comme l’application', () => {
    expect(sectionName('verse', 2)).toBe('Couplet 2');
    expect(sectionName('refrain', null)).toBe('Refrain');
  });
});

describe('transitions de statut', () => {
  const labels = (s: string, sa = false) => transitions(s, sa).map((t) => t.to);
  it('suivent le workflow, l’archivage étant réservé au super administrateur', () => {
    expect(labels('draft')).toEqual(['review']);
    expect(labels('review')).toEqual(['published', 'draft']);
    expect(labels('published')).toEqual(['draft']);
    expect(labels('archived')).toEqual([]);
    expect(labels('draft', true)).toEqual(['review', 'archived']);
    expect(labels('archived', true)).toEqual(['draft']);
  });
});

describe('aperçu comme sur mobile', () => {
  const hymn = PublishedHymn.parse({
    id: '00000000-0000-4000-8000-000000000001',
    numberLabel: '37bis',
    numberNumeric: 37,
    numberSuffix: 'bis',
    title: 'Oh ! quel beau jour',
    openingLine: null,
    languageCode: 'fr',
    sections: [
      {
        id: '00000000-0000-4000-8000-000000000002',
        type: 'refrain',
        number: null,
        order: 1,
        lines: [{ text: 'Gloire (bis)', repeat: { count: 2, marker: '(bis)' } }],
      },
      {
        id: '00000000-0000-4000-8000-000000000003',
        type: 'verse',
        number: 1,
        order: 0,
        lines: [{ text: 'Premier vers', repeat: null }],
      },
    ],
    bibleReferences: [],
    relations: [],
    people: [],
    themes: [],
  });

  it('affiche numéro, titre, sections dans l’ordre et répétitions reconnues', () => {
    const html = renderToStaticMarkup(<HymnPreview hymn={hymn} />);
    expect(html).toContain('37bis');
    expect(html.indexOf('Couplet 1')).toBeLessThan(html.indexOf('Refrain'));
    expect(html).toContain('Gloire (bis)');
    expect(html).toContain('×2');
  });

  it('n’affiche aucune information inconnue (T-010)', () => {
    const html = renderToStaticMarkup(<HymnPreview hymn={hymn} />);
    expect(html).not.toMatch(/auteur|thème|référence|undefined|null/i);
  });
});

describe('enregistrements audio', () => {
  const sections = [
    { id: 's1', section_type: 'verse', section_number: 1 },
    { id: 's2', section_type: 'refrain', section_number: null },
    { id: 's3', section_type: 'verse', section_number: null },
    { id: 's4', section_type: 'verse', section_number: null },
  ];

  it('durée : « m:ss », « h:mm:ss » ou secondes ; vide → null', () => {
    expect(parseDuration('')).toBeNull();
    expect(parseDuration('3:05')).toBe(185);
    expect(parseDuration('1:02:07')).toBe(3727);
    expect(parseDuration('185,5')).toBe(185.5);
    expect(parseDuration('0')).toBe('invalide');
    expect(parseDuration('3:75')).toBe('invalide');
    expect(parseDuration('trois minutes')).toBe('invalide');
  });

  it('horloge : aller-retour', () => {
    expect(formatClock(185_000)).toBe('3:05');
    expect(formatClock(3_727_000)).toBe('1:02:07');
    expect(formatClock(12_500)).toBe('0:12.5');
    expect(parseClock('0:12.5')).toBe(12_500);
  });

  it('passages : nom unique, « #n », « - », puis la fin', () => {
    const result = parseSegments(
      '0:00 Couplet 1\n0:30 refrain\n\n1:00 #3\n1:30 -\n1:40 #4\n2:10 Refrain\n2:40 fin',
      sections,
    );
    expect(result).toEqual({
      segments: [
        { section_id: 's1', start_ms: 0, end_ms: 30_000 },
        { section_id: 's2', start_ms: 30_000, end_ms: 60_000 },
        { section_id: 's3', start_ms: 60_000, end_ms: 90_000 },
        { section_id: null, start_ms: 90_000, end_ms: 100_000 },
        { section_id: 's4', start_ms: 100_000, end_ms: 130_000 },
        { section_id: 's2', start_ms: 130_000, end_ms: 160_000 },
      ],
    });
    if ('segments' in result) {
      expect(parseSegments(formatSegments(result.segments, sections), sections)).toEqual(result);
    }
    expect(parseSegments('  \n', sections)).toEqual({ segments: [] });
  });

  it('passages : erreurs explicites', () => {
    const error = (text: string) => {
      const r = parseSegments(text, sections);
      return 'error' in r ? r.error : null;
    };
    expect(error('0:00 Couplet\n1:00 fin')).toContain('ambiguë');
    expect(error('0:00 Couplet 1\n0:30 Refrain')).toContain('fin');
    expect(error('0:30 Couplet 1\n0:10 fin')).toContain('croissants');
    expect(error('0:00 Couplet 1\n0:30 fin\n0:40 Refrain')).toContain('« fin »');
    expect(error('Couplet 1')).toContain('m:ss');
  });

  it('aperçu : versions diffusées', () => {
    const html = renderToStaticMarkup(
      <HymnPreview
        hymn={PublishedHymn.parse({
          id: '00000000-0000-4000-8000-000000000001',
          numberLabel: '1',
          numberNumeric: 1,
          numberSuffix: null,
          title: 'Titre',
          openingLine: null,
          languageCode: 'fr',
          sections: [
            {
              id: '00000000-0000-4000-8000-000000000003',
              type: 'verse',
              number: 1,
              order: 0,
              lines: [{ text: 'Premier vers', repeat: null }],
            },
          ],
          bibleReferences: [],
          relations: [],
          people: [],
          themes: [],
          audio: [
            {
              id: '00000000-0000-4000-8000-0000000a0001',
              mediaType: 'choir',
              storageKey: 'cantiques/0001/chorale.mp3',
              durationSeconds: null,
              segments: [],
            },
          ],
        })}
      />,
    );
    expect(html).toContain('Écouter : Chorale');
  });
});
