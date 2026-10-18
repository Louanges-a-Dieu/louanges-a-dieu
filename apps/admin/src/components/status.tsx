import ui from './ui.module.css';

export const STATUS_LABELS: Record<string, string> = {
  draft: 'Brouillon',
  review: 'En relecture',
  published: 'Validé',
  archived: 'Archivé',
};

export const RIGHTS_LABELS: Record<string, string> = {
  unknown: 'Inconnu',
  pending: 'En cours',
  cleared: 'Autorisé',
  restricted: 'Restreint',
  public_domain: 'Domaine public',
};

export const SEVERITY_LABELS: Record<string, string> = {
  info: 'Information',
  warning: 'Avertissement',
  blocking: 'Bloquante',
};

export function StatusBadge({ status }: { status: string }) {
  const tone = (ui as Record<string, string | undefined>)[status];
  return <span className={`${ui.badge} ${tone ?? ''}`}>{STATUS_LABELS[status] ?? status}</span>;
}

export function SeverityBadge({ severity }: { severity: string }) {
  const tone =
    severity === 'blocking' ? ui.blocking : severity === 'warning' ? ui.warning : ui.draft;
  return <span className={`${ui.badge} ${tone}`}>{SEVERITY_LABELS[severity] ?? severity}</span>;
}
