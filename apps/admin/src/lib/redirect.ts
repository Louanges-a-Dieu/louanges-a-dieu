import { redirect } from 'next/navigation';

/** Retour à une page avec un message (?ok=… ou ?erreur=…), en conservant ses filtres. */
export function back(path: string, message: { ok?: string; erreur?: string }): never {
  const url = new URL(path, 'http://local');
  url.searchParams.delete('ok');
  url.searchParams.delete('erreur');
  if (message.ok) url.searchParams.set('ok', message.ok);
  if (message.erreur) url.searchParams.set('erreur', message.erreur);
  redirect(`${url.pathname}${url.search}`);
}

/** Message lisible d'une erreur Supabase/PostgREST (les nôtres sont en français). */
export function errorMessage(error: { message?: string } | null | undefined, fallback: string) {
  return error?.message?.trim() || fallback;
}
