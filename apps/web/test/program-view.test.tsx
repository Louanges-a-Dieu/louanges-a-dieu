import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';

import { ProgramView, UnavailableView } from '../src/app/programme/program-view';

describe('ProgramView', () => {
  it('affiche titre, date, numéros, titres, moments et notes — rien d’autre', () => {
    const html = renderToStaticMarkup(
      <ProgramView
        program={{
          title: 'Culte de Pâques',
          serviceDate: '2026-04-05',
          items: [
            { position: 0, label: 'Accueil', notes: null, hymn: null },
            {
              position: 1,
              label: null,
              notes: 'Couplets 1 et 3',
              hymn: { id: 'h1', numberLabel: '37 bis', title: 'Au matin' },
            },
            { position: 2, label: null, notes: null, hymn: { unavailable: true } },
          ],
        }}
      />,
    );
    expect(html).toContain('<h1');
    expect(html).toContain('Culte de Pâques');
    expect(html).toContain('dimanche 5 avril 2026');
    expect(html).toContain('Accueil');
    expect(html).toContain('37 bis');
    expect(html).toContain('Au matin');
    expect(html).toContain('Couplets 1 et 3');
    expect(html).toContain('Cantique retiré du recueil');
    expect(html.indexOf('Accueil')).toBeLessThan(html.indexOf('Au matin'));
    // L'identifiant interne du cantique n'est pas exposé.
    expect(html).not.toContain('h1"');
  });

  it('sans date ni élément : aucun champ vide affiché', () => {
    const html = renderToStaticMarkup(
      <ProgramView program={{ title: 'Culte', serviceDate: null, items: [] }} />,
    );
    expect(html).toContain('aucun élément');
    expect(html).not.toMatch(/<p[^>]*><\/p>/);
  });
});

describe('UnavailableView', () => {
  it('ne dit pas pourquoi le lien est inutilisable', () => {
    const html = renderToStaticMarkup(<UnavailableView />);
    expect(html).toContain('Programme indisponible');
  });
});
