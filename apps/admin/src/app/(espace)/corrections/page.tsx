import type { Metadata } from 'next';
import Link from 'next/link';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import {
  KIND_HINTS,
  KIND_LABELS,
  KIND_ORDER,
  UNIT_LABELS,
  highlight,
  parseCorrection,
  type CorrectionDetails,
  type SuggestionKind,
} from '@/lib/corrections';
import { param } from '@/lib/data';

import { applyCorrectionAction, decideCorrectionAction } from './actions';
import styles from './corrections.module.css';

export const metadata: Metadata = { title: 'Corrections — Administration' };

const STATUS = { open: 'À traiter', resolved: 'Appliquées', ignored: 'Refusées' } as const;

interface Row {
  id: string;
  status: keyof typeof STATUS;
  resolution_note: string | null;
  resolved_at: string | null;
  hymn: { id: string; number_label: string; title: string } | null;
  details: CorrectionDetails;
}

function Source({ d }: { d: CorrectionDetails }) {
  const s = d.source;
  const where = [s.file, s.row ? `ligne ${s.row}` : null, s.number ? `ancien n° ${s.number}` : null]
    .filter(Boolean)
    .join(' · ');
  return (
    <div className={styles.source}>
      <p>
        <span className={ui.muted}>Tableur :</span> « {s.original} » → « {s.proposed} »
      </p>
      <p className={ui.muted}>
        {where}
        {s.problem && ` · ${s.problem}`}
        {s.confidence && ` · confiance : ${s.confidence}`}
      </p>
      {s.comment && <p className={ui.muted}>Commentaire : {s.comment}</p>}
    </div>
  );
}

function OpenCorrection({ row, retour }: { row: Row; retour: string }) {
  const d = row.details;
  return (
    <>
      {d.passages.length > 0 && (
        <form action={applyCorrectionAction} className={styles.passages}>
          <input type="hidden" name="id" value={row.id} />
          <input type="hidden" name="retour" value={retour} />
          {d.passages.map((p, i) => {
            const [before, match, after] = highlight(p.context, p.current);
            const label = `${UNIT_LABELS[p.unit]} — texte corrigé`;
            return (
              <div key={`${p.unit}-${p.sectionId}-${p.offset}-${i}`} className={styles.passage}>
                <p className={styles.unit}>{UNIT_LABELS[p.unit]}</p>
                <p className={styles.context}>
                  {before}
                  <mark>{match}</mark>
                  {after}
                </p>
                {p.replacement !== null && (
                  <p className={styles.change}>
                    <del>{p.current}</del> → <ins>{p.replacement}</ins>
                  </p>
                )}
                <label className={ui.field}>
                  <span className={ui.label}>{label}</span>
                  {p.unit === 'section' ? (
                    <textarea
                      className={ui.textarea}
                      name="remplacement"
                      rows={Math.max(1, (p.replacement ?? p.current).split('\n').length)}
                      defaultValue={p.replacement ?? p.current}
                    />
                  ) : (
                    <input
                      className={ui.input}
                      name="remplacement"
                      defaultValue={p.replacement ?? p.current}
                    />
                  )}
                </label>
              </div>
            );
          })}
          <SubmitButton variant="primary">
            {d.suggestion === 'pending' ? 'Appliquer la correction' : 'Appliquer ce texte'}
          </SubmitButton>
        </form>
      )}
      <form action={decideCorrectionAction} className={ui.row}>
        <input type="hidden" name="id" value={row.id} />
        <input type="hidden" name="retour" value={retour} />
        <input
          className={ui.input}
          name="note"
          placeholder="Pourquoi refuser ? (obligatoire)"
          aria-label="Motif du refus"
        />
        <SubmitButton name="status" value="ignored" variant="ghost">
          Refuser
        </SubmitButton>
        {d.suggestion === 'not_found' && (
          <SubmitButton name="status" value="resolved" variant="ghost">
            Corrigée à la main
          </SubmitButton>
        )}
      </form>
    </>
  );
}

