import type { DraftIssue } from '@lad/shared-contracts';

import type { ImportResult } from './pipeline.ts';

const escape = (value: string): string =>
  value.replace(
    /[&<>"']/gu,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!,
  );

/** Libellés des codes d'anomalie (référence : IMPLEMENTATION_PLAN.md §3.3). */
export const ISSUE_LABELS: Record<string, string> = {
  'A-01': 'Numéros absents de la séquence',
  'A-02': 'Écart avec l’index alphabétique',
  'A-03': 'Régime de mise en forme',
  'A-04': 'Sauts de ligne manuels',
  'A-05': 'Section très longue',
  'A-06': 'Section d’un seul vers',
  'A-07': 'Refrain : forme incohérente',
  'A-08': 'Titre ≠ premier vers',
  'A-09': 'Marqueur de répétition non standard',
  'A-10': 'Parenthèse conservée comme texte',
  'A-11': 'Orthographe d’un livre biblique',
  'A-12': 'Texte en double ou proche',
  'A-15': 'Cantique sans vers',
  'A-16': 'Numérotation incohérente',
  'A-17': 'Paragraphe inattendu',
  'A-18': 'Référence non analysable',
  'A-19': 'Titre introuvable',
};

const SEVERITY_LABELS: Record<DraftIssue['severity'], string> = {
  blocking: 'Bloquant',
  warning: 'À vérifier',
  info: 'Information',
};

/** Rapport autonome (sans ressource externe), lisible hors connexion. */
export function renderReport(result: ImportResult): string {
  const { draft, stats, fidelity } = result;
  const order: DraftIssue['severity'][] = ['blocking', 'warning', 'info'];
  const issues = [...draft.issues].sort(
    (a, b) =>
      order.indexOf(a.severity) - order.indexOf(b.severity) ||
      a.code.localeCompare(b.code) ||
      (a.numberLabel ?? '').localeCompare(b.numberLabel ?? '', 'fr', { numeric: true }),
  );

  const rows = issues
    .map(
      (i) => `<tr class="${i.severity}">
  <td>${SEVERITY_LABELS[i.severity]}</td>
  <td>${escape(i.code)}<br><small>${escape(ISSUE_LABELS[i.code] ?? '')}</small></td>
  <td>${i.numberLabel ? `n° ${escape(i.numberLabel)}` : '—'}</td>
  <td>${escape(i.message)}${Object.keys(i.details).length ? `<pre>${escape(JSON.stringify(i.details, null, 1))}</pre>` : ''}</td>
</tr>`,
    )
    .join('\n');

  const fidelityText =
    fidelity.mismatches.length === 0 && fidelity.paragraphCountMatches
      ? `Conforme : ${fidelity.hymnsChecked} cantiques, aucun vers perdu, ajouté ou modifié.`
      : `NON CONFORME : ${fidelity.mismatches.length} cantique(s) en écart (${fidelity.mismatches
          .map((m) => m.numberLabel)
          .slice(0, 20)
          .join(', ')}).`;

  return `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rapport d'import</title>
<style>
  :root { --bg: #fff; --text: #1f1a17; --muted: #6b625b; --line: #ece8e2; --block: #9b2c2c; --warn: #8a6a35; }
  body { margin: 0 auto; max-width: 1100px; padding: 24px 16px; background: var(--bg); color: var(--text);
         font: 15px/1.5 system-ui, sans-serif; }
  h1 { font-family: Georgia, serif; font-weight: 600; }
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; vertical-align: top; padding: 8px; border-bottom: 1px solid var(--line); }
  td:first-child { white-space: nowrap; font-weight: 600; }
  tr.blocking td:first-child { color: var(--block); }
  tr.warning td:first-child { color: var(--warn); }
  tr.info td:first-child { color: var(--muted); }
  pre { margin: 4px 0 0; white-space: pre-wrap; font-size: 12px; color: var(--muted); }
  dl { display: grid; grid-template-columns: max-content 1fr; gap: 4px 16px; }
  dt { color: var(--muted); }
</style>
</head>
<body>
<h1>Rapport d'import — ${escape(draft.edition.name)}</h1>
<p>Toutes les détections ci-dessous sont automatiques et doivent être contrôlées par un éditeur.
Aucune donnée n'a été inventée : auteurs, thèmes et tonalités restent vides.</p>
<dl>
  <dt>Fichier source</dt><dd>${escape(draft.source.filename)}<br><small>SHA-256 ${draft.source.sha256}</small></dd>
  <dt>Version du parseur</dt><dd>${escape(draft.source.parserVersion)}</dd>
  <dt>Cantiques</dt><dd>${stats.hymns} (${stats.bisRelations} « bis »)</dd>
  <dt>Sections / vers</dt><dd>${stats.sections} / ${stats.lines} (refrain dans ${stats.refrains} cantiques)</dd>
  <dt>Références bibliques</dt><dd>${stats.bibleReferences}</dd>
  <dt>Fidélité au texte source</dt><dd>${escape(fidelityText)}</dd>
  <dt>Anomalies</dt><dd>${stats.issuesBySeverity.blocking ?? 0} bloquante(s), ${stats.issuesBySeverity.warning ?? 0} à vérifier, ${stats.issuesBySeverity.info ?? 0} information(s)</dd>
</dl>
<h2>Anomalies</h2>
<table>
<thead><tr><th>Gravité</th><th>Code</th><th>Cantique</th><th>Détail</th></tr></thead>
<tbody>
${rows}
</tbody>
</table>
</body>
</html>
`;
}
