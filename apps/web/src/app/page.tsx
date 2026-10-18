import Link from 'next/link';

import styles from './page.module.css';

/** Accueil du site public : projection hors ligne et informations légales. */
export default function Home() {
  return (
    <main className={styles.main}>
      <h1 className={styles.title}>Louanges à Dieu</h1>
      <p className={styles.lead}>Le recueil de cantiques, à lire, partager et projeter.</p>
      <nav className={styles.links} aria-label="Liens">
        <Link href="/projection">Projeter depuis cet ordinateur</Link>
        <Link href="/confidentialite">Confidentialité</Link>
        <Link href="/suppression-compte">Supprimer son compte</Link>
      </nav>
    </main>
  );
}
