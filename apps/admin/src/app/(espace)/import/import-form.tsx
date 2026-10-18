'use client';

import { useActionState, useState } from 'react';

import { SubmitButton } from '@/components/buttons';
import { SEVERITY_LABELS } from '@/components/status';
import ui from '@/components/ui.module.css';

import { importAction, type ImportReport } from './actions';

function Labels({ title, labels }: { title: string; labels: string[] }) {
  if (labels.length === 0) return null;
  return (
    <details>
      <summary>
        {title} : {labels.length}
      </summary>
      <p>
        {labels.slice(0, 200).join(', ')}
        {labels.length > 200 && ` … (+${labels.length - 200})`}
      </p>
    </details>
  );
}

/** Import : le fichier est lu dans le navigateur, simulé puis importé. */
export function ImportForm() {
  const [draft, setDraft] = useState('');
  const [fileName, setFileName] = useState('');
  const [report, action] = useActionState<ImportReport, FormData>(importAction, {});
  const s = report.summary;
  const nothingNew =
    s && s.inserted.length === 0 && s.changed.length === 0 && s.missingFromSource.length === 0;

  return (
    <>
      <label className={ui.field}>
        <span className={ui.label}>
          Catalogue brouillon (catalog.draft.json produit par content-tools)
        </span>
        <input
          className={ui.input}
          type="file"
          accept="application/json,.json"
          onChange={async (event) => {
            const file = event.target.files?.[0];
            setFileName(file?.name ?? '');
            setDraft(file ? await file.text() : '');
          }}
        />
      </label>

      <form action={action}>
        <input type="hidden" name="draft" value={draft} />
        <input type="hidden" name="fileName" value={fileName} />
        <div className={ui.row}>
          <SubmitButton name="mode" value="simulate" disabled={!draft}>
            Simuler l’import
          </SubmitButton>
          {report.dryRun && s && !nothingNew && report.fileName === fileName && (
            <SubmitButton
              name="mode"
              value="import"
              variant="primary"
              confirm="Importer ce catalogue ? Les nouveaux cantiques arriveront en brouillon ; rien d’existant ne sera écrasé."
            >
              Importer
            </SubmitButton>
          )}
        </div>
      </form>

      {report.errors && (
        <div className={ui.error} role="alert">
          {report.errors.join('\n')}
        </div>
      )}

      {s && (
        <section className={ui.card} aria-live="polite">
          <h2 className={ui.h2}>
            {report.dryRun ? 'Simulation' : 'Import terminé'} — {report.fileName}
          </h2>
          <p>
            Édition : {report.edition}
            {s.editionCreated && ' (nouvelle)'}
          </p>
          <ul>
            <li>{s.inserted.length} nouveau(x) cantique(s), importé(s) en brouillon</li>
            <li>{s.unchanged.length} inchangé(s)</li>
            <li>
              {s.changed.length} au texte différent : jamais écrasé(s), anomalie A-20 à arbitrer
            </li>
            <li>{s.missingFromSource.length} absent(s) de ce fichier : anomalie A-21</li>
          </ul>
          <Labels title="Nouveaux" labels={s.inserted} />
          <Labels title="Texte différent" labels={s.changed} />
          <Labels title="Absents du fichier" labels={s.missingFromSource} />
          {report.issuesBySeverity && Object.keys(report.issuesBySeverity).length > 0 && (
            <p>
              Anomalies signalées par l’extraction :{' '}
              {Object.entries(report.issuesBySeverity)
                .map(([k, n]) => `${n} ${SEVERITY_LABELS[k]?.toLowerCase() ?? k}`)
                .join(', ')}
            </p>
          )}
          {nothingNew && <p>Rien de nouveau : cet import ne changerait rien.</p>}
          {!report.dryRun && (
            <p className={ui.ok}>{s.issuesCreated} anomalie(s) créée(s) dans la file.</p>
          )}
        </section>
      )}
    </>
  );
}
