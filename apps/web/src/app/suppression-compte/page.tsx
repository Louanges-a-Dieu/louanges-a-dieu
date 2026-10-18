import type { Metadata } from 'next';
import Link from 'next/link';

import styles from '../legal.module.css';

export const metadata: Metadata = {
  title: 'Supprimer son compte — Louanges à Dieu',
  description: 'Comment supprimer votre compte Louanges à Dieu et vos données.',
  robots: { index: true, follow: true },
};

const CONTACT = 'louangesaDieu04@gmail.com';

/** Suppression de compte (exigence des stores, 10.7). */
export default function AccountDeletionPage() {
  return (
    <main className={styles.page}>
      <p className={styles.brand}>Louanges à Dieu</p>
      <h1>Supprimer son compte</h1>

      <h2>Depuis l’application</h2>
      <ol>
        <li>Ouvrez l’onglet « Plus », puis « Mon compte ».</li>
        <li>Touchez « Supprimer mon compte » et confirmez.</li>
      </ol>
      <p>
        La suppression est <strong>immédiate et définitive</strong> : adresse e-mail, favoris
        synchronisés, listes et programmes de culte sont effacés, et les liens de partage cessent de
        fonctionner. Les copies de sauvegarde chiffrées sont effacées au plus tard 180 jours après.
      </p>
      <p>
        Sans compte, l’application ne conserve vos favoris et réglages que sur votre appareil :
        désinstaller l’application les efface.
      </p>

      <h2>Sans l’application</h2>
      <p>
        Écrivez à <a href={`mailto:${CONTACT}?subject=Suppression%20de%20compte`}>{CONTACT}</a>{' '}
        depuis l’adresse e-mail du compte, avec l’objet « Suppression de compte ». La suppression
        est effectuée sous 30 jours et vous est confirmée par e-mail.
      </p>

      <p>
        Voir aussi la <Link href="/confidentialite">politique de confidentialité</Link>.
      </p>
    </main>
  );
}
