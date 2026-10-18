import type { Metadata } from 'next';
import Link from 'next/link';

import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { param } from '@/lib/data';

export const metadata: Metadata = { title: 'Journal — Administration' };

const TABLES: Record<string, string> = {
  hymns: 'Cantique',
  hymn_sections: 'Section',
  bible_references: 'Référence',
  hymn_relations: 'Lien',
  rights_records: 'Droits',
  import_issues: 'Anomalie',
  catalog_releases: 'Release',
  user_roles: 'Rôle',
  editions: 'Édition',
};
const ACTIONS: Record<string, string> = {
  insert: 'création',
  update: 'modification',
  delete: 'suppression',
};

interface Entry {
  id: number;
  occurred_at: string;
  actor_email: string | null;
  table_name: string;
  record_id: string;
  action: string;
  changes: Record<string, unknown>;
}

/** Journal des modifications (9.10), le plus récent d'abord. */
export default async function JournalPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireEditor();
  const objet = param(sp.objet);
  const avant = param(sp.avant);
  const { data, error } = await supabase.rpc('admin_audit_log', {
    p_record_id: objet ?? null,
    p_limit: 100,
    p_before: avant ? Number(avant) : null,
  });
  const entries = (data ?? []) as Entry[];
  const next = entries.length === 100 ? entries[entries.length - 1]!.id : null;

  return (
    <>
      <h1 className={ui.h1}>Journal</h1>
      {error && <p className={ui.error}>{error.message}</p>}
      {objet && (
        <p>
          Filtré sur un objet · <Link href="/journal">tout afficher</Link>
        </p>
      )}
      <table className={ui.table}>
        <thead>
          <tr>
            <th>Date</th>
            <th>Auteur</th>
            <th>Objet</th>
            <th>Action</th>
            <th>Détail</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((e) => (
            <tr key={e.id}>
              <td className={ui.muted}>{new Date(e.occurred_at).toLocaleString('fr-FR')}</td>
              <td>{e.actor_email ?? 'système'}</td>
              <td>
                {e.table_name === 'hymns' ? (
                  <Link href={`/cantiques/${e.record_id}`}>{TABLES[e.table_name]}</Link>
                ) : (
                  (TABLES[e.table_name] ?? e.table_name)
                )}
              </td>
              <td>{ACTIONS[e.action] ?? e.action}</td>
              <td>
                <details>
                  <summary>
                    {e.action === 'update' ? Object.keys(e.changes).join(', ') : 'voir'}
                  </summary>
                  <pre>{JSON.stringify(e.changes, null, 2)}</pre>
                </details>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {next && (
        <p>
          <Link
            className={ui.button}
            href={`/journal?${new URLSearchParams({ ...(objet ? { objet } : {}), avant: String(next) })}`}
          >
            Plus ancien ›
          </Link>
        </p>
      )}
    </>
  );
}
