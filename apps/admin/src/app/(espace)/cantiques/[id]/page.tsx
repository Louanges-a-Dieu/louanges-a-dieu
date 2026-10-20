import type { PublishedHymn } from '@lad/shared-contracts';
import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import { SubmitButton } from '@/components/buttons';
import { Flash } from '@/components/flash';
import { HymnPreview } from '@/components/hymn-preview';
import { KaraokeSync } from '@/components/karaoke-sync';
import { RIGHTS_LABELS, SeverityBadge, StatusBadge } from '@/components/status';
import ui from '@/components/ui.module.css';
import { requireEditor } from '@/lib/auth';
import { param } from '@/lib/data';
import { MEDIA_LABELS, audioUrl, formatClock, formatSegments, syncLines } from '@/lib/audio';
import { sectionName } from '@/lib/text';
import { transitions } from '@/lib/transitions';

import { resolveIssuesAction } from '../../anomalies/actions';
import {
  addPersonAction,
  addReferenceAction,
  addRelationAction,
  addThemeAction,
  addRightsAction,
  addAudioTrackAction,
  deleteAudioTrackAction,
  saveAudioCuesAction,
  saveAudioSegmentsAction,
  updateAudioTrackAction,
  deletePersonAction,
  deleteReferenceAction,
  deleteRelationAction,
  deleteSectionAction,
  moveSectionAction,
  saveSectionAction,
  deleteThemeAction,
  setStatusAction,
  updateMetadataAction,
} from './actions';
import styles from './editor.module.css';

export const metadata: Metadata = { title: 'Cantique — Administration' };

const SECTION_TYPES = ['verse', 'refrain', 'bridge', 'intro', 'outro', 'note'] as const;
const PERSON_ROLES: Record<string, string> = {
  author: 'Auteur',
  composer: 'Compositeur',
  translator: 'Traducteur',
  arranger: 'Arrangeur',
};
const RELATION_LABELS: Record<string, string> = {
  bis_of: '« bis » de',
  same_melody: 'Même mélodie que',
  variant: 'Variante de',
  related: 'En lien avec',
};

