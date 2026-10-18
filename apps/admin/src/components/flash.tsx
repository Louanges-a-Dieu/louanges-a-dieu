import ui from './ui.module.css';

/** Message de résultat transmis par l'adresse (?ok=… ou ?erreur=…) après une action. */
export function Flash({ ok, erreur }: { ok?: string; erreur?: string }) {
  if (erreur) {
    return (
      <p className={ui.error} role="alert">
        {erreur}
      </p>
    );
  }
  if (ok) {
    return (
      <p className={ui.ok} role="status">
        {ok}
      </p>
    );
  }
  return null;
}
