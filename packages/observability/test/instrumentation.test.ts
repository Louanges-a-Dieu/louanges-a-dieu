import { afterAll, describe, expect, it, vi } from 'vitest';

/**
 * Observabilité serveur sans Sentry (10.5) : journal JSON sans donnée
 * personnelle, aucun envoi. Le cas avec Sentry est dans instrumentation-sentry.test.ts.
 */

const error = () => Object.assign(new Error('Échec pour marie@exemple.org'), { digest: '42' });
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

afterAll(() => vi.unstubAllEnvs());

describe('instrumentation serveur, sans Sentry', () => {
  it('sans SENTRY_DSN : journal JSON sans donnée personnelle', async () => {
    vi.stubEnv('NEXT_RUNTIME', 'nodejs');
    vi.stubEnv('SENTRY_DSN', '');
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    const { onRequestError, register } = await import('./instrumentation-fixture.ts');
    await register();
    await onRequestError(error(), request, context);
    const record = JSON.parse(String(log.mock.calls[0]![0])) as Record<string, string>;
    expect(record).toMatchObject({
      level: 'error',
      app: 'test',
      message: 'Échec pour [adresse]',
      path: '/programme/[jeton]?ref=…',
      digest: '42',
    });
    expect(JSON.stringify(record)).not.toMatch(/marie|AbCdEf|secret|Bearer/);
    log.mockRestore();
  });
});
