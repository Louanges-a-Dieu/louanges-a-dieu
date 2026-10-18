import Link from 'next/link';
import type { ReactNode } from 'react';

import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';

import { signOutAction } from '../connexion/actions';
import styles from './layout.module.css';

/** Espace éditorial : session, rôle et second facteur exigés (requireEditor). */
export default async function EditorialLayout({ children }: { children: ReactNode }) {
  const editor = await requireEditor();
  return (
    <div className={styles.shell}>
      <nav className={styles.nav} aria-label="Navigation principale">
        <p className={styles.brand}>
          <small>Louanges à Dieu</small>
          Administration
        </p>
        <ul className={styles.links}>
          <li>
            <Link href="/">Tableau de bord</Link>
          </li>
          <li>
            <Link href="/cantiques">Cantiques</Link>
          </li>
          <li>
            <Link href="/anomalies">Anomalies</Link>
          </li>
          <li>
            <Link href="/publication">Publication</Link>
          </li>
          <li>
            <Link href="/import">Import</Link>
          </li>
          <li>
            <Link href="/journal">Journal</Link>
          </li>
          {editor.isSuperAdmin && (
            <li>
              <Link href="/equipe">Équipe</Link>
            </li>
          )}
        </ul>
        <p className={styles.account}>
          {editor.email}
          <br />
          {editor.isSuperAdmin ? 'Super administrateur' : 'Éditeur'}
        </p>
        <form action={signOutAction}>
          <button type="submit" className={ui.buttonGhost}>
            Se déconnecter
          </button>
        </form>
      </nav>
      <main className={styles.main}>{children}</main>
    </div>
  );
}
