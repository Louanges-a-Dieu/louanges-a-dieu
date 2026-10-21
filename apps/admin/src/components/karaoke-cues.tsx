'use client';

import { useEffect, useRef, useState, type KeyboardEvent } from 'react';

import {
  cueProblems,
  parseTenths,
  shiftCues,
  tenths,
  toCueRows,
  type EditableCue,
} from '@/lib/karaoke';

import { SubmitButton } from './buttons';
import styles from './karaoke-sync.module.css';
import ui from './ui.module.css';

type Field = 'start' | 'end';

/**
 * Ajustement d'une synchronisation karaoké existante, vers par vers : début
 * et fin modifiables (saisie, flèches ±0,1 s ou Maj ±1 s, « = lecture »),
 * écoute d'un vers seul, décalage de tous les vers. Rien n'est effacé :
 * l'enregistrement remplace les instants par ceux affichés.
 */
export function KaraokeCues({
  src,
  initial,
  hymnId,
  trackId,
  action,
}: {
  src: string;
  initial: EditableCue[];
  hymnId: string;
  trackId: string;
  action: (form: FormData) => Promise<void>;
}) {
  const audio = useRef<HTMLAudioElement>(null);
  const stopAt = useRef<number | null>(null);
  const [cues, setCues] = useState(initial);
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [shift, setShift] = useState('0,5');
  const problems = cueProblems(cues);
  const changed = cues.some((c, i) => c.start !== initial[i]?.start || c.end !== initial[i]?.end);
  const valid = problems.every((p) => p === null);

  // Écoute d'un vers : arrêt automatique à sa fin.
  useEffect(() => {
    const el = audio.current;
    if (!el) return;
    const onTime = () => {
      if (stopAt.current !== null && el.currentTime * 1000 >= stopAt.current) {
        el.pause();
        stopAt.current = null;
      }
    };
    el.addEventListener('timeupdate', onTime);
    return () => el.removeEventListener('timeupdate', onTime);
  }, []);

  const set = (i: number, field: Field, ms: number) =>
    setCues((all) =>
      all.map((c, k) => (k === i ? { ...c, [field]: Math.max(0, Math.round(ms)) } : c)),
    );

  const key = (i: number, field: Field) => `${i}-${field}`;

  /** Saisie en cours abandonnée : la valeur enregistrée s'affiche. */
  const forget = (i: number, field: Field) =>
    setDrafts((d) => {
      const next = { ...d };
      delete next[key(i, field)];
      return next;
    });

  const commit = (i: number, field: Field) => {
    const draft = drafts[key(i, field)];
    if (draft === undefined) return;
    const ms = parseTenths(draft);
    if (ms !== null) set(i, field, ms);
    forget(i, field);
  };

  const nudge = (e: KeyboardEvent<HTMLInputElement>, i: number, field: Field) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      commit(i, field);
      return;
    }
    if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return;
    e.preventDefault();
    const step = (e.shiftKey ? 1000 : 100) * (e.key === 'ArrowUp' ? 1 : -1);
    forget(i, field);
    set(i, field, cues[i]![field] + step);
  };

  const play = (c: EditableCue) => {
    const el = audio.current;
    if (!el) return;
    el.currentTime = Math.max(0, c.start - 300) / 1000;
    stopAt.current = c.end;
    void el.play();
  };

  const now = () => Math.round((audio.current?.currentTime ?? 0) * 1000);
  const delta = Math.round(Number(shift.replace(',', '.')) * 1000);

  return (
    <div className={styles.sync}>
      <p className={ui.hint}>
        Corrigez un vers sans refaire toute la synchronisation : saisissez le temps (« 1:05.3 »), ou
        utilisez <kbd>↑</kbd> <kbd>↓</kbd> (±0,1 s ; avec <kbd>Maj</kbd> ±1 s), ou « = lecture »
        pour prendre la position du lecteur. « ▶ » fait écouter le vers seul.
      </p>
      <audio ref={audio} src={src} preload="auto" controls className={styles.audio} />
      <div className={ui.row}>
        <label className={styles.shift}>
          <span>Décaler tous les vers de</span>
          <input
            className={ui.input}
            value={shift}
            onChange={(e) => setShift(e.target.value)}
            inputMode="decimal"
            aria-label="Décalage en secondes (négatif pour avancer)"
          />
          <span>s</span>
        </label>
        <button
          type="button"
          className={ui.button}
          disabled={!Number.isFinite(delta) || delta === 0}
          onClick={() => setCues((all) => shiftCues(all, delta))}
        >
          Appliquer
        </button>
        <button
          type="button"
          className={ui.buttonGhost}
          disabled={!changed}
          onClick={() => {
            setCues(initial);
            setDrafts({});
          }}
        >
          Annuler les modifications
        </button>
      </div>
      <ol className={styles.cues}>
        {cues.map((c, i) => (
          <li
            key={`${c.sectionId}-${c.lineIndex}-${i}`}
            className={problems[i] ? styles.invalid : undefined}
          >
            {c.section && <span className={styles.section}>{c.section}</span>}
            <button
              type="button"
              className={ui.buttonGhost}
              onClick={() => play(c)}
              aria-label={`Écouter : ${c.text}`}
            >
              ▶
            </button>
            <span className={styles.cueText}>{c.text}</span>
            {(['start', 'end'] as const).map((field) => (
              <span key={field} className={styles.cueTime}>
                <input
                  className={ui.input}
                  value={drafts[key(i, field)] ?? tenths(c[field])}
                  onChange={(e) => setDrafts((d) => ({ ...d, [key(i, field)]: e.target.value }))}
                  onBlur={() => commit(i, field)}
                  onKeyDown={(e) => nudge(e, i, field)}
                  size={7}
                  aria-label={`${field === 'start' ? 'Début' : 'Fin'} : ${c.text}`}
                />
                <button
                  type="button"
                  className={ui.buttonGhost}
                  onClick={() => set(i, field, now())}
                  title={`${field === 'start' ? 'Début' : 'Fin'} = position du lecteur`}
                >
                  = lecture
                </button>
              </span>
            ))}
            {problems[i] && (
              <span className={styles.problem} role="alert">
                {problems[i]}
              </span>
            )}
          </li>
        ))}
      </ol>
      <form action={action} className={ui.row}>
        <input type="hidden" name="hymn_id" value={hymnId} />
        <input type="hidden" name="track_id" value={trackId} />
        <input type="hidden" name="cues" value={JSON.stringify(toCueRows(cues))} />
        <span className={ui.muted}>
          {valid
            ? changed
              ? 'Modifications non enregistrées.'
              : 'Aucune modification.'
            : 'Corrigez les vers signalés avant d’enregistrer.'}
        </span>
        <SubmitButton variant="primary" disabled={!changed || !valid}>
          Enregistrer les ajustements
        </SubmitButton>
      </form>
    </div>
  );
}
