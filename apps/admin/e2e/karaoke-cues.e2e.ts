/**
 * Ajustement d'une synchronisation karaoké existante (navigateur réel) :
 * connexion avec second facteur, ouverture d'un enregistrement déjà
 * synchronisé, modification d'un temps, contrôle d'un chevauchement.
 * N'enregistre RIEN : la synchronisation réelle reste intacte. Ignoré s'il
 * n'existe aucun enregistrement synchronisé vers par vers.
 */
import { type ChildProcess, spawn } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

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

/** Un cantique dont un enregistrement est synchronisé vers par vers. */
async function syncedHymn(): Promise<{ hymnId: string; cues: number } | null> {
  const client = new pg.Client(connectionConfig(repo));
  await client.connect();
  try {
    const { rows } = await client.query<{ hymn_id: string; cues: string }>(
      `select t.hymn_id, count(*) as cues
         from public.audio_tracks t
         join public.audio_segments s on s.audio_track_id = t.id
        where s.line_index is not null
        group by t.id, t.hymn_id
        order by count(*) desc
        limit 1`,
    );
    return rows[0] ? { hymnId: rows[0].hymn_id, cues: Number(rows[0].cues) } : null;
  } finally {
    await client.end();
  }
}

describe.skipIf(!ready)('karaoké : ajuster la synchronisation (navigateur réel)', () => {
  let chrome: Chrome;
  let server: ChildProcess;
  let base: string;
  let page: Page;
  let target: { hymnId: string; cues: number } | null;

  beforeAll(async () => {
    target = await syncedHymn();
    const port = await freePort();
    base = `http://127.0.0.1:${port}`;
    server = spawn(resolve(admin, 'node_modules/.bin/next'), ['start', '-p', String(port)], {
      cwd: admin,
      env: { ...process.env, NODE_ENV: 'production', AUDIO_BASE_URL: 'https://media.invalid/lad' },
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
    server?.kill();
    await chrome?.close();
  });

  it('modifier un temps, signaler un chevauchement, sans rien enregistrer', async (ctx) => {
    if (!target) ctx.skip();
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
    await page.goto(`${base}/cantiques/${target!.hymnId}`);
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

    await page.goto(`${base}/cantiques/${target!.hymnId}`);
    await page.waitFor(
      "[...document.querySelectorAll('summary')].some(s => s.textContent.includes('ajuster le début'))",
      30_000,
    );
    await page.eval(
      "[...document.querySelectorAll('summary')].find(s => s.textContent.includes('ajuster le début')).click()",
    );
    const inputs = "document.querySelectorAll('details[open] ol li input')";
    await page.waitFor(`${inputs}.length === ${target!.cues * 2}`);
    expect(await page.eval("document.body.innerText.includes('Aucune modification.')")).toBe(true);

    // ↑ sur le début du 2ᵉ vers : +0,1 s.
    const before = await page.eval<string>(`${inputs}[2].value`);
    await page.eval(`(() => {
      const i = ${inputs}[2];
      i.focus();
      i.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true }));
    })()`);
    await page.waitFor("document.body.innerText.includes('Modifications non enregistrées.')");
    expect(await page.eval<string>(`${inputs}[2].value`)).not.toBe(before);

    // Début du 2ᵉ vers ramené avant le début du 1ᵉʳ : chevauchement signalé,
    // enregistrement impossible.
    await page.eval(`(() => {
      const i = ${inputs}[2];
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(i, '0:00.0');
      i.dispatchEvent(new Event('input', { bubbles: true }));
      i.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    })()`);
    await page.waitFor(
      "document.body.innerText.includes('commence avant la fin du vers précédent')",
    );
    expect(
      await page.eval(
        "[...document.querySelectorAll('button')].find(b => b.textContent.includes('Enregistrer les ajustements')).disabled",
      ),
    ).toBe(true);

    if (process.env.ADMIN_SHOT) {
      await page.eval(`${inputs}[0].scrollIntoView({ block: 'center' })`);
      await page.waitFor("document.fonts.status === 'loaded'");
      await sleep(300);
      const shot = await page.send('Page.captureScreenshot', { format: 'png' });
      writeFileSync(
        `${process.env.ADMIN_SHOT}-ajuster-karaoke.png`,
        Buffer.from((shot.result as { data: string }).data, 'base64'),
      );
    }

    // Annuler : retour aux temps enregistrés.
    await page.eval(
      "[...document.querySelectorAll('button')].find(b => b.textContent.includes('Annuler les modifications')).click()",
    );
    await page.waitFor("document.body.innerText.includes('Aucune modification.')");
  });
});
