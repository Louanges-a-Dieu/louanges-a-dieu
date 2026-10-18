import type { Metadata } from 'next';
import { connection } from 'next/server';

import ui from '@/components/ui.module.css';

import { signOutAction } from '../connexion/actions';
import styles from '../connexion/auth.module.css';

export const metadata: Metadata = { title: 'Accès refusé — Administration' };

export default async function AccessDeniedPage() {
  // Rendu à chaque requête : la CSP exige un nonce neuf (proxy.ts).
  await connection();
  return (
    <main className={styles.page}>
      <div className={styles.panel}>
        <p className={styles.brand}>Louanges à Dieu</p>
        <h1 className={ui.h1}>Accès réservé</h1>
        <p>
          Ce compte n’a pas de rôle éditorial. Demandez à un super administrateur de vous ajouter à
          l’équipe (page « Équipe »), puis reconnectez-vous.
        </p>
        <form action={signOutAction}>
          <button type="submit" className={ui.button}>
            Se déconnecter
          </button>
        </form>
      </div>
    </main>
  );
}
