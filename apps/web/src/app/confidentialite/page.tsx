import type { Metadata } from 'next';
import Link from 'next/link';

import styles from '../legal.module.css';

export const metadata: Metadata = {
  title: 'Confidentialité — Louanges à Dieu',
  description: 'Politique de confidentialité de l’application Louanges à Dieu.',
  robots: { index: true, follow: true },
};

const CONTACT = 'louangesaDieu04@gmail.com';

/** Politique de confidentialité (10.7) : décrit exactement le fonctionnement de l'application. */
export default function PrivacyPage() {
  return (
    <main className={styles.page}>
      <p className={styles.brand}>Louanges à Dieu</p>
      <h1>Politique de confidentialité</h1>
      <p className={styles.updated}>Version du 18 octobre 2026</p>

      <p>
        L’application <strong>Louanges à Dieu</strong> permet de lire, rechercher et projeter les
        cantiques du recueil. Elle est conçue pour collecter le moins de données possible : elle ne
        contient <strong>ni publicité, ni pistage, ni mesure d’audience</strong>, et aucune donnée
        n’est vendue ni cédée.
      </p>

      <h2>Sans compte</h2>
      <p>
        L’application s’utilise entièrement sans compte. Le recueil est téléchargé puis conservé sur
        l’appareil ; vos favoris et réglages restent <strong>sur votre appareil</strong> et ne nous
        sont pas transmis. Pour vérifier les mises à jour du recueil, l’application contacte notre
        serveur, qui reçoit, comme tout serveur, l’adresse IP de la connexion ; elle n’est pas
        associée à votre identité.
      </p>

      <h2>Avec un compte</h2>
      <p>
        Un compte est facultatif. Il sert à retrouver vos listes, programmes de culte et favoris sur
        plusieurs appareils.
      </p>
      <table>
        <thead>
          <tr>
            <th>Donnée</th>
            <th>Pourquoi</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Adresse e-mail</td>
            <td>Vous connecter (code envoyé par e-mail, sans mot de passe)</td>
          </tr>
          <tr>
            <td>Favoris, listes, programmes de culte</td>
            <td>Les synchroniser entre vos appareils</td>
          </tr>
        </tbody>
      </table>
      <p>
        Ces données sont hébergées dans l’Union européenne (Irlande). Elles sont conservées tant que
        le compte existe. Les copies de sauvegarde, chiffrées, sont effacées au plus tard 180 jours
        après la suppression.
      </p>

      <h2>Programmes partagés</h2>
      <p>
        Si vous partagez un programme de culte, toute personne disposant du lien voit son titre, sa
        date et la liste des cantiques et moments,{' '}
        <strong>sans votre nom ni votre adresse e-mail</strong>. Vous pouvez désactiver le lien à
        tout moment depuis l’application.
      </p>

      <h2>Projection</h2>
      <p>
        La projection depuis un téléphone passe uniquement par votre réseau local (Wi-Fi ou point
        d’accès du téléphone) ; rien ne transite par Internet.
      </p>

      <h2>Rapports de plantage</h2>
      <p>
        En cas de plantage, l’application peut envoyer un rapport technique (modèle et système de
        l’appareil, version de l’application, description de l’erreur) afin de la corriger. Ces
        rapports ne contiennent ni votre adresse e-mail, ni identifiant de compte, ni capture
        d’écran.
      </p>

      <h2>Prestataires</h2>
      <p>
        Hébergement de la base de données et de la connexion : Supabase (Union européenne) ; envoi
        des e-mails de connexion : Resend ; site web : Vercel ; sauvegardes chiffrées : Cloudflare ;
        rapports de plantage : Sentry. Ils n’agissent que pour notre compte.
      </p>

      <h2>Vos droits</h2>
      <p>
        Vous pouvez consulter, corriger, exporter ou supprimer vos données. La suppression du compte
        se fait directement dans l’application (voir{' '}
        <Link href="/suppression-compte">suppression du compte</Link>). Pour toute demande ou
        question : <a href={`mailto:${CONTACT}`}>{CONTACT}</a>. Vous pouvez également saisir
        l’autorité de protection des données de votre pays.
      </p>

      <h2>Enfants</h2>
      <p>
        L’application ne demande aucune information sur l’âge et ne collecte aucune donnée sans
        compte. La création d’un compte est réservée aux personnes ayant l’âge requis dans leur pays
        pour consentir seules à un service en ligne.
      </p>
    </main>
  );
}
