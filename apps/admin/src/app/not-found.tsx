import Link from 'next/link';
import { connection } from 'next/server';

import ui from '@/components/ui.module.css';

export default async function NotFound() {
  // Rendu à chaque requête : la CSP exige un nonce neuf (proxy.ts).
  await connection();
  return (
    <main>
      <h1 className={ui.h1}>Page introuvable</h1>
      <Link href="/">Retour au tableau de bord</Link>
    </main>
  );
}
