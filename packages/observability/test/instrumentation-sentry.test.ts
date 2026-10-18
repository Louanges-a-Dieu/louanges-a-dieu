import { createServer, type Server } from 'node:http';
import { gunzipSync, inflateSync } from 'node:zlib';

import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';

/**
 * Observabilité serveur avec le VRAI SDK Sentry (fichier séparé : registre de modules neuf), envoyant à un faux serveur
 * Sentry local : vérifie que rien d'identifiant ne part (10.5).
 */
const received: string[] = [];
let server: Server;
let port = 0;

// Construit hors de la ligne fautive : la pile d'appels ne cite que cette ligne.
const MESSAGE = ['Échec pour marie', 'exemple.org'].join('@');
const error = () => Object.assign(new Error(MESSAGE), { digest: '42' });
const request = {
  path: '/programme/AbCdEfGhIjKlMnOpQrStUvWxYz012345?ref=lettre',
  method: 'GET',
  headers: { cookie: 'sb-auth-token=secret-de-session', authorization: 'Bearer jeton-secret' },
};
const context = {
  routerKind: 'App Router' as const,
  routePath: '/programme/[token]',
  routeType: 'render' as const,
  renderSource: 'server-rendering' as const,
  revalidateReason: undefined,
  renderType: 'dynamic' as const,
};

beforeAll(async () => {
  server = createServer((req, res) => {
    const chunks: Buffer[] = [];
    req.on('data', (c: Buffer) => chunks.push(c));
    req.on('end', () => {
      const body = Buffer.concat(chunks);
      const encoding = String(req.headers['content-encoding'] ?? '');
      let text = body.toString();
      try {
        if (encoding.includes('gzip')) text = gunzipSync(body).toString();
        else if (encoding.includes('deflate')) text = inflateSync(body).toString();
      } catch {
        text = `[corps illisible : ${encoding}]`;
      }
      received.push(text);
      res.writeHead(200, { 'Content-Type': 'application/json' }).end('{}');
    });
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  port = (server.address() as { port: number }).port;
});

afterAll(() => {
  server.close();
  vi.unstubAllEnvs();
});

describe('instrumentation serveur, avec Sentry', () => {
  it('avec SENTRY_DSN : l’erreur part, filtrée', async () => {
    vi.stubEnv('NEXT_RUNTIME', 'nodejs');
    vi.stubEnv('SENTRY_DSN', `http://clepublique@127.0.0.1:${port}/1`);
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const { onRequestError, register } = await import('./instrumentation-fixture.ts');
    await register();
    await onRequestError(error(), request, context);
    await vi.waitFor(() => expect(received.length).toBeGreaterThan(0), { timeout: 5000 });
    const sent = received.join('\n');
    expect(sent).toContain('Échec pour [adresse]');
    expect(sent).toContain('/programme/[jeton]');
    expect(sent).not.toMatch(/marie@|AbCdEfGhIjKl|secret-de-session|jeton-secret|Bearer/);
  }, 20_000);
});
