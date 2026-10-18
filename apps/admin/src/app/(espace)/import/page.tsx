import type { Metadata } from 'next';

import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';

import { ImportForm } from './import-form';

export const metadata: Metadata = { title: 'Import — Administration' };

/** Import d'un catalogue brouillon et diff de réimport (9.9). */
export default async function ImportPage() {
  const { supabase } = await requireEditor();
  const { data: batches } = await supabase
    .from('import_batches')
    .select('id, source_filename, parser_version, stats, created_at')
    .order('created_at', { ascending: false })
    .limit(10);

  return (
    <>
      <h1 className={ui.h1}>Import</h1>
      <p className={ui.hint}>
        Le fichier est produit par <code>content-tools import</code> à partir du .docx. Un cantique
        déjà présent n’est jamais écrasé : les différences deviennent des anomalies à arbitrer.
      </p>
      <ImportForm />
      <section className={ui.card}>
        <h2 className={ui.h2}>Derniers imports</h2>
        <table className={ui.table}>
          <thead>
            <tr>
              <th>Date</th>
              <th>Fichier</th>
              <th>Résultat</th>
            </tr>
          </thead>
          <tbody>
            {(batches ?? []).map((b) => {
              const stats = b.stats as Record<string, number>;
              return (
                <tr key={b.id}>
                  <td>{new Date(b.created_at).toLocaleString('fr-FR')}</td>
                  <td>
                    {b.source_filename} <span className={ui.muted}>({b.parser_version})</span>
                  </td>
                  <td>
                    {stats.inserted ?? 0} ajoutés · {stats.changed ?? 0} différents ·{' '}
                    {stats.missingFromSource ?? 0} absents
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </section>
    </>
  );
}
