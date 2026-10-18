import { describe, expect, it } from 'vitest';

import { scrubPath, scrubSentryEvent, serverErrorRecord } from '../src/index.ts';

describe('scrubPath', () => {
  it('retire le jeton d’un lien de programme et le code de projection', () => {
    expect(scrubPath('/programme/AbCdEfGhIjKlMnOpQrStUvWxYz012345')).toBe('/programme/[jeton]');
    expect(scrubPath('/s/k7mx2qpa/ws')).toBe('/s/[code]/ws');
  });

  it('masque les valeurs de la requête, garde les noms', () => {
    expect(scrubPath('/cantiques?q=jean.dupont@exemple.org&statut=draft&q=x')).toBe(
      '/cantiques?q=…&statut=…',
    );
    expect(scrubPath('/cantiques/1234')).toBe('/cantiques/1234');
  });
});

describe('serverErrorRecord', () => {
  it('produit un enregistrement JSON sans donnée personnelle', () => {
    const error = Object.assign(new Error('Aucun compte pour marie@exemple.org'), {
      digest: '123',
    });
    const record = serverErrorRecord(
      'admin',
      error,
      { path: '/programme/AbCdEfGhIjKlMnOpQrStUvWxYz012345?ref=x', method: 'GET' },
      { routePath: '/programme/[token]', routeType: 'render' },
      new Date('2026-10-18T10:00:00Z'),
    );
    expect(record).toEqual({
      level: 'error',
      app: 'admin',
      time: '2026-10-18T10:00:00.000Z',
      message: 'Aucun compte pour [adresse]',
      digest: '123',
      method: 'GET',
      path: '/programme/[jeton]?ref=…',
      route: '/programme/[token]',
      routeType: 'render',
    });
    expect(JSON.stringify(record)).not.toMatch(/marie|AbCdEf/);
  });
});

describe('scrubSentryEvent', () => {
  it('retire utilisateur, en-têtes, cookies, corps et jetons', () => {
    const event = scrubSentryEvent({
      user: { email: 'marie@exemple.org', ip_address: '1.2.3.4' },
      server_name: 'machine',
      request: {
        url: 'https://louanges.exemple.org/programme/AbCdEfGhIjKlMnOpQrStUvWxYz012345?x=1',
        headers: { cookie: 'sb-auth-token=secret' },
        cookies: { a: 'b' },
        data: { email: 'marie@exemple.org' },
        query_string: 'x=1',
      },
      exception: {
        values: [
          {
            value: 'Échec pour marie@exemple.org',
            stacktrace: {
              frames: [
                { vars: { email: 'marie@exemple.org' }, pre_context: ['x'], post_context: ['y'] },
              ],
            },
          },
        ],
      },
      breadcrumbs: [
        { message: 'GET /programme/AbCdEfGhIjKlMnOpQrStUvWxYz012345', data: { url: 'x' } },
      ],
    });
    expect(event).toEqual({
      request: { url: 'https://louanges.exemple.org/programme/[jeton]?x=…' },
      exception: { values: [{ value: 'Échec pour [adresse]', stacktrace: { frames: [{}] } }] },
      breadcrumbs: [{ message: 'GET /programme/[jeton]' }],
    });
  });
});
