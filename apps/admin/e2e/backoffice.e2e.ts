/**
 * Parcours administrateur de bout en bout (9.13), dans un VRAI Chrome contre
 * la base de DÉVELOPPEMENT : connexion (session sans second facteur → page
 * MFA → code TOTP), import d'une édition de test, validation par lots,
 * publication, T-009 (modification d'un cantique publié : brouillon, version
 * publique inchangée), anomalie ignorée avec justification, retour arrière,
 * journal, équipe ; CSP sans violation. L'édition de test est supprimée à la fin.
 *
 * Prérequis : `pnpm build`, Chrome, apps/admin/.env.local, accès base
 * (fichier de secrets « supabase.env » chargé), compte de test créé par
 * `node tools/pgtap/create-test-editor.ts`.
 */
import { spawn, type ChildProcess } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

import { createServerClient } from '@supabase/ssr';
import pg from 'pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { connectionConfig } from '../../../packages/content_tools/src/db.ts';
import {
  acceptDialogs,
  Chrome,
  chromePath,
  freePort,
  sleep,
  type Page,
} from '../../../tools/e2e/cdp';
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

const env = ready
  ? Object.fromEntries(
      readFileSync(envFile, 'utf8')
        .split('\n')
        .filter((l) => l.includes('='))
        .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).trim()]),
    )
  : {};

const editionName = `Édition E2E ${randomUUID().slice(0, 8)}`;

function draftFile(): string {
  const sha = 'e'.repeat(64);
  const draft = {
    format: 'lad.catalog-draft',
    version: 1,
    source: { filename: 'e2e.docx', sha256: sha, parserVersion: 'e2e' },
    edition: { name: editionName, editionNumber: null },
    hymns: [
      {
        numberLabel: '1',
        numberNumeric: 1,
        numberSuffix: null,
        title: 'Premier cantique E2E',
        openingLine: 'Premier vers E2E',
        sourceParagraphStart: 1,
        sourceParagraphEnd: 2,
        sections: [
          { type: 'verse', order: 0, text: 'Premier vers E2E\nDeuxième vers (bis)' },
          { type: 'refrain', order: 1, text: 'Refrain E2E' },
        ],
        bibleReferences: [],
        relations: [],
      },
      {
        numberLabel: '2',
        numberNumeric: 2,
        numberSuffix: null,
        title: 'Second cantique E2E',
        openingLine: null,
        sourceParagraphStart: 3,
        sourceParagraphEnd: 4,
        sections: [{ type: 'verse', order: 0, text: 'Unique strophe E2E' }],
        bibleReferences: [],
        relations: [],
      },
    ],
    issues: [
      {
        code: 'A-11',
        severity: 'warning',
        numberLabel: '2',
        message: 'Anomalie de test E2E',
        details: {},
      },
    ],
  };
  const dir = mkdtempSync(join(tmpdir(), 'lad-e2e-'));
  const file = join(dir, 'catalog.draft.json');
  writeFileSync(file, JSON.stringify(draft));
  return file;
}

async function startServer(port: number): Promise<ChildProcess> {
  const child = spawn(resolve(admin, 'node_modules/.bin/next'), ['start', '-p', String(port)], {
    cwd: admin,
    // Next ne lit pas .env.local quand NODE_ENV vaut « test » (cas de Vitest).
    // Hébergement des enregistrements fictif : seul l'élément <audio> (sans
    // préchargement) en dépend.
    env: { ...process.env, NODE_ENV: 'production', AUDIO_BASE_URL: 'https://media.invalid/lad' },
    stdio: 'ignore',
  });
  for (let i = 0; i < 150; i++) {
    try {
      await fetch(`http://127.0.0.1:${port}/connexion`);
      return child;
    } catch {
      await sleep(100);
    }
  }
  throw new Error('next start ne répond pas');
}

/** Cookies de session (format @supabase/ssr) d'une connexion par mot de passe : niveau aal1. */
async function sessionCookies(email: string, password: string) {
  const jar = new Map<string, string>();
  const supabase = createServerClient(env.SUPABASE_URL!, env.SUPABASE_PUBLISHABLE_KEY!, {
    cookies: {
      getAll: () => [...jar].map(([name, value]) => ({ name, value })),
      setAll: (list) => list.forEach((c) => jar.set(c.name, c.value)),
    },
  });
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return [...jar].map(([name, value]) => ({ name, value }));
}