export default async function HymnEditorPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const [{ id }, sp] = await Promise.all([params, searchParams]);
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const editor = await requireEditor();
  const { supabase } = editor;

  const [
    hymnRes,
    sections,
    references,
    relations,
    rights,
    effective,
    issues,
    preview,
    history,
    people,
    themes,
    allPeople,
    allThemes,
    audio,
  ] = await Promise.all([
    supabase.from('hymns').select('*').eq('id', id).maybeSingle(),
    supabase.from('hymn_sections').select('*').eq('hymn_id', id).order('display_order'),
    supabase.from('bible_references').select('*').eq('hymn_id', id).order('chapter_start'),
    supabase
      .from('hymn_relations')
      .select(
        'related_hymn_id, relation, notes, related:hymns!hymn_relations_related_hymn_id_fkey(number_label, title)',
      )
      .eq('hymn_id', id),
    supabase
      .from('rights_records')
      .select('*')
      .eq('hymn_id', id)
      .is('media_id', null)
      .order('created_at', { ascending: false }),
    supabase.from('hymn_rights').select('rights_status').eq('hymn_id', id).maybeSingle(),
    supabase
      .from('import_issues')
      .select('id, code, severity, message, status, resolution_note, created_at')
      .eq('hymn_id', id)
      .order('created_at', { ascending: false }),
    supabase.rpc('preview_hymn', { p_hymn_id: id }),
    supabase.rpc('admin_audit_log', { p_record_id: id, p_limit: 15 }),
    supabase
      .from('hymn_people')
      .select('person_id, role, person:people(full_name)')
      .eq('hymn_id', id),
    supabase.from('hymn_themes').select('theme_id, theme:themes(name)').eq('hymn_id', id),
    supabase.from('people').select('full_name').order('full_name').limit(500),
    supabase.from('themes').select('name').order('name').limit(500),
    supabase
      .from('audio_tracks')
      .select(
        'id, media_type, storage_key, duration_seconds, rights_status, segments:audio_segments(section_id, line_index, start_ms, end_ms, display_order)',
      )
      .eq('hymn_id', id)
      .order('created_at'),
  ]);
  const hymn = hymnRes.data;
  if (!hymn) notFound();
  const here = `/cantiques/${id}`;
  const rightsStatus = effective.data?.rights_status ?? 'unknown';
  const karaokeLines = preview.data ? syncLines((preview.data as PublishedHymn).sections) : [];

  return (
    <>
      <p className={ui.muted}>
        <Link href="/cantiques">‹ Cantiques</Link>
      </p>
      <div className={styles.header}>
        <h1 className={ui.h1}>
          <span className={ui.number}>{hymn.number_label}</span> {hymn.title}
        </h1>
        <StatusBadge status={hymn.status} />
      </div>
      <Flash ok={param(sp.ok)} erreur={param(sp.erreur)} />
      {hymn.status === 'published' && (
        <p className={ui.hint}>
          Toute modification repasse ce cantique en brouillon ; la version publiée reste servie aux
          applications jusqu’à sa nouvelle validation et la prochaine publication.
        </p>
      )}

      <div className={styles.layout}>
        <div>
          {/* ---------------------------------------------------------- statut */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Statut</h2>
            <div className={ui.row}>
              {transitions(hymn.status, editor.isSuperAdmin).map((t) => (
                <form key={t.to} action={setStatusAction}>
                  <input type="hidden" name="id" value={id} />
                  <SubmitButton
                    name="status"
                    value={t.to}
                    variant={t.primary ? 'primary' : t.to === 'archived' ? 'danger' : 'default'}
                    confirm={t.confirm}
                  >
                    {t.label}
                  </SubmitButton>
                </form>
              ))}
            </div>
            {hymn.validated_at && (
              <p className={ui.muted}>
                Validé le {new Date(hymn.validated_at).toLocaleString('fr-FR')}
              </p>
            )}
          </section>

          {/* ----------------------------------------------------- métadonnées */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Informations</h2>
            <form action={updateMetadataAction}>
              <input type="hidden" name="id" value={id} />
              <label className={ui.field}>
                <span className={ui.label}>Titre</span>
                <input className={ui.input} name="title" defaultValue={hymn.title} required />
              </label>
              <label className={ui.field}>
                <span className={ui.label}>Premier vers (laisser vide si inconnu)</span>
                <input
                  className={ui.input}
                  name="opening_line"
                  defaultValue={hymn.opening_line ?? ''}
                />
              </label>
              <label className={ui.field}>
                <span className={ui.label}>Notes éditoriales (internes, jamais publiées)</span>
                <textarea
                  className={ui.input}
                  name="editorial_notes"
                  rows={3}
                  defaultValue={hymn.editorial_notes ?? ''}
                />
              </label>
              <SubmitButton variant="primary">Enregistrer</SubmitButton>
            </form>
          </section>

          {/* -------------------------------------------------------- sections */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Sections</h2>
            <p className={ui.hint}>
              Un vers par ligne, texte tel qu’imprimé. Répétitions : écrire « (bis) », « (ter) » ou
              « (4x) » en fin de vers ; l’aperçu indique ce qui est reconnu.
            </p>
            {(sections.data ?? []).map((s, i, all) => (
              <div key={s.id} className={styles.section}>
                <form action={saveSectionAction}>
                  <input type="hidden" name="hymn_id" value={id} />
                  <input type="hidden" name="section_id" value={s.id} />
                  <div className={styles.sectionHead}>
                    <strong>{sectionName(s.section_type, s.section_number)}</strong>
                    <select
                      className={ui.select}
                      name="section_type"
                      defaultValue={s.section_type}
                      aria-label="Type de section"
                    >
                      {SECTION_TYPES.map((t) => (
                        <option key={t} value={t}>
                          {sectionName(t, null)}
                        </option>
                      ))}
                    </select>
                    <input
                      className={ui.input}
                      name="section_number"
                      inputMode="numeric"
                      defaultValue={s.section_number ?? ''}
                      placeholder="N°"
                      aria-label="Numéro de la section"
                    />
                  </div>
                  <textarea
                    className={ui.textarea}
                    name="text"
                    defaultValue={s.text}
                    rows={Math.max(3, s.text.split('\n').length + 1)}
                    aria-label={`Texte : ${sectionName(s.section_type, s.section_number)}`}
                    required
                  />
                  <div className={ui.row}>
                    <SubmitButton>Enregistrer la section</SubmitButton>
                  </div>
                </form>
                <div className={ui.row}>
                  <form action={moveSectionAction}>
                    <input type="hidden" name="hymn_id" value={id} />
                    <input type="hidden" name="section_id" value={s.id} />
                    <SubmitButton variant="ghost" name="direction" value="up" disabled={i === 0}>
                      ↑ Monter
                    </SubmitButton>
                    <SubmitButton
                      variant="ghost"
                      name="direction"
                      value="down"
                      disabled={i === all.length - 1}
                    >
                      ↓ Descendre
                    </SubmitButton>
                  </form>
                  <form action={deleteSectionAction}>
                    <input type="hidden" name="hymn_id" value={id} />
                    <input type="hidden" name="section_id" value={s.id} />
                    <SubmitButton variant="ghost" confirm="Supprimer cette section ?">
                      Supprimer
                    </SubmitButton>
                  </form>
                </div>
              </div>
            ))}
            <details className={styles.add}>
              <summary>Ajouter une section</summary>
              <form action={saveSectionAction}>
                <input type="hidden" name="hymn_id" value={id} />
                <div className={styles.sectionHead}>
                  <select
                    className={ui.select}
                    name="section_type"
                    defaultValue="verse"
                    aria-label="Type"
                  >
                    {SECTION_TYPES.map((t) => (
                      <option key={t} value={t}>
                        {sectionName(t, null)}
                      </option>
                    ))}
                  </select>
                  <input
                    className={ui.input}
                    name="section_number"
                    inputMode="numeric"
                    placeholder="N°"
                    aria-label="Numéro"
                  />
                </div>
                <textarea
                  className={ui.textarea}
                  name="text"
                  required
                  aria-label="Texte de la nouvelle section"
                />
                <SubmitButton variant="primary">Ajouter</SubmitButton>
              </form>
            </details>
          </section>

          {/* ------------------------------------------------- auteurs, thèmes */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Auteurs et thèmes</h2>
            <p className={ui.hint}>
              À renseigner seulement quand l’information est sûre ; sinon, laisser vide.
            </p>
            <ul className={styles.list}>
              {(people.data ?? []).map((p) => {
                const person = p.person as unknown as { full_name: string } | null;
                return (
                  <li key={`${p.person_id}-${p.role}`}>
                    {person?.full_name}{' '}
                    <span className={ui.muted}>({PERSON_ROLES[p.role] ?? p.role})</span>
                    <form action={deletePersonAction}>
                      <input type="hidden" name="hymn_id" value={id} />
                      <input type="hidden" name="person_id" value={p.person_id} />
                      <input type="hidden" name="role" value={p.role} />
                      <SubmitButton variant="ghost" confirm="Retirer cette personne ?">
                        Retirer
                      </SubmitButton>
                    </form>
                  </li>
                );
              })}
              {(themes.data ?? []).map((t) => {
                const theme = t.theme as unknown as { name: string } | null;
                return (
                  <li key={t.theme_id}>
                    Thème : {theme?.name}
                    <form action={deleteThemeAction}>
                      <input type="hidden" name="hymn_id" value={id} />
                      <input type="hidden" name="theme_id" value={t.theme_id} />
                      <SubmitButton variant="ghost" confirm="Retirer ce thème ?">
                        Retirer
                      </SubmitButton>
                    </form>
                  </li>
                );
              })}
            </ul>
            <datalist id="personnes">
              {(allPeople.data ?? []).map((p) => (
                <option key={p.full_name} value={p.full_name} />
              ))}
            </datalist>
            <datalist id="themes">
              {(allThemes.data ?? []).map((t) => (
                <option key={t.name} value={t.name} />
              ))}
            </datalist>
            <details className={styles.add}>
              <summary>Ajouter une personne</summary>
              <form action={addPersonAction} className={styles.grid}>
                <input type="hidden" name="hymn_id" value={id} />
                <label className={ui.field}>
                  <span className={ui.label}>Nom complet</span>
                  <input className={ui.input} name="full_name" list="personnes" required />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Rôle</span>
                  <select className={ui.select} name="role" defaultValue="author">
                    {Object.entries(PERSON_ROLES).map(([v, l]) => (
                      <option key={v} value={v}>
                        {l}
                      </option>
                    ))}
                  </select>
                </label>
                <SubmitButton variant="primary">Ajouter</SubmitButton>
              </form>
            </details>
            <details className={styles.add}>
              <summary>Ajouter un thème</summary>
              <form action={addThemeAction} className={styles.grid}>
                <input type="hidden" name="hymn_id" value={id} />
                <label className={ui.field}>
                  <span className={ui.label}>Thème</span>
                  <input className={ui.input} name="name" list="themes" required />
                </label>
                <SubmitButton variant="primary">Ajouter</SubmitButton>
              </form>
            </details>
          </section>

          {/* ------------------------------------------------------ références */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Références bibliques</h2>
            {(references.data ?? []).length === 0 && <p className={ui.muted}>Aucune.</p>}
            <ul className={styles.list}>
              {(references.data ?? []).map((r) => (
                <li key={r.id}>
                  {r.display_text ?? `${r.book} ${r.chapter_start}`}
                  <form action={deleteReferenceAction}>
                    <input type="hidden" name="hymn_id" value={id} />
                    <input type="hidden" name="reference_id" value={r.id} />
                    <SubmitButton variant="ghost" confirm="Supprimer cette référence ?">
                      Supprimer
                    </SubmitButton>
                  </form>
                </li>
              ))}
            </ul>
            <details className={styles.add}>
              <summary>Ajouter une référence</summary>
              <form action={addReferenceAction} className={styles.grid}>
                <input type="hidden" name="hymn_id" value={id} />
                <label className={ui.field}>
                  <span className={ui.label}>Livre</span>
                  <input className={ui.input} name="book" required />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Chapitre</span>
                  <input className={ui.input} name="chapter_start" inputMode="numeric" required />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Verset</span>
                  <input className={ui.input} name="verse_start" inputMode="numeric" />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Jusqu’au chapitre</span>
                  <input className={ui.input} name="chapter_end" inputMode="numeric" />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Jusqu’au verset</span>
                  <input className={ui.input} name="verse_end" inputMode="numeric" />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Texte affiché (tel qu’imprimé)</span>
                  <input className={ui.input} name="display_text" />
                </label>
                <SubmitButton variant="primary">Ajouter</SubmitButton>
              </form>
            </details>
          </section>

          {/* ------------------------------------------------------- relations */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Cantiques liés</h2>
            {(relations.data ?? []).length === 0 && <p className={ui.muted}>Aucun.</p>}
            <ul className={styles.list}>
              {(relations.data ?? []).map((r) => {
                const related = r.related as unknown as {
                  number_label: string;
                  title: string;
                } | null;
                return (
                  <li key={`${r.related_hymn_id}-${r.relation}`}>
                    {RELATION_LABELS[r.relation] ?? r.relation}{' '}
                    <Link href={`/cantiques/${r.related_hymn_id}`}>
                      {related?.number_label} — {related?.title}
                    </Link>
                    <form action={deleteRelationAction}>
                      <input type="hidden" name="hymn_id" value={id} />
                      <input type="hidden" name="related_hymn_id" value={r.related_hymn_id} />
                      <input type="hidden" name="relation" value={r.relation} />
                      <SubmitButton variant="ghost" confirm="Supprimer ce lien ?">
                        Supprimer
                      </SubmitButton>
                    </form>
                  </li>
                );
              })}
            </ul>
            <details className={styles.add}>
              <summary>Ajouter un lien</summary>
              <form action={addRelationAction} className={styles.grid}>
                <input type="hidden" name="hymn_id" value={id} />
                <label className={ui.field}>
                  <span className={ui.label}>Type</span>
                  <select className={ui.select} name="relation" defaultValue="same_melody">
                    {Object.entries(RELATION_LABELS).map(([v, l]) => (
                      <option key={v} value={v}>
                        {l}
                      </option>
                    ))}
                  </select>
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Numéro du cantique</span>
                  <input className={ui.input} name="related_label" placeholder="37bis" required />
                </label>
                <SubmitButton variant="primary">Ajouter</SubmitButton>
              </form>
            </details>
          </section>

          {/* ------------------------------------------------ enregistrements */}
          <section className={ui.card} id="audio">
            <h2 className={ui.h2}>Enregistrements audio</h2>
            <p className={ui.hint}>
              Déposer d’abord le fichier sur Backblaze B2, puis indiquer ici son chemin dans le
              compartiment (par exemple <code>cantiques/0037bis/melodie.mp3</code>). Un
              enregistrement est diffusé à la prochaine publication, sans repasser le cantique en
              brouillon ; un enregistrement aux droits « Restreint » n’est jamais diffusé.
            </p>
            {(audio.data ?? []).length === 0 && <p className={ui.muted}>Aucun.</p>}
            {(audio.data ?? []).map((track) => {
              const segments = [...(track.segments ?? [])].sort(
                (a, b) => a.display_order - b.display_order,
              );
              const url = audioUrl(track.storage_key);
              const label = MEDIA_LABELS[track.media_type] ?? track.media_type;
              const lineCues = segments.filter((g) => g.line_index != null).length;
              return (
                <div key={track.id} className={styles.section}>
                  <div className={styles.sectionHead}>
                    <strong>{label}</strong>
                    <code>{track.storage_key}</code>
                    {track.rights_status === 'restricted' && (
                      <span className={ui.muted}>— non diffusé (droits restreints)</span>
                    )}
                  </div>
                  {url ? (
                    <audio
                      controls
                      preload="none"
                      src={url}
                      className={styles.audio}
                      aria-label={`Écouter : ${label}`}
                    />
                  ) : (
                    <p className={ui.muted}>
                      Écoute ici indisponible : adresse des enregistrements (AUDIO_BASE_URL) non
                      configurée.
                    </p>
                  )}
                  <form action={updateAudioTrackAction} className={styles.grid}>
                    <input type="hidden" name="hymn_id" value={id} />
                    <input type="hidden" name="track_id" value={track.id} />
                    <label className={ui.field}>
                      <span className={ui.label}>Version</span>
                      <select
                        className={ui.select}
                        name="media_type"
                        defaultValue={track.media_type}
                      >
                        {Object.entries(MEDIA_LABELS).map(([v, l]) => (
                          <option key={v} value={v}>
                            {l}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className={ui.field}>
                      <span className={ui.label}>Durée (facultative)</span>
                      <input
                        className={ui.input}
                        name="duration"
                        placeholder="3:05"
                        defaultValue={
                          track.duration_seconds == null
                            ? ''
                            : formatClock(Math.round(Number(track.duration_seconds) * 1000))
                        }
                      />
                    </label>
                    <label className={ui.field}>
                      <span className={ui.label}>Droits</span>
                      <select
                        className={ui.select}
                        name="rights_status"
                        defaultValue={track.rights_status}
                      >
                        {Object.entries(RIGHTS_LABELS).map(([v, l]) => (
                          <option key={v} value={v}>
                            {l}
                          </option>
                        ))}
                      </select>
                    </label>
                    <SubmitButton>Enregistrer</SubmitButton>
                  </form>
                  {lineCues > 0 ? (
                    <form action={saveAudioSegmentsAction} className={ui.row}>
                      <input type="hidden" name="hymn_id" value={id} />
                      <input type="hidden" name="track_id" value={track.id} />
                      <input type="hidden" name="segments" value="" />
                      <span>
                        Karaoké : <strong>{lineCues} vers synchronisés</strong>.
                      </span>
                      <SubmitButton
                        variant="ghost"
                        confirm="Effacer la synchronisation karaoké de cet enregistrement ?"
                      >
                        Effacer
                      </SubmitButton>
                    </form>
                  ) : (
                    <details className={styles.add}>
                      <summary>
                        Passages ({segments.length === 0 ? 'non repérés' : segments.length})
                      </summary>
                      <p className={ui.hint}>
                        Une ligne par début de passage : temps puis section (« Couplet 2 », «
                        Refrain », ou « #3 » pour la 3ᵉ section imprimée ; « - » pour un passage
                        sans paroles). Dernière ligne : la fin, par exemple « 2:10 fin ».
                        L’application met alors en avant les paroles chantées. Vider le texte pour
                        retirer les passages.
                      </p>
                      <form action={saveAudioSegmentsAction}>
                        <input type="hidden" name="hymn_id" value={id} />
                        <input type="hidden" name="track_id" value={track.id} />
                        <textarea
                          className={ui.textarea}
                          name="segments"
                          rows={Math.max(4, segments.length + 2)}
                          defaultValue={formatSegments(segments, sections.data ?? [])}
                          placeholder={'0:00 Couplet 1\n0:32 Refrain\n1:05 fin'}
                          aria-label={`Passages : ${label}`}
                        />
                        <SubmitButton>Enregistrer les passages</SubmitButton>
                      </form>
                    </details>
                  )}
                  <details className={styles.add}>
                    <summary>
                      Karaoké : {lineCues > 0 ? 'resynchroniser' : 'synchroniser'} vers par vers
                    </summary>
                    {url && karaokeLines.length > 0 ? (
                      <KaraokeSync
                        src={url}
                        lines={karaokeLines}
                        hymnId={id}
                        trackId={track.id}
                        action={saveAudioCuesAction}
                      />
                    ) : (
                      <p className={ui.muted}>
                        Indisponible : adresse des enregistrements (AUDIO_BASE_URL) non configurée.
                      </p>
                    )}
                  </details>
                  <form action={deleteAudioTrackAction}>
                    <input type="hidden" name="hymn_id" value={id} />
                    <input type="hidden" name="track_id" value={track.id} />
                    <SubmitButton
                      variant="ghost"
                      confirm="Retirer cet enregistrement du cantique ? Le fichier reste sur Backblaze."
                    >
                      Retirer
                    </SubmitButton>
                  </form>
                </div>
              );
            })}
            <details className={styles.add}>
              <summary>Ajouter un enregistrement</summary>
              <form action={addAudioTrackAction} className={styles.grid}>
                <input type="hidden" name="hymn_id" value={id} />
                <label className={ui.field}>
                  <span className={ui.label}>Chemin du fichier</span>
                  <input
                    className={ui.input}
                    name="storage_key"
                    placeholder="cantiques/0037bis/melodie.mp3"
                    required
                  />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Version</span>
                  <select className={ui.select} name="media_type" defaultValue="melody">
                    {Object.entries(MEDIA_LABELS).map(([v, l]) => (
                      <option key={v} value={v}>
                        {l}
                      </option>
                    ))}
                  </select>
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Durée (facultative)</span>
                  <input className={ui.input} name="duration" placeholder="3:05" />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Droits</span>
                  <select className={ui.select} name="rights_status" defaultValue="unknown">
                    {Object.entries(RIGHTS_LABELS).map(([v, l]) => (
                      <option key={v} value={v}>
                        {l}
                      </option>
                    ))}
                  </select>
                </label>
                <SubmitButton variant="primary">Ajouter</SubmitButton>
              </form>
            </details>
          </section>

          {/* ---------------------------------------------------------- droits */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Droits</h2>
            <p>
              Statut effectif : <strong>{RIGHTS_LABELS[rightsStatus] ?? rightsStatus}</strong>
              {rightsStatus === 'restricted' && (
                <span className={ui.muted}> — ce cantique ne peut être ni validé ni publié.</span>
              )}
            </p>
            {(rights.data ?? []).length > 0 && (
              <table className={ui.table}>
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Statut</th>
                    <th>Détenteur</th>
                    <th>Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {(rights.data ?? []).map((r) => (
                    <tr key={r.id}>
                      <td>{new Date(r.created_at).toLocaleDateString('fr-FR')}</td>
                      <td>{RIGHTS_LABELS[r.rights_status] ?? r.rights_status}</td>
                      <td>{r.rights_holder ?? '—'}</td>
                      <td>
                        {r.notes ?? ''}
                        {r.valid_until && <div className={ui.muted}>Jusqu’au {r.valid_until}</div>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            <details className={styles.add}>
              <summary>Nouvel enregistrement de droits</summary>
              <form action={addRightsAction} className={styles.grid}>
                <input type="hidden" name="hymn_id" value={id} />
                <label className={ui.field}>
                  <span className={ui.label}>Statut</span>
                  <select className={ui.select} name="rights_status" defaultValue={rightsStatus}>
                    {Object.entries(RIGHTS_LABELS).map(([v, l]) => (
                      <option key={v} value={v}>
                        {l}
                      </option>
                    ))}
                  </select>
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Détenteur des droits</span>
                  <input className={ui.input} name="rights_holder" />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Licence</span>
                  <input className={ui.input} name="license_type" />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Valable jusqu’au</span>
                  <input className={ui.input} name="valid_until" type="date" />
                </label>
                <label className={ui.field}>
                  <span className={ui.label}>Notes</span>
                  <input className={ui.input} name="notes" />
                </label>
                <SubmitButton variant="primary">Enregistrer</SubmitButton>
              </form>
            </details>
          </section>

          {/* ------------------------------------------------------- anomalies */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Anomalies</h2>
            {(issues.data ?? []).length === 0 && <p className={ui.muted}>Aucune.</p>}
            {(issues.data ?? []).map((issue) => (
              <div key={issue.id} className={styles.issue}>
                <div className={ui.row}>
                  <SeverityBadge severity={issue.severity} />
                  <code>{issue.code}</code>
                  <span>{issue.message}</span>
                  {issue.status !== 'open' && (
                    <span className={ui.muted}>
                      ({issue.status === 'resolved' ? 'résolue' : 'ignorée'}
                      {issue.resolution_note ? ` : ${issue.resolution_note}` : ''})
                    </span>
                  )}
                </div>
                <form action={resolveIssuesAction} className={ui.row}>
                  <input type="hidden" name="ids" value={issue.id} />
                  <input type="hidden" name="retour" value={here} />
                  {issue.status === 'open' ? (
                    <>
                      <input
                        className={ui.input}
                        name="note"
                        placeholder="Justification"
                        aria-label="Justification"
                      />
                      <SubmitButton name="status" value="resolved">
                        Résolue
                      </SubmitButton>
                      <SubmitButton name="status" value="ignored" variant="ghost">
                        Ignorer
                      </SubmitButton>
                    </>
                  ) : (
                    <SubmitButton name="status" value="open" variant="ghost">
                      Rouvrir
                    </SubmitButton>
                  )}
                </form>
              </div>
            ))}
          </section>

          {/* -------------------------------------------------------- historique */}
          <section className={ui.card}>
            <h2 className={ui.h2}>Historique</h2>
            {(history.data ?? []).length === 0 && (
              <p className={ui.muted}>Aucune modification enregistrée.</p>
            )}
            <ul className={styles.list}>
              {(
                (history.data ?? []) as {
                  id: number;
                  occurred_at: string;
                  actor_email: string | null;
                  action: string;
                  changes: Record<string, unknown>;
                }[]
              ).map((h) => (
                <li key={h.id}>
                  <span className={ui.muted}>
                    {new Date(h.occurred_at).toLocaleString('fr-FR')}
                  </span>{' '}
                  {h.actor_email ?? 'système'} —{' '}
                  {h.action === 'insert'
                    ? 'création'
                    : h.action === 'delete'
                      ? 'suppression'
                      : `modification (${Object.keys(h.changes).join(', ')})`}
                </li>
              ))}
            </ul>
            <Link href={`/journal?objet=${id}`}>Journal complet</Link>
          </section>
        </div>

        <aside className={styles.preview}>
          <h2 className={ui.h2}>Aperçu comme sur mobile</h2>
          {preview.data ? (
            <HymnPreview hymn={preview.data as PublishedHymn} />
          ) : (
            <p className={ui.muted}>Aperçu indisponible.</p>
          )}
        </aside>
      </div>
    </>
  );
}
