/**
 * Lecture d'un programme partagé (ADR-012, Q-09) par la fonction publique
 * `get_shared_program`, seul point d'entrée côté serveur.
 *
 * Un jeton inconnu, désactivé, expiré ou dont le programme n'est plus publié
 * donne exactement le même résultat (`null`) : la page ne doit pas permettre
 * de distinguer ces cas.
 */

export type SharedHymn =
  { unavailable: true } | { unavailable?: false; id: string; numberLabel: string; title: string };

export interface SharedItem {
  position: number;
  /** Intitulé d'un moment libre (accueil, prière…), null pour un cantique. */
  label: string | null;
  notes: string | null;
  hymn: SharedHymn | null;
}

export interface SharedProgram {
  title: string;
  /** Date ISO `AAAA-MM-JJ`, ou null si le programme n'est pas daté. */
  serviceDate: string | null;
  items: SharedItem[];
}

export interface SupabaseConfig {
  url: string;
  publishableKey: string;
}

/** Erreur du service (réseau, serveur) : distincte d'un lien indisponible. */
export class SharedProgramServiceError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = 'SharedProgramServiceError';
  }
}

/** Même contrôle que la base : inutile d'interroger le serveur sinon. */
export function isPlausibleToken(token: string): boolean {
  return /^[A-Za-z0-9_-]{32,128}$/.test(token);
}

export function configFromEnv(
  env: Record<string, string | undefined> = process.env,
): SupabaseConfig {
  const url = env.SUPABASE_URL ?? '';
  const publishableKey = env.SUPABASE_PUBLISHABLE_KEY ?? '';
  if (!url || !publishableKey) {
    throw new SharedProgramServiceError('SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY sont requis');
  }
  return { url: url.replace(/\/+$/, ''), publishableKey };
}

const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v);
const optionalString = (v: unknown): string | null =>
  typeof v === 'string' && v !== '' ? v : null;

function parseHymn(v: unknown): SharedHymn | null {
  if (v === null || v === undefined) return null;
  if (!isObject(v)) throw new TypeError('cantique invalide');
  if (v.unavailable === true) return { unavailable: true };
  if (
    typeof v.id !== 'string' ||
    typeof v.numberLabel !== 'string' ||
    typeof v.title !== 'string'
  ) {
    throw new TypeError('cantique incomplet');
  }
  return { id: v.id, numberLabel: v.numberLabel, title: v.title };
}

/** Valide la réponse de `get_shared_program` (null = lien indisponible). */
export function parseSharedProgram(json: unknown): SharedProgram | null {
  if (json === null) return null;
  if (!isObject(json) || typeof json.title !== 'string' || !Array.isArray(json.items)) {
    throw new TypeError('programme invalide');
  }
  const items = json.items.map((raw): SharedItem => {
    if (!isObject(raw) || typeof raw.position !== 'number') throw new TypeError('élément invalide');
    return {
      position: raw.position,
      label: optionalString(raw.label),
      notes: optionalString(raw.notes),
      hymn: parseHymn(raw.hymn),
    };
  });
  return {
    title: json.title,
    serviceDate: optionalString(json.serviceDate),
    items: items.sort((a, b) => a.position - b.position),
  };
}

export async function fetchSharedProgram(
  token: string,
  config: SupabaseConfig,
  fetchImpl: typeof fetch = fetch,
): Promise<SharedProgram | null> {
  if (!isPlausibleToken(token)) return null;
  let response: Response;
  try {
    response = await fetchImpl(`${config.url}/rest/v1/rpc/get_shared_program`, {
      method: 'POST',
      headers: {
        apikey: config.publishableKey,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({ p_token: token }),
      cache: 'no-store',
      signal: AbortSignal.timeout(10_000),
    });
  } catch (error) {
    throw new SharedProgramServiceError('Service injoignable', { cause: error });
  }
  if (!response.ok) {
    throw new SharedProgramServiceError(`Réponse ${response.status} du service`);
  }
  try {
    return parseSharedProgram(await response.json());
  } catch (error) {
    throw new SharedProgramServiceError('Réponse illisible', { cause: error });
  }
}

/** « dimanche 12 avril 2026 » ; la date est un jour civil, sans fuseau. */
export function formatServiceDate(isoDate: string): string | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(isoDate);
  if (!match) return null;
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  return new Intl.DateTimeFormat('fr-FR', { dateStyle: 'full', timeZone: 'UTC' }).format(date);
}

/**
 * Programme d'un lien pour la page publique : le programme, `null` (lien
 * indisponible) ou `'service-error'` (configuration absente, réseau, serveur).
 * Aucune erreur ne s'échappe : la page affiche toujours un message clair.
 */
export async function loadSharedProgram(
  token: string,
  env: Record<string, string | undefined> = process.env,
  fetchImpl: typeof fetch = fetch,
): Promise<SharedProgram | null | 'service-error'> {
  try {
    return await fetchSharedProgram(token, configFromEnv(env), fetchImpl);
  } catch (error) {
    if (error instanceof SharedProgramServiceError) return 'service-error';
    throw error;
  }
}
