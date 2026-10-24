/**
 * Envoi d'un enregistrement depuis la fiche (navigateur réel), contre un faux
 * Backblaze : API locale (B2_API_URL) et envoi du navigateur intercepté par
 * DevTools. Vérifie l'empreinte SHA-1, le chemin choisi, la durée lue sur le
 * fichier et le rattachement en base. Aucun fichier n'est envoyé ; la piste
 * créée est supprimée à la fin.
 */
import { type ChildProcess, spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { createServer, type Server } from 'node:http';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

import { createServerClient } from '@supabase/ssr';
import pg from 'pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { connectionConfig } from '../../../packages/content_tools/src/db.ts';
import { Chrome, chromePath, freePort, sleep, type Page } from '../../../tools/e2e/cdp';
import { totp } from '../../../tools/pgtap/test-users.ts';

const admin = resolve(import.meta.dirname, '..');
const repo = resolve(admin, '../..');
const editorFile = resolve(admin, 'e2e/.test-editor.json');
const envFile = resolve(admin, '.env.local');
const ready =
  !!chromePath &&
  existsSync(envFile) &&
  existsSync(editorFile) &&
  existsSync(resolve(admin, '.next/BUILD_ID')) &&
  !!(process.env.DATABASE_URL ?? process.env.SUPABASE_DB_PASSWORD);

const env: Record<string, string> = ready
  ? Object.fromEntries(
      readFileSync(envFile, 'utf8')
        .split('\n')
        .filter((l) => l.includes('='))
        .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).trim()]),
    )
  : {};

const UPLOAD_URL = 'https://pod-000-0000-00.backblaze.com/b2api/v4/b2_upload_file/bkt/essai';

/** MP3 muet d'environ 2,6 s : 100 trames MPEG-1 couche III, 128 kb/s, 44,1 kHz. */
function silentMp3(): Buffer {
  const frame = Buffer.alloc(417);
  frame.writeUInt32BE(0xfffb9000, 0);
  return Buffer.concat(Array.from({ length: 100 }, () => frame));
}

/** Faux Backblaze : autorisation et adresse d'envoi. */
function fakeB2(port: number): Server {
  return createServer((req, res) => {
    const url = new URL(req.url ?? '/', `http://127.0.0.1:${port}`);
    const send = (status: number, body: unknown) => {
      res.writeHead(status, { 'content-type': 'application/json' });
      res.end(JSON.stringify(body));
    };
    if (url.pathname === '/b2api/v4/b2_authorize_account') {
      const expected = `Basic ${Buffer.from('faux-id:fausse-cle').toString('base64')}`;
      if (req.headers.authorization !== expected) return send(401, { code: 'unauthorized' });
      return send(200, {
        accountId: 'compte',
        authorizationToken: 'jeton-api',
        apiInfo: {
          storageApi: {
            apiUrl: `http://127.0.0.1:${port}`,
            allowed: { buckets: [{ id: 'bkt', name: 'lad' }], capabilities: ['writeFiles'] },
          },
        },
      });
    }
    if (url.pathname === '/b2api/v4/b2_get_upload_url') {
      if (req.headers.authorization !== 'jeton-api' || url.searchParams.get('bucketId') !== 'bkt') {
        return send(401, { code: 'unauthorized' });
      }
      return send(200, { uploadUrl: UPLOAD_URL, authorizationToken: 'jeton-envoi' });
    }
    send(404, { code: 'not_found' });
  });
}