async function cleanup() {
  const client = new pg.Client(connectionConfig(repo));
  await client.connect();
  try {
    await client.query('begin');
    const { rows } = await client.query<{ id: string }>(
      'select id from public.editions where name = $1',
      [editionName],
    );
    for (const { id } of rows) {
      await client.query('delete from public.catalog_releases where edition_id = $1', [id]);
      await client.query('delete from public.import_batches where edition_id = $1', [id]);
      await client.query('delete from public.hymns where edition_id = $1', [id]);
      await client.query('delete from public.editions where id = $1', [id]);
    }
    await client.query('delete from public.people where full_name = $1', [
      `Auteur E2E ${editionName}`,
    ]);
    await client.query('delete from public.themes where name = $1', [`Thème E2E ${editionName}`]);
    await client.query('commit');
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    await client.end();
  }
}

describe.skipIf(!ready)('parcours administrateur (navigateur réel)', () => {
  let chrome: Chrome;
  let server: ChildProcess;
  let base: string;
  let page: Page;
  let stopDialogs: () => void;

  const text = () => page.eval<string>('document.body.innerText');
  const go = async (path: string) => {
    await page.goto(`${base}${path}`);
    await page.waitFor("document.readyState === 'complete' && !!document.querySelector('h1')");
  };
  /** Clique sur le bouton (ou lien) dont le texte contient `label`, dans `scope` éventuellement. */
  const click = (label: string, scope = 'document') =>
    page.eval(
      `[...${scope}.querySelectorAll('button, a')].find(b => b.textContent.trim().includes(${JSON.stringify(label)})).click()`,
    );
  const fill = (selector: string, value: string) =>
    page.eval(`(() => {
      const el = document.querySelector(${JSON.stringify(selector)});
      const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, ${JSON.stringify(value)});
      el.dispatchEvent(new Event('input', { bubbles: true }));
    })()`);
  const waitText = (t: string, timeout = 20_000) =>
    page.waitFor(`document.body.innerText.includes(${JSON.stringify(t)})`, timeout);

  beforeAll(async () => {
    const port = await freePort();
    base = `http://127.0.0.1:${port}`;
    server = await startServer(port);
    chrome = await Chrome.launch();
    page = await chrome.newPage();
    await page.send('Log.enable');
    stopDialogs = await acceptDialogs(page);
  });

  afterAll(async () => {
    stopDialogs?.();
    server?.kill();
    await chrome?.close();
    if (ready) await cleanup();
  });

  it('connexion avec second facteur, import, validation, publication, T-009, retour arrière', async () => {
    const editor = JSON.parse(readFileSync(editorFile, 'utf8')) as {
      email: string;
      password: string;
      totpSecret: string;
    };

    // Sans session : page de connexion, CSP stricte.
    const anonymous = await fetch(`${base}/cantiques`, { redirect: 'manual' });
    expect(anonymous.status).toBe(307);
    expect(anonymous.headers.get('location')).toContain('/connexion');
    const login = await fetch(`${base}/connexion`);
    expect(login.headers.get('content-security-policy')).toMatch(
      /script-src 'self' 'nonce-[^']+' 'strict-dynamic'/,
    );
    expect(login.headers.get('x-frame-options')).toBe('DENY');
    expect(login.headers.get('content-security-policy')).toContain(
      'media-src https://media.invalid',
    );

    // Session sans second facteur → page MFA → code TOTP → tableau de bord.
    for (const cookie of await sessionCookies(editor.email, editor.password)) {
      await page.send('Network.setCookie', {
        ...cookie,
        url: base,
        httpOnly: false,
        sameSite: 'Lax',
      });
    }
    await go('/cantiques');
    expect(await page.eval('location.pathname')).toBe('/connexion/mfa');
    await fill('input[name=code]', totp(editor.totpSecret));
    await click('Vérifier');
    await waitText('Tableau de bord');
    expect(await text()).toContain('Progression de la revue');

    // Import : simulation puis import réel.
    await go('/import');
    const { root } = (await page.send('DOM.getDocument')).result as { root: { nodeId: number } };
    const { nodeId } = (
      await page.send('DOM.querySelector', { nodeId: root.nodeId, selector: 'input[type=file]' })
    ).result as { nodeId: number };
    await page.send('DOM.setFileInputFiles', { nodeId, files: [draftFile()] });
    await page.waitFor("!document.querySelector('button[value=simulate]').disabled");
    await click('Simuler l’import');
    await waitText('Simulation');
    expect(await text()).toContain('2 nouveau(x) cantique(s)');
    await click('Importer');
    await waitText('Import terminé');
    expect(await text()).toContain('1 anomalie(s) créée(s)');

    // Liste filtrée sur l'édition de test, validation par lots.
    await go('/cantiques');
    const editionId = await page.eval<string>(
      `[...document.querySelectorAll('select[name=edition] option')].find(o => o.textContent === ${JSON.stringify(editionName)}).value`,
    );
    await go(`/cantiques?edition=${editionId}`);
    expect(await text()).toContain('2 cantiques');
    await page.eval(
      `document.querySelectorAll('input[name=ids]').forEach(c => { c.checked = true; })`,
    );
    await click('Soumettre en relecture');
    await waitText('2 cantiques → « En relecture »');
    await page.eval(
      `document.querySelectorAll('input[name=ids]').forEach(c => { c.checked = true; })`,
    );
    await click('Valider');
    await waitText('2 cantiques → « Validé »');

    // Publication : diff puis release.
    await go(`/publication?edition=${editionId}`);
    expect(await text()).toContain('2 ajouté(s)');
    await click('Publier');
    await waitText('publiée : les applications').catch(async (error) => {
      throw new Error(`${error}\n--- page ---\n${(await text()).slice(0, 1500)}`);
    });
    const r1 = Number((await text()).match(/Release n° (\d+) publiée/)?.[1]);
    expect(r1, (await text()).slice(0, 800)).toBeGreaterThan(0);

    const publicTitle = async (release: number) => {
      const r = await fetch(
        `${env.SUPABASE_URL}/rest/v1/published_hymns?release_id=eq.${release}&select=title:payload->>title,label:payload->>numberLabel`,
        { headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY! } },
      );
      return ((await r.json()) as { title: string; label: string }[]).find((h) => h.label === '1')
        ?.title;
    };
    expect(await publicTitle(r1)).toBe('Premier cantique E2E');

    // T-009 : modifier un cantique publié le repasse en brouillon ; le public garde la version publiée.
    await go(`/cantiques?edition=${editionId}&q=Premier`);
    await click('Premier cantique E2E');
    await page.waitFor("location.pathname.startsWith('/cantiques/')");
    await page.waitFor("!!document.querySelector('input[name=title]')");
    const hymnPath = await page.eval<string>('location.pathname');
    await fill('input[name=title]', 'Premier cantique E2E (corrigé)');
    await click('Enregistrer');
    await waitText('Informations enregistrées.');
    expect(await page.eval("document.querySelector('h1').parentElement.innerText")).toContain(
      'Brouillon',
    );
    expect(await text()).toContain('Premier cantique E2E (corrigé)');
    // Aperçu « comme sur mobile » : nouveau titre et répétition reconnue.
    expect(
      await page.eval(
        'document.querySelector(\'[aria-label="Aperçu comme sur mobile"]\').innerText',
      ),
    ).toMatch(/Premier cantique E2E \(corrigé\)[\s\S]*×2/);
    await go(`/publication?edition=${editionId}`);
    expect(await text()).toContain('Rien à publier');
    expect(await publicTitle(r1)).toBe('Premier cantique E2E');

    // Revalidation, deuxième release, puis retour arrière vers la première.
    await go(hymnPath);
    await click('Soumettre en relecture');
    await waitText('Statut modifié.');
    await click('Valider');
    await waitText('Statut modifié.');
    await go(`/publication?edition=${editionId}`);
    expect(await text()).toContain('1 modifié(s)');
    await click('Publier');
    await waitText('publiée : les applications');
    const r2 = Number((await text()).match(/Release n° (\d+) publiée/)![1]);
    expect(await publicTitle(r2)).toBe('Premier cantique E2E (corrigé)');
    await page.eval(
      `[...document.querySelectorAll('tr')].find(tr => tr.firstElementChild?.textContent === '${r1}').querySelector('button').click()`,
    );
    await waitText(`avec le contenu de la release n° ${r1}`);
    const r3 = Number((await text()).match(/Release n° (\d+) publiée avec/)![1]);
    expect(await publicTitle(r3)).toBe('Premier cantique E2E');

    // Enregistrement audio : chemin contrôlé, passages, diffusé à la publication suivante
    // sans repasser le cantique en brouillon.
    await go(hymnPath);
    await fill('input[name=storage_key]', 'https://f003.backblazeb2.com/file/lad/a.mp3');
    await click('Ajouter', "document.querySelector('input[name=storage_key]').closest('form')");
    await waitText('Chemin du fichier invalide');
    await fill('input[name=storage_key]', 'cantiques/e2e/melodie.mp3');
    await fill('input[name=duration]', '2:00');
    await click('Ajouter', "document.querySelector('input[name=storage_key]').closest('form')");
    await waitText('Enregistrement ajouté.');
    expect(await page.eval("document.querySelector('h1').parentElement.innerText")).toContain(
      'Validé',
    );
    expect(await page.eval<string>("document.querySelector('audio').getAttribute('src')")).toBe(
      'https://media.invalid/lad/cantiques/e2e/melodie.mp3',
    );
    await fill('textarea[name=segments]', '0:00 #1\n1:30 -\n2:00 fin');
    await click('Enregistrer les passages');
    await waitText('Passages enregistrés.');
    expect(await text()).toContain('Passages (2)');
    expect(
      await page.eval(
        'document.querySelector(\'[aria-label="Aperçu comme sur mobile"]\').innerText',
      ),
    ).toContain('Écouter : Mélodie');
    await go(`/publication?edition=${editionId}`);
    await click('Publier');
    await waitText('publiée : les applications');
    const r4 = Number((await text()).match(/Release n° (\d+) publiée/)![1]);
    const audioRes = await fetch(
      `${env.SUPABASE_URL}/rest/v1/published_hymns?release_id=eq.${r4}&select=label:payload->>numberLabel,audio:payload->audio`,
      { headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY! } },
    );
    const published = (
      (await audioRes.json()) as {
        label: string;
        audio: { storageKey: string; segments: unknown[] }[] | null;
      }[]
    ).find((h) => h.label === '1');
    expect(published?.audio?.[0]?.storageKey).toBe('cantiques/e2e/melodie.mp3');
    expect(published?.audio?.[0]?.segments).toHaveLength(2);

    // Auteur et thème : visibles dans l'aperçu (rien d'inventé tant qu'ils ne sont pas saisis).
    await go(`/cantiques?edition=${editionId}&q=Second`);
    await click('Second cantique E2E');
    await page.waitFor("!!document.querySelector('input[name=full_name]')");
    const preview = () =>
      page.eval<string>(
        'document.querySelector(\'[aria-label="Aperçu comme sur mobile"]\').innerText',
      );
    expect(await preview()).not.toContain('Auteur E2E');
    await fill('input[name=full_name]', `Auteur E2E ${editionName}`);
    await click('Ajouter', "document.querySelector('input[name=full_name]').closest('form')");
    await waitText('Personne ajoutée.');
    await fill('input[name=name]', `Thème E2E ${editionName}`);
    await click(
      'Ajouter',
      "document.querySelector('input[name=name][list=themes]').closest('form')",
    );
    await waitText('Thème ajouté.');
    expect(await preview()).toContain(`Auteur E2E ${editionName}`);
    expect(await preview()).toContain(`Thème E2E ${editionName}`);

    // Anomalie : ignorer exige une justification.
    await go('/anomalies?code=A-11');
    await page.eval(`document.querySelector('input[name=ids]').checked = true`);
    await click('Ignorer la sélection');
    await waitText('Indiquez pourquoi');
    await page.eval(`document.querySelector('input[name=ids]').checked = true`);
    await fill('input[name=note]', 'Vérifié : conforme au recueil');
    await click('Ignorer la sélection');
    await waitText('1 anomalie ignorée.');

    // Journal et équipe.
    await go('/journal');
    expect(await text()).toContain(editor.email);
    await go('/equipe');
    expect(await text()).toContain(`${editor.email} (vous)`);

    if (process.env.ADMIN_SHOT) {
      const { writeFileSync: write } = await import('node:fs');
      for (const [path, name] of [
        ['/', 'tableau-de-bord'],
        [`/cantiques?edition=${editionId}`, 'cantiques'],
        [hymnPath, 'cantique'],
        [`/publication?edition=${editionId}`, 'publication'],
      ] as const) {
        await go(path);
        const shot = await page.send('Page.captureScreenshot', {
          format: 'png',
          captureBeyondViewport: false,
        });
        write(
          `${process.env.ADMIN_SHOT}-${name}.png`,
          Buffer.from((shot.result as { data: string }).data, 'base64'),
        );
      }
    }

    // Aucune violation de CSP ni erreur de script pendant le parcours.
    const problems = page.events.filter(
      (e) =>
        e.method === 'Runtime.exceptionThrown' ||
        (e.method === 'Log.entryAdded' &&
          /Content Security Policy|Refused to/i.test(
            String((e.params.entry as { text: string }).text),
          )),
    );
    expect(problems).toEqual([]);
  });
});
