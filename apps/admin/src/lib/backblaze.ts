/**
 * Dépôt des enregistrements sur Backblaze B2 depuis le back-office (API
 * native v4). Le fichier ne passe pas par le serveur (limite de 4,5 Mo des
 * fonctions Vercel) : le serveur obtient une adresse d'envoi à usage limité
 * (24 h), le navigateur y envoie le fichier directement. Exception assumée à
 * ADR-011 : la clé d'application B2 (restreinte au compartiment audio) reste
 * côté serveur et n'est jamais transmise au navigateur.
 */

/** API Backblaze ; B2_API_URL ne sert qu'aux tests de bout en bout (faux Backblaze local). */
const api = () => process.env.B2_API_URL || 'https://api.backblazeb2.com/b2api/v4';

export interface B2Config {
  keyId: string;
  applicationKey: string;
  bucket: string;
}

/** Nom du compartiment : B2_BUCKET, sinon tiré de AUDIO_BASE_URL (…/file/<compartiment>). */
export function bucketName(): string | null {
  const explicit = (process.env.B2_BUCKET ?? '').trim();
  if (explicit) return explicit;
  const m = /\/file\/([^/]+)\/?$/.exec(process.env.AUDIO_BASE_URL ?? '');
  return m ? decodeURIComponent(m[1]!) : null;
}

/** Configuration du dépôt, ou null si la clé B2 n'est pas configurée. */
export function b2Config(): B2Config | null {
  const keyId = (process.env.B2_KEY_ID ?? '').trim();
  const applicationKey = (process.env.B2_APPLICATION_KEY ?? '').trim();
  const bucket = bucketName();
  if (!keyId || !applicationKey || !bucket) return null;
  return { keyId, applicationKey, bucket };
}

class B2Error extends Error {}

async function call<T>(url: string, init: RequestInit): Promise<T> {
  let res: Response;
  try {
    res = await fetch(url, { ...init, cache: 'no-store', signal: AbortSignal.timeout(15_000) });
  } catch {
    throw new B2Error('Backblaze ne répond pas. Réessayer dans un instant.');
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { code?: string; message?: string };
    if (res.status === 401) {
      throw new B2Error('Clé Backblaze refusée (B2_KEY_ID / B2_APPLICATION_KEY).');
    }
    throw new B2Error(`Backblaze : ${body.message ?? body.code ?? `erreur ${res.status}`}.`);
  }
  return (await res.json()) as T;
}

interface Authorization {
  accountId: string;
  authorizationToken: string;
  apiInfo: {
    storageApi: {
      apiUrl: string;
      allowed: { buckets: { id: string; name: string | null }[] | null; capabilities: string[] };
    };
  };
}

/** Adresse d'envoi d'un fichier dans le compartiment (valable 24 h). */
export async function uploadTarget(
  config: B2Config,
): Promise<{ uploadUrl: string; authorizationToken: string }> {
  const basic = Buffer.from(`${config.keyId}:${config.applicationKey}`).toString('base64');
  const auth = await call<Authorization>(`${api()}/b2_authorize_account`, {
    headers: { Authorization: `Basic ${basic}` },
  });
  const storage = auth.apiInfo.storageApi;
  if (!storage.allowed.capabilities.includes('writeFiles')) {
    throw new B2Error('La clé Backblaze ne permet pas d’écrire (accès « Read and Write » requis).');
  }
  let bucketId = storage.allowed.buckets?.find((b) => b.name === config.bucket)?.id;
  if (!bucketId) {
    const { buckets } = await call<{ buckets: { bucketId: string }[] }>(
      `${storage.apiUrl}/b2api/v4/b2_list_buckets`,
      {
        method: 'POST',
        headers: { Authorization: auth.authorizationToken },
        body: JSON.stringify({ accountId: auth.accountId, bucketName: config.bucket }),
      },
    );
    bucketId = buckets[0]?.bucketId;
  }
  if (!bucketId) {
    throw new B2Error(`Compartiment « ${config.bucket} » inaccessible avec cette clé Backblaze.`);
  }
  const target = await call<{ uploadUrl: string; authorizationToken: string }>(
    `${storage.apiUrl}/b2api/v4/b2_get_upload_url?bucketId=${encodeURIComponent(bucketId)}`,
    { headers: { Authorization: auth.authorizationToken } },
  );
  return { uploadUrl: target.uploadUrl, authorizationToken: target.authorizationToken };
}

/** Message lisible d'une erreur de dépôt. */
export function b2ErrorMessage(error: unknown): string {
  return error instanceof B2Error ? error.message : 'Préparation de l’envoi impossible.';
}

/**
 * Le fichier existe-t-il à cette adresse publique ? null si on ne peut pas
 * le savoir (réseau) : l'appelant ne bloque alors pas.
 */
export async function fileExists(url: string): Promise<boolean | null> {
  try {
    const res = await fetch(url, {
      method: 'HEAD',
      cache: 'no-store',
      signal: AbortSignal.timeout(8_000),
    });
    if (res.ok) return true;
    if (res.status === 404) return false;
    return null;
  } catch {
    return null;
  }
}
