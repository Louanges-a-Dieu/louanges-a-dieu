'use client';

import { useState } from 'react';

import { saveProgram, toSavedProgram } from '@/lib/projection/saved-programs';
import { openStore } from '@/lib/projection/store';
import type { SharedProgram } from '@/lib/shared-program';

import styles from './programme.module.css';

/**
 * Mode « ordinateur seul » (8.4) : garde ce programme sur l'ordinateur pour le
 * projeter plus tard sans Internet, depuis /projection.
 */
export function SaveForProjection({ program }: { program: SharedProgram }) {
  const [status, setStatus] = useState<'idle' | 'saved' | 'error'>('idle');
  return (
    <section className={styles.projection}>
      <button
        type="button"
        className={styles.projectionButton}
        onClick={async () => {
          try {
            await saveProgram(await openStore(), toSavedProgram(program));
            setStatus('saved');
          } catch {
            setStatus('error');
          }
        }}
      >
        Préparer pour la projection hors ligne
      </button>
      {status === 'saved' && (
        <p className={styles.notes} role="status">
          Programme gardé sur cet ordinateur. Ouvrez maintenant{' '}
          <a href="/projection">la console de projection</a> une première fois avec Internet : elle
          sera ensuite utilisable sans connexion.
        </p>
      )}
      {status === 'error' && (
        <p className={styles.notes} role="alert">
          Ce navigateur ne permet pas de garder le programme (navigation privée ?).
        </p>
      )}
    </section>
  );
}