function ClosedCorrection({ row }: { row: Row }) {
  const applied = row.details.applied ?? [];
  return (
    <div className={styles.passages}>
      {applied.map((a, i) => (
        <p key={i} className={styles.change}>
          <span className={ui.muted}>
            {UNIT_LABELS[a.unit as keyof typeof UNIT_LABELS] ?? a.unit} :
          </span>{' '}
          <del>{a.before}</del> → <ins>{a.after}</ins>
        </p>
      ))}
      <p className={ui.muted}>
        {row.resolution_note}
        {row.resolved_at && ` — ${new Date(row.resolved_at).toLocaleString('fr-FR')}`}
      </p>
    </div>
  );
}

/**
 * Propositions des tableurs de relecture (Q-04, A-13), à valider une par une.
 * Chargées par `content-tools corrections` ; rien n'est appliqué sans décision.
 */
export default async function CorrectionsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const { supabase } = await requireEditor();
  const statut = (param(sp.statut) ?? 'open') as keyof typeof STATUS;
  const status = statut in STATUS ? statut : 'open';
  const retour = `/corrections?statut=${status}`;

  const { data, error } = await supabase
    .from('import_issues')
    .select(
      'id, status, resolution_note, resolved_at, details, hymn:hymns(id, number_label, title)',
    )
    .eq('code', 'A-13')
    .eq('status', status)
    .order('created_at')
    .limit(500);

  const rows: Row[] = (data ?? []).flatMap((r) => {
    const details = parseCorrection(r.details);
    return details ? [{ ...r, details, hymn: r.hymn as unknown as Row['hymn'] } as Row] : [];
  });
  const groups = KIND_ORDER.map((kind) => ({
    kind,
    rows: rows.filter((r) => r.details.suggestion === kind),
  })).filter((g) => g.rows.length > 0);

  return (
    <>
      <h1 className={ui.h1}>Corrections proposées</h1>
      <p className={ui.hint}>
        Corrections linguistiques des tableurs de relecture, rapprochées du texte actuel par{' '}
        <code>content-tools corrections</code>. Rien n’est appliqué sans votre décision ; un
        cantique validé repasse en brouillon quand on le corrige.
      </p>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur) ?? error?.message} />
      <nav className={ui.row} aria-label="Statut">
        {Object.entries(STATUS).map(([v, l]) => (
          <Link
            key={v}
            href={`/corrections?statut=${v}`}
            className={v === status ? ui.buttonPrimary : ui.button}
            aria-current={v === status ? 'page' : undefined}
          >
            {l}
          </Link>
        ))}
      </nav>

      {rows.length === 0 && (
        <p className={ui.muted}>
          {status === 'open'
            ? 'Aucune proposition à traiter.'
            : `Aucune proposition ${STATUS[status].toLowerCase()}.`}
        </p>
      )}

      {groups.map(({ kind, rows: list }) => (
        <section key={kind} aria-labelledby={`groupe-${kind}`}>
          <h2 className={ui.h2} id={`groupe-${kind}`}>
            {KIND_LABELS[kind as SuggestionKind]} ({list.length})
          </h2>
          {status === 'open' && <p className={ui.hint}>{KIND_HINTS[kind as SuggestionKind]}</p>}
          {list.map((row) => (
            <article key={row.id} className={ui.card}>
              <h3 className={styles.title}>
                {row.hymn ? (
                  <Link href={`/cantiques/${row.hymn.id}`}>
                    <span className={ui.number}>{row.hymn.number_label}</span> {row.hymn.title}
                  </Link>
                ) : (
                  <span className={ui.muted}>Cantique non identifié</span>
                )}
              </h3>
              <Source d={row.details} />
              {status === 'open' ? (
                <OpenCorrection row={row} retour={retour} />
              ) : (
                <ClosedCorrection row={row} />
              )}
            </article>
          ))}
        </section>
      ))}
    </>
  );
}
