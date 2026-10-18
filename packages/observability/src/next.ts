import { scrubPath, scrubSentryEvent, serverErrorRecord } from './index.ts';

/** Paramètres de `onRequestError` (Next.js 16), réduits à ce qui est utilisé. */
type RequestInfo = {
  path: string;
  method: string;
  headers: Record<string, string | string[] | undefined>;
};
type ContextInfo = { routePath?: string; routeType?: string } & Record<string, unknown>;

/**
 * Instrumentation serveur Next.js (10.5, Q-16) : chaque erreur est journalisée
 * en JSON sans donnée personnelle (journaux de l'hébergeur) et, si
 * `SENTRY_DSN` est défini, envoyée à Sentry après filtrage. Aucun suivi côté
 * navigateur : les CSP restent fermées à toute origine externe.
 */
export function nextInstrumentation(app: string) {
  const enabled = () => process.env.NEXT_RUNTIME === 'nodejs' && !!process.env.SENTRY_DSN;

  async function register() {
    if (!enabled()) return;
    const Sentry = await import('@sentry/nextjs');
    Sentry.init({
      dsn: process.env.SENTRY_DSN,
      environment: process.env.APP_ENV ?? 'production',
      sendDefaultPii: false,
      // Jamais les valeurs des variables locales (jetons, adresses…).
      includeLocalVariables: false,
      tracesSampleRate: 0,
      beforeSend: (event) => scrubSentryEvent(event),
    });
  }

  async function onRequestError(error: unknown, request: RequestInfo, context: ContextInfo) {
    console.error(JSON.stringify(serverErrorRecord(app, error, request, context)));
    if (!enabled()) return;
    const Sentry = await import('@sentry/nextjs');
    Sentry.captureRequestError(
      error,
      { ...request, path: scrubPath(request.path), headers: {} },
      context as Parameters<typeof Sentry.captureRequestError>[2],
    );
    await Sentry.flush(2000);
  }

  return { register, onRequestError };
}
