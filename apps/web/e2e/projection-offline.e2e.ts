/**
 * Mode « ordinateur seul » de bout en bout (8.4, 8.5), dans un VRAI Chrome :
 * un programme est préparé depuis son lien de partage, la console est ouverte
 * une fois avec Internet, puis le serveur web est ARRÊTÉ et le réseau coupé ;
 * la console et l'écran projeté (deuxième onglet, BroadcastChannel) doivent
 * continuer à fonctionner (Q-08, T-008).
 *
 * Prérequis : `pnpm build`, Chrome, apps/web/.env.local (base de dev).
 * L'étape « programme » demande aussi l'utilisateur de test
 * (node tools/pgtap/create-test-user.ts).
 */
import { spawn, type ChildProcess } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { Chrome, chromePath, freePort, sleep, type Page } from '../../../tools/e2e/cdp';
import { createSharedProgram, envFile, hasTestUser } from './dev-backend';

const web = resolve(import.meta.dirname, '..');
const ready = !!chromePath && existsSync(envFile) && existsSync(resolve(web, '.next/BUILD_ID'));

async function startServer(port: number): Promise<ChildProcess> {
  const child = spawn(resolve(web, 'node_modules/.bin/next'), ['start', '-p', String(port)], {
    cwd: web,
    // Next ne lit pas .env.local quand NODE_ENV vaut « test » (cas de Vitest).
    env: { ...process.env, NODE_ENV: 'production' },
    stdio: 'ignore',
  });
  for (let i = 0; i < 150; i++) {
    try {
      await fetch(`http://127.0.0.1:${port}/projection`);
      return child;
    } catch {
      await sleep(100);
    }
  }
  throw new Error('next start ne répond pas');
}

