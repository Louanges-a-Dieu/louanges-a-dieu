/**
 * Observabilité sans données personnelles (10.5, Q-16).
 *
 * - Jetons et codes d'accès retirés des chemins (liens de programme partagé,
 *   code de session de projection) ; valeurs de recherche masquées.
 * - Jamais d'utilisateur, de cookie, d'en-tête ni de corps de requête.
 */

const SECRET_SEGMENTS: Array<[RegExp, string]> = [
  [/^(\/programme\/)[^/?#]+/, '$1[jeton]'],
  [/^(\/s\/)[^/?#]+/, '$1[code]'],
];

/** Chemin sans secret : segments sensibles remplacés, valeurs de la requête masquées. */
export function scrubPath(path: string): string {
  const [pathname = '', query] = path.split('?', 2);
  let clean = pathname;
  for (const [pattern, replacement] of SECRET_SEGMENTS) clean = clean.replace(pattern, replacement);
  if (!query) return clean;
  const keys = [...new URLSearchParams(query).keys()];
  return `${clean}?${[...new Set(keys)].map((k) => `${encodeURIComponent(k)}=…`).join('&')}`;
}

export interface ServerErrorRecord {
  level: 'error';
  app: string;
  time: string;
  message: string;
  digest?: string;
  method?: string;
  path?: string;
  route?: string;
  routeType?: string;
}

/** Enregistrement JSON d'une erreur serveur (les journaux de l'hébergeur le conservent). */
export function serverErrorRecord(
  app: string,
  error: unknown,
  request?: { path?: string; method?: string },
  context?: { routePath?: string; routeType?: string },
  now = new Date(),
): ServerErrorRecord {
  const message = (error instanceof Error ? error.message : String(error)).slice(0, 500);
  const digest =
    typeof error === 'object' && error !== null && 'digest' in error
      ? String((error as { digest: unknown }).digest)
      : undefined;
  return {
    level: 'error',
    app,
    time: now.toISOString(),
    message: scrubText(message),
    ...(digest ? { digest } : {}),
    ...(request?.method ? { method: request.method } : {}),
    ...(request?.path ? { path: scrubPath(request.path) } : {}),
    ...(context?.routePath ? { route: context.routePath } : {}),
    ...(context?.routeType ? { routeType: context.routeType } : {}),
  };
}

/** Adresses e-mail et jetons longs retirés d'un texte libre (message d'erreur). */
export function scrubText(text: string): string {
  return text
    .replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '[adresse]')
    .replace(/\/programme\/[^\s/?#'"]+/g, '/programme/[jeton]')
    .replace(/\b[A-Za-z0-9_-]{32,}\b/g, '[jeton]');
}

/** Événement Sentry minimal (sous-ensemble utile du type du SDK). */
export interface ScrubbableEvent {
  user?: unknown;
  server_name?: string;
  message?: string;
  request?: {
    url?: string;
    headers?: unknown;
    cookies?: unknown;
    data?: unknown;
    query_string?: unknown;
    env?: unknown;
  };
  exception?: {
    values?: Array<{
      value?: string;
      stacktrace?: {
        frames?: Array<{ vars?: unknown; pre_context?: unknown; post_context?: unknown }>;
      };
    }>;
  };
  breadcrumbs?: Array<{ data?: Record<string, unknown>; message?: string }>;
}

/** Filtre `beforeSend` : rien qui permette d'identifier une personne ou d'ouvrir un lien. */
export function scrubSentryEvent<T extends ScrubbableEvent>(event: T): T {
  delete event.user;
  delete event.server_name;
  if (event.message) event.message = scrubText(event.message);
  if (event.request) {
    const url = event.request.url;
    event.request = {};
    if (url) {
      try {
        const parsed = new URL(url);
        event.request.url = `${parsed.origin}${scrubPath(parsed.pathname + parsed.search)}`;
      } catch {
        event.request.url = scrubPath(url);
      }
    }
  }
  for (const value of event.exception?.values ?? []) {
    if (value.value) value.value = scrubText(value.value);
    // Valeurs des variables et lignes voisines : peuvent contenir des données.
    for (const frame of value.stacktrace?.frames ?? []) {
      delete frame.vars;
      delete frame.pre_context;
      delete frame.post_context;
    }
  }
  for (const crumb of event.breadcrumbs ?? []) {
    delete crumb.data;
    if (crumb.message) crumb.message = scrubText(crumb.message);
  }
  return event;
}
