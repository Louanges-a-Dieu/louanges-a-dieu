import type { PublishedHymn } from '@lad/shared-contracts';

import { sectionName } from '@/lib/text';

import styles from './hymn-preview.module.css';

/**
 * Aperçu « comme sur mobile » (9.5) : rendu du contenu exactement tel qu'une
 * publication l'enverrait à l'application (preview_hymn). Les informations
 * inconnues ne sont pas affichées (T-010). Les répétitions détectées dans le
 * texte (« (bis) », « (ter) », « (4x) ») sont signalées.
 */
export function HymnPreview({ hymn }: { hymn: PublishedHymn }) {
  const sections = [...hymn.sections].sort((a, b) => a.order - b.order);
  return (
    <article className={styles.phone} aria-label="Aperçu comme sur mobile">
      <p className={styles.number}>{hymn.numberLabel}</p>
      <h3 className={styles.title}>{hymn.title}</h3>
      {hymn.bibleReferences.length > 0 && (
        <p className={styles.references}>
          {hymn.bibleReferences.map((r) => r.displayText).join(' · ')}
        </p>
      )}
      {sections.map((section) => (
        <section
          key={section.id}
          className={section.type === 'refrain' ? styles.refrain : styles.section}
        >
          <p className={styles.sectionName}>{sectionName(section.type, section.number)}</p>
          {section.lines.map((line, i) => (
            <p key={i} className={styles.line}>
              {line.text}
              {line.repeat && (
                <span className={styles.repeat} title={`Chanté ${line.repeat.count} fois`}>
                  ×{line.repeat.count}
                </span>
              )}
            </p>
          ))}
        </section>
      ))}
      {hymn.people.length > 0 && (
        <p className={styles.meta}>{hymn.people.map((p) => p.fullName).join(', ')}</p>
      )}
      {hymn.themes.length > 0 && <p className={styles.meta}>{hymn.themes.join(' · ')}</p>}
    </article>
  );
}
