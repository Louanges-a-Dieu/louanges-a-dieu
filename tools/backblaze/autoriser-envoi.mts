/**
 * Autorise une seule fois le back-office à envoyer des fichiers dans le
 * compartiment audio (règle CORS « envoi-back-office », API native B2) :
 *
 *     node tools/backblaze/autoriser-envoi.mts [compartiment]
 *
 * La clé Backblaze est demandée au clavier (saisie masquée), utilisée pour
 * cet appel seulement, jamais enregistrée. Il faut une clé autorisée à
 * modifier les réglages du compartiment (« writeBuckets ») : si la clé du
 * back-office est refusée, en créer une temporaire « All buckets / Read and
 * Write », relancer, puis la supprimer. Les autres règles CORS du
 * compartiment sont conservées.
 */
import { createInterface } from 'node:readline/promises';
import { Writable } from 'node:stream';

const API = 'https://api.backblazeb2.com/b2api/v4';
const BUCKET = process.argv[2] ?? 'CantiquesEA';
const RULE = {
  corsRuleName: 'envoi-back-office',
  allowedOrigins: ['https://admin.louanges.eglisedabidjan.com', 'http://localhost:3001'],
  allowedOperations: ['b2_upload_file'],
  allowedHeaders: ['authorization', 'content-type', 'x-bz-file-name', 'x-bz-content-sha1'],
  exposeHeaders: [],
  maxAgeSeconds: 3600,
};

let muted = false;
const output = new Writable({
  write(chunk, _encoding, callback) {
    if (!muted) process.stdout.write(chunk);
    callback();
  },
});
const rl = createInterface({ input: process.stdin, output, terminal: true });

async function ask(question: string, hidden = false): Promise<string> {
  process.stdout.write(question);
  muted = hidden;
  const answer = await rl.question('');
  muted = false;
  if (hidden) process.stdout.write('\n');
  return answer.trim();
}

async function call<T>(url: string, init: RequestInit, refused?: string): Promise<T> {
  const res = await fetch(url, init);
  const body = (await res.json().catch(() => ({}))) as T & { code?: string; message?: string };
  if (!res.ok) {
    if (res.status === 401 && refused) throw new Error(refused);
    if (res.status === 401) {
      throw new Error(
        `clé refusée pour cette opération (${body.code ?? 401}). Il faut une clé avec ` +
          '« writeBuckets » : créer une clé temporaire « All buckets / Read and Write », relancer, puis la supprimer.',
      );
    }
    throw new Error(body.message ?? body.code ?? `erreur ${res.status}`);
  }
  return body;
}

interface Bucket {
  bucketId: string;
  bucketName: string;
  corsRules: { corsRuleName: string }[];
}

async function main() {
  console.log(`Compartiment : ${BUCKET}`);
  const keyId = await ask('Identifiant de la clé (keyID) : ');
  const key = await ask('Clé (applicationKey, saisie masquée) : ', true);
  rl.close();
  if (!keyId || !key) throw new Error('identifiant et clé requis.');

  const auth = await call<{
    accountId: string;
    authorizationToken: string;
    apiInfo: { storageApi: { apiUrl: string } };
  }>(
    `${API}/b2_authorize_account`,
    {
      headers: { Authorization: `Basic ${Buffer.from(`${keyId}:${key}`).toString('base64')}` },
    },
    'identifiant ou clé incorrects (vérifier keyID et applicationKey).',
  );
  const apiUrl = `${auth.apiInfo.storageApi.apiUrl}/b2api/v4`;
  const headers = { Authorization: auth.authorizationToken };

  const { buckets } = await call<{ buckets: Bucket[] }>(`${apiUrl}/b2_list_buckets`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ accountId: auth.accountId, bucketName: BUCKET }),
  });
  const bucket = buckets[0];
  if (!bucket) throw new Error(`compartiment « ${BUCKET} » introuvable avec cette clé.`);

  const others = (bucket.corsRules ?? []).filter((r) => r.corsRuleName !== RULE.corsRuleName);
  if (others.length) {
    console.log(`Règles conservées : ${others.map((r) => r.corsRuleName).join(', ')}`);
  }
  await call(`${apiUrl}/b2_update_bucket`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      accountId: auth.accountId,
      bucketId: bucket.bucketId,
      corsRules: [...others, RULE],
    }),
  });
  console.log(
    `Règle « ${RULE.corsRuleName} » enregistrée pour : ${RULE.allowedOrigins.join(', ')}.`,
  );

  // Vérification : le navigateur du back-office serait-il autorisé à envoyer ?
  const target = await call<{ uploadUrl: string }>(
    `${apiUrl}/b2_get_upload_url?bucketId=${encodeURIComponent(bucket.bucketId)}`,
    { headers },
  ).catch(() => null);
  if (!target) {
    console.log('(Vérification sautée : cette clé ne permet pas d’envoyer de fichier.)');
    return;
  }
  const preflight = await fetch(target.uploadUrl, {
    method: 'OPTIONS',
    headers: {
      Origin: RULE.allowedOrigins[0]!,
      'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': RULE.allowedHeaders.join(','),
    },
  });
  const allowed = preflight.headers.get('access-control-allow-origin');
  console.log(
    allowed
      ? `Vérifié : Backblaze accepte les envois depuis ${allowed}.`
      : `Attention : la vérification n’a pas confirmé l’autorisation (HTTP ${preflight.status}). ` +
          'Les règles CORS peuvent mettre quelques minutes à s’appliquer : réessayer plus tard.',
  );
}

main().catch((error: unknown) => {
  rl.close();
  console.error(`Échec : ${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
