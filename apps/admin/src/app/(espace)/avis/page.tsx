import type { Metadata } from 'next';
import Link from 'next/link';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { REVIEW_STATUS, stars } from '@/lib/community';
import { param } from '@/lib/data';

import { moderateReviewAction } from './actions';

export const metadata: Metadata = { title: 'Avis — Administration' };

interface ReviewRow {
  id: string;
  rating: number;
  body: string | null;
  reply: string | null;
  status: string;
  created_at: string;
  hymn: { id: string; number_label: string; title: string } | null;
}

/**
 * Avis des fidèles (planche 8, écran 11) : rien n'est public avant d'être
 * publié ici. Les auteurs ne sont jamais affichés (ni nom, ni adresse).
 */
export default async function ReviewsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const sp = await searchParams;
  const status = param(sp.statut) ?? 'pending';
  const filter = status in REVIEW_STATUS ? status : 'pending';
  const { supabase } = await requireEditor();
  const [{ data, error }, counts] = await Promise.all([
    supabase
      .from('hymn_comments')
      .select('id, rating, body, reply, status, created_at, hymn:hymns(id, number_label, title)')
      .eq('status', filter)
      .order('created_at', { ascending: filter === 'pending' })
      .limit(200),
    Promise.all(
      Object.keys(REVIEW_STATUS).map(async (s) => {
        const { count } = await supabase
          .from('hymn_comments')
          .select('id', { count: 'exact', head: true })
          .eq('status', s);
        return [s, count ?? 0] as const;
      }),
    ),
  ]);
  const reviews = (data ?? []) as unknown as ReviewRow[];
  const count = Object.fromEntries(counts);
  const retour = `/avis?statut=${filter}`;

  return (
    <>
      <h1 className={ui.h1}>Avis</h1>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur) ?? error?.message} />
      <p className={ui.hint}>
        Un avis n’est visible dans l’application qu’une fois publié. Son auteur n’est jamais
        affiché.
      </p>
      <nav className={ui.row} aria-label="Statut">
        {Object.entries(REVIEW_STATUS).map(([value, label]) => (
          <Link
            key={value}
            href={`/avis?statut=${value}`}
            className={value === filter ? ui.buttonPrimary : ui.button}
            aria-current={value === filter ? 'page' : undefined}
          >
            {label} ({count[value] ?? 0})
          </Link>
        ))}
      </nav>
      {reviews.length === 0 ? (
        <p className={ui.muted}>Aucun avis.</p>
      ) : (
        reviews.map((r) => (
          <section key={r.id} className={ui.card}>
            <p>
              {r.hymn && (
                <Link href={`/cantiques/${r.hymn.id}`}>
                  <span className={ui.number}>{r.hymn.number_label}</span> {r.hymn.title}
                </Link>
              )}{' '}
              <span aria-label={`${r.rating} sur 5`}>{stars(r.rating)}</span>{' '}
              <span className={ui.muted}>
                {new Date(r.created_at).toLocaleString('fr-FR', {
                  dateStyle: 'medium',
                  timeStyle: 'short',
                })}
              </span>
            </p>
            {r.body ? <p>{r.body}</p> : <p className={ui.muted}>Note sans commentaire.</p>}
            <form action={moderateReviewAction} className={ui.field}>
              <input type="hidden" name="id" value={r.id} />
              <input type="hidden" name="retour" value={retour} />
              <label className={ui.field}>
                <span className={ui.label}>Réponse de l’équipe (facultative, publique)</span>
                <textarea
                  className={ui.textarea}
                  name="reply"
                  maxLength={1000}
                  defaultValue={r.reply ?? ''}
                />
              </label>
              <div className={ui.row}>
                {r.status !== 'approved' && (
                  <SubmitButton variant="primary" name="status" value="approved">
                    Publier
                  </SubmitButton>
                )}
                {r.status === 'approved' && (
                  <SubmitButton variant="primary" name="status" value="approved">
                    Enregistrer la réponse
                  </SubmitButton>
                )}
                {r.status !== 'rejected' && (
                  <SubmitButton variant="danger" name="status" value="rejected">
                    Refuser
                  </SubmitButton>
                )}
                {r.status !== 'pending' && (
                  <SubmitButton variant="ghost" name="status" value="pending">
                    Remettre en attente
                  </SubmitButton>
                )}
              </div>
            </form>
          </section>
        ))
      )}
    </>
  );
}