describe.skipIf(!ready)('projection sur ordinateur seul, sans Internet', () => {
  let chrome: Chrome;
  let server: ChildProcess | null = null;
  let port: number;
  let program: Awaited<ReturnType<typeof createSharedProgram>> | null = null;

  beforeAll(async () => {
    port = await freePort();
    server = await startServer(port);
    chrome = await Chrome.launch();
    if (hasTestUser())
      program = await createSharedProgram('Culte (test hors ligne)', ['1', '37bis']);
  });

  afterAll(async () => {
    server?.kill();
    await chrome?.close();
    await program?.cleanup();
  });

  it('prépare, coupe tout, puis projette', async () => {
    const base = `http://127.0.0.1:${port}`;
    const console_ = await chrome.newPage();

    // 1. Avec Internet : programme gardé depuis son lien de partage.
    if (program) {
      await console_.goto(`${base}/programme/${program.token}`);
      await console_.waitFor("document.body.innerText.includes('Préparer pour la projection')");
      await console_.eval(
        "[...document.querySelectorAll('button')].find(b => b.textContent.includes('Préparer')).click()",
      );
      await console_.waitFor(
        "document.body.innerText.includes('Programme gardé sur cet ordinateur')",
      );
    }

    // 2. Avec Internet : la console télécharge le recueil et s'installe.
    await console_.goto(`${base}/projection`);
    await console_.waitFor("document.body.innerText.includes('Prêt sans Internet')", 60_000);
    const count = await console_.eval<string>(
      'document.body.innerText.match(/(\\d+) cantiques/)[1]',
    );
    expect(Number(count)).toBeGreaterThan(1000);

    // 3. Plus de serveur web, plus de réseau.
    server!.kill();
    server = null;
    await sleep(500);
    await expect(fetch(`${base}/projection`)).rejects.toThrow();
    const offline = {
      offline: true,
      latency: 0,
      downloadThroughput: 0,
      uploadThroughput: 0,
    };
    await console_.send('Network.emulateNetworkConditions', offline);
    console_.events.length = 0;

    // 4. La console se recharge depuis l'ordinateur.
    await console_.send('Page.reload', {});
    await console_.waitFor("document.body.innerText.includes('cantiques')", 30_000);
    expect(await console_.eval<string>('document.title')).toContain('Projection');

    // 5. L'écran projeté (deuxième onglet) s'ouvre aussi sans réseau.
    const screen = await chrome.newPage();
    await screen.send('Network.emulateNetworkConditions', offline);
    await screen.goto(`${base}/projection-ecran/screen.html?canal=local`);
    await screen.waitFor("document.body.textContent.includes('Louanges à Dieu')");
    await screen.eval('window.__chargement = 42');

    // 6. Choisir un cantique par la recherche : l'écran affiche son titre.
    await console_.eval(`(() => {
      const input = document.getElementById('recherche');
      const set = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      set.call(input, '37bis');
      input.dispatchEvent(new Event('input', { bubbles: true }));
    })()`);
    await console_.waitFor('document.querySelector(\'[aria-label="Résultats"] button\') !== null');
    const title = await console_.eval<string>(
      'document.querySelector(\'[aria-label="Résultats"] button span:last-child\').textContent',
    );
    await console_.eval('document.querySelector(\'[aria-label="Résultats"] button\').click()');
    await screen.waitFor(`document.body.textContent.includes(${JSON.stringify(title)})`);

    // 7. T-008 : diapositive suivante sans rechargement de l'écran.
    await console_.eval(
      "[...document.querySelectorAll('button')].find(b => b.textContent.includes('Suivante')).click()",
    );
    const latency = await screen.waitFor("document.querySelector('.section-name') !== null");
    expect(await screen.eval('window.__chargement')).toBe(42);
    console.log(`Console → écran projeté (BroadcastChannel) : ${latency} ms`);
    expect(latency).toBeLessThan(300);

    // 8. Écran noir au clavier (touche B, comme une télécommande).
    await console_.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'b', text: 'b' });
    await console_.send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'b' });
    await screen.waitFor("document.body.classList.contains('blank')");
    await console_.send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'b', text: 'b' });
    await screen.waitFor("!document.body.classList.contains('blank')");

    // La console voit l'écran projeté.
    await console_.waitFor("document.body.innerText.includes('Écran projeté ouvert')", 10_000);

    // 9. Le programme préparé se projette aussi hors ligne, depuis son début.
    if (program) {
      await console_.eval(
        "[...document.querySelectorAll('button')].find(b => b.textContent.includes('Culte (test hors ligne)')).click()",
      );
      await screen.waitFor("document.body.textContent.includes('Accueil')").catch(async (error) => {
        const text = await console_.eval<string>('document.body.innerText');
        throw new Error(`${error}\n--- console ---\n${text.slice(0, 1500)}`);
      });
      await console_.eval(
        "[...document.querySelectorAll('button')].find(b => b.textContent.includes('Suivante')).click()",
      );
      await screen.waitFor("document.querySelector('.number')?.textContent === '1'");
    }

    // Aucune requête n'a pu partir sur le réseau pendant la coupure.
    const failedOrSent = console_.events.filter(
      (e) =>
        e.method === 'Network.responseReceived' &&
        !(e.params.response as { fromServiceWorker?: boolean }).fromServiceWorker,
    );
    expect(failedOrSent.map((e) => (e.params.response as { url: string }).url)).toEqual([]);
    expect(console_.events.filter((e) => e.method === 'Runtime.exceptionThrown')).toEqual([]);
    expect(screen.events.filter((e) => e.method === 'Runtime.exceptionThrown')).toEqual([]);

    if (process.env.PROJECTION_SHOT) {
      for (const [page, name] of [
        [console_, 'console'],
        [screen, 'ecran'],
      ] as Array<[Page, string]>) {
        const shot = await page.send('Page.captureScreenshot', { format: 'png' });
        const { writeFileSync } = await import('node:fs');
        writeFileSync(
          `${process.env.PROJECTION_SHOT}-${name}.png`,
          Buffer.from((shot.result as { data: string }).data, 'base64'),
        );
      }
    }
  });
});