describe.skipIf(!ready)('enregistrements : envoi depuis la fiche (navigateur réel)', () => {
  let chrome: Chrome;
  let server: ChildProcess;
  let b2: Server;
  let base: string;
  let page: Page;
  let db: pg.Client;
  let hymnId: string;

  beforeAll(async () => {
    db = new pg.Client(connectionConfig(repo));
    await db.connect();
    const { rows } = await db.query<{ id: string }>(
      `select h.id from public.hymns h
        where not exists (select 1 from public.audio_tracks t where t.hymn_id = h.id)
        order by h.number_numeric desc limit 1`,
    );
    hymnId = rows[0]!.id;

    const b2Port = await freePort();
    b2 = fakeB2(b2Port);
    await new Promise<void>((r) => b2.listen(b2Port, '127.0.0.1', r));
    const port = await freePort();
    base = `http://127.0.0.1:${port}`;
    server = spawn(resolve(admin, 'node_modules/.bin/next'), ['start', '-p', String(port)], {
      cwd: admin,
      env: {
        ...process.env,
        NODE_ENV: 'production',
        AUDIO_BASE_URL: 'https://media.invalid/file/lad',
        B2_API_URL: `http://127.0.0.1:${b2Port}/b2api/v4`,
        B2_KEY_ID: 'faux-id',
        B2_APPLICATION_KEY: 'fausse-cle',
      },
      stdio: 'ignore',
    });
    for (let i = 0; i < 150; i++) {
      try {
        await fetch(`${base}/connexion`);
        break;
      } catch {
        await sleep(100);
      }
    }
    chrome = await Chrome.launch();
    page = await chrome.newPage();
  });

  afterAll(async () => {
    await db
      ?.query(
        `delete from public.audio_tracks where hymn_id = $1 and storage_key like 'cantiques/%'`,
        [hymnId],
      )
      .catch(() => {});
    await db?.end();
    server?.kill();
    b2?.close();
    await chrome?.close();
  });

  it('choisir un fichier, l’envoyer et le rattacher au cantique', async () => {
    const editor = JSON.parse(readFileSync(editorFile, 'utf8')) as {
      email: string;
      password: string;
      totpSecret: string;
    };
    const jar = new Map<string, string>();
    const supabase = createServerClient(env.SUPABASE_URL!, env.SUPABASE_PUBLISHABLE_KEY!, {
      cookies: {
        getAll: () => [...jar].map(([name, value]) => ({ name, value })),
        setAll: (list) => list.forEach((c) => jar.set(c.name, c.value)),
      },
    });
    const { error } = await supabase.auth.signInWithPassword(editor);
    if (error) throw error;
    for (const [name, value] of jar) {
      await page.send('Network.setCookie', { name, value, url: base, sameSite: 'Lax' });
    }
    await page.goto(`${base}/cantiques/${hymnId}`);
    await page.waitFor("!!document.querySelector('input[name=code]')");
    await page.eval(`(() => {
      const el = document.querySelector('input[name=code]');
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(el, ${JSON.stringify(totp(editor.totpSecret))});
      el.dispatchEvent(new Event('input', { bubbles: true }));
      [...document.querySelectorAll('button')].find(b => b.textContent.includes('Vérifier')).click();
    })()`);
    await page.waitFor(
      "!location.pathname.startsWith('/connexion') && !!document.querySelector('h1')",
      30_000,
    );

    // Envoi du navigateur vers « Backblaze » intercepté (préliminaire CORS compris).
    const mp3 = silentMp3();
    const sha1 = createHash('sha1').update(mp3).digest('hex');
    const uploads: Record<string, string>[] = [];
    await page.send('Fetch.enable', { patterns: [{ urlPattern: 'https://pod-*' }] });
    let handled = page.events.length;
    const interceptor = setInterval(() => {
      for (; handled < page.events.length; handled++) {
        const { method, params } = page.events[handled]!;
        if (method !== 'Fetch.requestPaused') continue;
        const request = params.request as { method: string; headers: Record<string, string> };
        const cors = [
          { name: 'Access-Control-Allow-Origin', value: base },
          { name: 'Access-Control-Allow-Methods', value: 'POST' },
          {
            name: 'Access-Control-Allow-Headers',
            value: 'authorization,content-type,x-bz-file-name,x-bz-content-sha1',
          },
        ];
        if (request.method === 'POST') uploads.push(request.headers);
        void page.send('Fetch.fulfillRequest', {
          requestId: params.requestId,
          responseCode: request.method === 'OPTIONS' ? 204 : 200,
          responseHeaders: [...cors, { name: 'Content-Type', value: 'application/json' }],
          body: Buffer.from(request.method === 'OPTIONS' ? '' : '{"fileId":"f"}').toString(
            'base64',
          ),
        });
      }
    }, 20);

    try {
      await page.goto(`${base}/cantiques/${hymnId}`);
      // Attendre l'hydratation : un changement de fichier antérieur serait perdu.
      await page.waitFor(
        "Object.keys(document.querySelector('input[type=file]') ?? {}).some(k => k.startsWith('__reactProps'))",
        30_000,
      );
      const dir = mkdtempSync(join(tmpdir(), 'lad-audio-'));
      const file = join(dir, 'Essai Chant.MP3');
      writeFileSync(file, mp3);
      const input = await page.send('Runtime.evaluate', {
        expression: "document.querySelector('input[type=file]')",
      });
      const objectId = (input.result as { result: { objectId: string } }).result.objectId;
      await page.send('DOM.setFileInputFiles', { files: [file], objectId });

      // Durée lue sur le fichier (≈ 2,6 s).
      await page.waitFor(
        "[...document.querySelectorAll('input')].some(i => /^0:0[23]$/.test(i.value))",
      );
      await page.eval(
        "[...document.querySelectorAll('button')].find(b => b.textContent.includes('Envoyer et ajouter')).click()",
      );
      await page.waitFor("document.body.innerText.includes('Enregistrement ajouté.')", 30_000);
    } finally {
      clearInterval(interceptor);
    }

    expect(uploads).toHaveLength(1);
    const headers = Object.fromEntries(
      Object.entries(uploads[0]!).map(([k, v]) => [k.toLowerCase(), v]),
    );
    expect(headers.authorization).toBe('jeton-envoi');
    expect(headers['x-bz-content-sha1']).toBe(sha1);
    expect(headers['content-type']).toBe('audio/mpeg');
    expect(headers['x-bz-file-name']).toMatch(/^cantiques\/\d{4}[a-z0-9]*\/melodie\.mp3$/);

    const { rows } = await db.query<{ storage_key: string; duration_seconds: string }>(
      'select storage_key, duration_seconds from public.audio_tracks where hymn_id = $1',
      [hymnId],
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]!.storage_key).toBe(headers['x-bz-file-name']);
    expect(Number(rows[0]!.duration_seconds)).toBeGreaterThanOrEqual(2);
    expect(
      await page.eval(`document.body.innerText.includes(${JSON.stringify(rows[0]!.storage_key)})`),
    ).toBe(true);
  });
});
