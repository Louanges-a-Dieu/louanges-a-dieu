import { spawn, type ChildProcess } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

/** Client minimal du protocole DevTools pour piloter un vrai Chrome. */
export const chromePath = [
  process.env.CHROME_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
].find((p): p is string => !!p && existsSync(p));

export async function freePort(): Promise<number> {
  return new Promise((resolve) => {
    const server = createServer();
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address() as { port: number };
      server.close(() => resolve(port));
    });
  });
}

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export class Page {
  private id = 0;
  private pending = new Map<number, (msg: Record<string, unknown>) => void>();
  readonly events: Array<{ method: string; params: Record<string, unknown> }> = [];

  private constructor(private ws: WebSocket) {
    ws.addEventListener('message', (e) => {
      const msg = JSON.parse(String(e.data));
      if (msg.id && this.pending.has(msg.id)) {
        this.pending.get(msg.id)!(msg);
        this.pending.delete(msg.id);
      } else if (msg.method) {
        this.events.push(msg);
      }
    });
  }

  static async attach(debuggerUrl: string): Promise<Page> {
    const ws = new WebSocket(debuggerUrl);
    await new Promise((r) => ws.addEventListener('open', r, { once: true }));
    const page = new Page(ws);
    await page.send('Runtime.enable');
    await page.send('Network.enable');
    await page.send('Page.enable');
    return page;
  }

  send(method: string, params: Record<string, unknown> = {}): Promise<Record<string, unknown>> {
    const id = ++this.id;
    return new Promise((resolve) => {
      this.pending.set(id, resolve);
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async eval<T = unknown>(expression: string): Promise<T> {
    const r = await this.send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    const result = r.result as { result?: { value?: T }; exceptionDetails?: unknown };
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result?.value as T;
  }

  async waitFor(expression: string, timeout = 30_000): Promise<number> {
    const start = Date.now();
    while (Date.now() - start < timeout) {
      try {
        if (await this.eval<boolean>(expression)) return Date.now() - start;
      } catch {
        /* page en cours de chargement */
      }
      await sleep(25);
    }
    throw new Error(`Condition jamais vraie : ${expression}`);
  }

  async goto(url: string) {
    await this.send('Page.navigate', { url });
  }

  close() {
    this.ws.close();
  }
}

export class Chrome {
  private constructor(
    private process: ChildProcess,
    private profile: string,
    readonly port: number,
  ) {}

  static async launch(): Promise<Chrome> {
    const port = await freePort();
    const profile = mkdtempSync(join(tmpdir(), 'lad-chrome-'));
    const child = spawn(
      chromePath!,
      [
        '--headless=new',
        '--disable-gpu',
        '--no-first-run',
        '--no-default-browser-check',
        `--remote-debugging-port=${port}`,
        `--user-data-dir=${profile}`,
        'about:blank',
      ],
      { stdio: 'ignore' },
    );
    for (let i = 0; i < 100; i++) {
      try {
        await fetch(`http://127.0.0.1:${port}/json/version`);
        return new Chrome(child, profile, port);
      } catch {
        await sleep(100);
      }
    }
    throw new Error('Chrome ne répond pas');
  }

  /** Nouvel onglet (même profil : même stockage, même BroadcastChannel). */
  async newPage(): Promise<Page> {
    const response = await fetch(`http://127.0.0.1:${this.port}/json/new?about:blank`, {
      method: 'PUT',
    });
    const target = (await response.json()) as { webSocketDebuggerUrl: string };
    const page = await Page.attach(target.webSocketDebuggerUrl);
    await page.send('Emulation.setDeviceMetricsOverride', {
      width: 1280,
      height: 800,
      deviceScaleFactor: 1,
      mobile: false,
    });
    return page;
  }

  async close() {
    this.process.kill();
    await sleep(300);
    rmSync(this.profile, { recursive: true, force: true });
  }
}

/** Accepte automatiquement les boîtes « confirmer » de la page. */
export async function acceptDialogs(page: Page) {
  const timer = setInterval(() => {
    const dialog = page.events.findIndex((e) => e.method === 'Page.javascriptDialogOpening');
    if (dialog >= 0) {
      page.events.splice(dialog, 1);
      void page.send('Page.handleJavaScriptDialog', { accept: true });
    }
  }, 20);
  return () => clearInterval(timer);
}
