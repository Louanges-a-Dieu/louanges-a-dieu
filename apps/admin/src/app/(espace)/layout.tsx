import type { ReactNode } from 'react';

import { NavLink } from '@/components/nav-link';
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
            <NavLink href="/">Tableau de bord</NavLink>
          </li>
          <li>
            <NavLink href="/cantiques">Cantiques</NavLink>
          </li>
          <li>
            <NavLink href="/anomalies">Anomalies</NavLink>
          </li>
          <li>
            <NavLink href="/publication">Publication</NavLink>
          </li>
          <li>
            <NavLink href="/import">Import</NavLink>
          </li>
          <li>
            <NavLink href="/journal">Journal</NavLink>
          </li>
          {editor.isSuperAdmin && (
            <li>
              <NavLink href="/equipe">Équipe</NavLink>
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
