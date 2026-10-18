export interface Transition {
  to: 'draft' | 'review' | 'published' | 'archived';
  label: string;
  primary?: boolean;
  confirm?: string;
}

/** Transitions proposées à l'écran (la base vérifie tout, y compris l'archivage super_admin). */
export function transitions(status: string, superAdmin: boolean): Transition[] {
  const t: Transition[] = [];
  if (status === 'draft') t.push({ to: 'review', label: 'Soumettre en relecture', primary: true });
  if (status === 'review') {
    t.push({
      to: 'published',
      label: 'Valider',
      primary: true,
      confirm: 'Valider ce cantique ? Il sera inclus dans la prochaine publication.',
    });
    t.push({ to: 'draft', label: 'Renvoyer en brouillon' });
  }
  if (status === 'published') t.push({ to: 'draft', label: 'Repasser en brouillon' });
  if (superAdmin && status !== 'archived') {
    t.push({
      to: 'archived',
      label: 'Archiver',
      confirm: 'Archiver ce cantique ? Il sera retiré du recueil à la prochaine publication.',
    });
  }
  if (superAdmin && status === 'archived') t.push({ to: 'draft', label: 'Restaurer en brouillon' });
  return t;
}
