import type { Metadata } from 'next';
import Link from 'next/link';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import { SEVERITY_LABELS, SeverityBadge } from '@/components/status';
import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { param } from '@/lib/data';

import { resolveIssuesAction } from './actions';

export const metadata: Metadata = { title: 'Anomalies — Administration' };

const STATUS = { open: 'Ouvertes', resolved: 'Résolues', ignored: 'Ignorées' } as const;

/** File d'anomalies (9.8). */
export default async function IssuesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireEditor();
  const statut = (param(sp.statut) ?? 'open') as keyof typeof STATUS;
  const gravite = param(sp.gravite);
  const code = param(sp.code);

  let query = supabase
    .from('import_issues')
    .select(
      'id, code, severity, message, details, status, resolution_note, hymn:hymns(id, number_label, title)',
      {
        count: 'exact',
      },
    )
    .eq('status', statut in STATUS ? statut : 'open')
    .order('severity', { ascending: false })
    .order('created_at')
    .limit(200);
  if (gravite) query = query.eq('severity', gravite);
  if (code) query = query.eq('code', code.toUpperCase());
  const { data, count, error } = await query;
  const retour = `/anomalies?${new URLSearchParams(
    Object.entries({ statut, gravite, code }).filter((e): e is [string, string] => !!e[1]),
  )}`;

  return (
    <>
      <h1 className={ui.h1}>Anomalies</h1>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur) ?? error?.message} />
      <form method="get" className={ui.row}>
        <select className={ui.select} name="statut" defaultValue={statut} aria-label="Statut">
          {Object.entries(STATUS).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </select>
        <select
          className={ui.select}
          name="gravite"
          defaultValue={gravite ?? ''}
          aria-label="Gravité"
        >
          <option value="">Toutes gravités</option>
          {Object.entries(SEVERITY_LABELS).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </select>
        <input
          className={ui.input}
          name="code"
          defaultValue={code}
          placeholder="Code (A-10)"
          aria-label="Code"
        />
        <button type="submit" className={ui.button}>
          Filtrer
        </button>
      </form>
      <p className={ui.muted}>
        {count ?? 0} anomalie{(count ?? 0) > 1 ? 's' : ''}
        {(count ?? 0) > 200 && ' (200 premières affichées)'}
      </p>

      <form action={resolveIssuesAction}>
        <input type="hidden" name="retour" value={retour} />
        {statut === 'open' && (
          <div className={ui.row}>
            <input
              className={ui.input}
              name="note"
              placeholder="Justification (obligatoire pour ignorer)"
              aria-label="Justification"
            />
            <SubmitButton name="status" value="resolved">
              Marquer la sélection résolue
            </SubmitButton>
            <SubmitButton name="status" value="ignored" variant="ghost">
              Ignorer la sélection
            </SubmitButton>
          </div>
        )}
        <table className={ui.table}>
          <thead>
            <tr>
              <th />
              <th>Gravité</th>
              <th>Code</th>
              <th>Cantique</th>
              <th>Message</th>
            </tr>
          </thead>
          <tbody>
            {(data ?? []).map((issue) => {
              const hymn = issue.hymn as unknown as {
                id: string;
                number_label: string;
                title: string;
              } | null;
              return (
                <tr key={issue.id}>
                  <td>
                    <input
                      type="checkbox"
                      name="ids"
                      value={issue.id}
                      aria-label={`Sélectionner ${issue.code}`}
                    />
                  </td>
                  <td>
                    <SeverityBadge severity={issue.severity} />
                  </td>
                  <td>
                    <code>{issue.code}</code>
                  </td>
                  <td>
                    {hymn ? (
                      <Link href={`/cantiques/${hymn.id}`}>
                        <span className={ui.number}>{hymn.number_label}</span> {hymn.title}
                      </Link>
                    ) : (
                      <span className={ui.muted}>Document</span>
                    )}
                  </td>
                  <td>
                    {issue.message}
                    {issue.resolution_note && (
                      <div className={ui.muted}>{issue.resolution_note}</div>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        {statut !== 'open' && (data ?? []).length > 0 && (
          <SubmitButton name="status" value="open" variant="ghost">
            Rouvrir la sélection
          </SubmitButton>
        )}
      </form>
    </>
  );
}
