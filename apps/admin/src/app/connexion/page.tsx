import type { Metadata } from 'next';
import { connection } from 'next/server';

import ui from '@/components/ui.module.css';

import styles from './auth.module.css';
import { LoginForm } from './login-form';

export const metadata: Metadata = { title: 'Connexion — Administration' };

export default async function LoginPage() {
  // Rendu à chaque requête : la CSP exige un nonce neuf (proxy.ts).
  await connection();
  return (
    <main className={styles.page}>
      <div className={styles.panel}>
        <p className={styles.brand}>Louanges à Dieu</p>
        <h1 className={ui.h1}>Administration</h1>
        <LoginForm />
      </div>
    </main>
  );
}
