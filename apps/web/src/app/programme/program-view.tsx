import { formatServiceDate, type SharedProgram } from '@/lib/shared-program';

import styles from './programme.module.css';

/** Programme partagé : numéros et titres (Q-09), moments libres, notes. */
export function ProgramView({ program }: { program: SharedProgram }) {
  const date = program.serviceDate ? formatServiceDate(program.serviceDate) : null;
  return (
    <article className={styles.program}>
      <header className={styles.header}>
        <p className={styles.brand}>Louanges à Dieu</p>
        <h1 className={styles.title}>{program.title}</h1>
        {date && <p className={styles.date}>{date}</p>}
        {program.location && <p className={styles.location}>{program.location}</p>}
        {program.description && <p className={styles.description}>{program.description}</p>}
      </header>
      {program.items.length === 0 ? (
        <p className={styles.muted}>Ce programme ne contient encore aucun élément.</p>
      ) : (
        <ol className={styles.items}>
          {program.items.map((item) => (
            <li key={item.position} className={styles.item}>
              <ItemContent item={item} />
              {item.notes && <p className={styles.notes}>{item.notes}</p>}
            </li>
          ))}
        </ol>
      )}
    </article>
  );
}

function ItemContent({ item }: { item: SharedProgram['items'][number] }) {
  if (item.hymn === null) {
    return <p className={styles.section}>{item.label}</p>;
  }
  if (item.hymn.unavailable) {
    return <p className={styles.muted}>Cantique retiré du recueil</p>;
  }
  return (
    <p className={styles.hymn}>
      <span className={styles.number}>{item.hymn.numberLabel}</span>
      <span>{item.hymn.title}</span>
    </p>
  );
}

/** Message unique pour tout lien inutilisable : rien n'indique pourquoi. */
export function UnavailableView() {
  return (
    <article className={styles.program}>
      <header className={styles.header}>
        <p className={styles.brand}>Louanges à Dieu</p>
        <h1 className={styles.title}>Programme indisponible</h1>
      </header>
      <p className={styles.muted}>
        Ce lien ne donne accès à aucun programme. Il a peut-être été désactivé ou a expiré :
        demandez un nouveau lien à la personne qui vous l’a envoyé.
      </p>
    </article>
  );
}

export function ServiceErrorView() {
  return (
    <article className={styles.program}>
      <header className={styles.header}>
        <p className={styles.brand}>Louanges à Dieu</p>
        <h1 className={styles.title}>Service momentanément indisponible</h1>
      </header>
      <p className={styles.muted}>
        Le programme n’a pas pu être chargé. Réessayez dans un instant.
      </p>
    </article>
  );
}
