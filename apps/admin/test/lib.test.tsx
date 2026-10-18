import { PublishedHymn } from '@lad/shared-contracts';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import { HymnPreview } from '../src/components/hymn-preview';
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
