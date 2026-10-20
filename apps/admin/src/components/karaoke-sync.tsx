'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

import { canPause, cuesFromTaps, replay, type SyncEvent, type SyncLine } from '@/lib/karaoke';

import { SubmitButton } from './buttons';
import styles from './karaoke-sync.module.css';
import ui from './ui.module.css';

/** « 1:05.3 » */
function clock(ms: number): string {
  const s = ms / 1000;
  return `${Math.floor(s / 60)}:${(s % 60).toFixed(1).padStart(4, '0')}`;
}

/**
 * Synchronisation karaoké d'un enregistrement : on l'écoute et l'on appuie
 * sur Espace au début de chaque vers (S : vers non chanté ; P : pause
 * instrumentale après le vers ; Retour arrière : annuler le dernier appui ;
 * Entrée : fin). Le résultat est envoyé au
 * formulaire [action] (champ caché « cues »).
 */
export function KaraokeSync({
  src,
  lines,
  hymnId,
  trackId,
  action,
}: {
  src: string;
  lines: SyncLine[];
  hymnId: string;
  trackId: string;
  action: (form: FormData) => Promise<void>;
}) {
  const audio = useRef<HTMLAudioElement>(null);
  const [events, setEvents] = useState<SyncEvent[]>([]);
  const [endMs, setEndMs] = useState<number | null>(null);
  const [running, setRunning] = useState(false);
  const { starts, ends } = replay(events);
  const index = starts.length;
  const now = () => Math.round((audio.current?.currentTime ?? 0) * 1000);

  const start = () => {
    const el = audio.current;
    if (!el) return;
    setEvents([]);
    setEndMs(null);
    el.currentTime = 0;
    void el.play();
    setRunning(true);
  };

  const mark = useCallback(
    (sung: boolean) => {
      if (!running || index >= lines.length) return;
      setEvents((e) => [...e, { kind: 'line', at: sung ? now() : null }]);
    },
    [running, index, lines.length],
  );

  const pause = useCallback(() => {
    if (!running) return;
    setEvents((e) => (canPause(e) ? [...e, { kind: 'pause', at: now() }] : e));
  }, [running]);

  const undo = useCallback(() => {
    if (!running) return;
    setEvents((e) => {
      const previous = e.slice(0, -1);
      const last = [...previous].reverse().find((x) => x.at !== null)?.at;
      if (audio.current) audio.current.currentTime = Math.max(0, (last ?? 0) / 1000);
      return previous;
    });
  }, [running]);

  const finish = useCallback(() => {
    if (!running) return;
    audio.current?.pause();
    setEndMs(now());
    setRunning(false);
  }, [running]);

  useEffect(() => {
    if (!running) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if (e.code === 'Space') mark(true);
      else if (e.key === 's' || e.key === 'S') mark(false);
      else if (e.key === 'p' || e.key === 'P') pause();
      else if (e.key === 'Backspace') undo();
      else if (e.key === 'Enter') finish();
      else return;
      e.preventDefault();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [running, mark, pause, undo, finish]);

  const cues = endMs === null ? [] : cuesFromTaps(lines, starts, endMs, ends);

  return (
    <div className={styles.sync}>
      <p className={ui.hint}>
        « Démarrer », puis <kbd>Espace</kbd> au tout début de chaque vers surligné ; <kbd>P</kbd>{' '}
        dès que le chant s’arrête avant un passage instrumental (le vers s’éteint, l’app affiche un
        compte à rebours) ; <kbd>S</kbd> si l’enregistrement ne chante pas ce vers ; <kbd>⌫</kbd>{' '}
        pour annuler le dernier appui ; <kbd>Entrée</kbd> à la fin de l’enregistrement. Les vers
        suivent l’ordre chanté (refrain après chaque couplet).
      </p>
      <audio ref={audio} src={src} preload="auto" controls className={styles.audio} />
      <div className={ui.row}>
        <button type="button" className={ui.button} onClick={start}>
          {running ? 'Recommencer' : 'Démarrer'}
        </button>
        <button type="button" className={ui.button} onClick={() => mark(true)} disabled={!running}>
          Vers suivant (Espace)
        </button>
        <button
          type="button"
          className={ui.button}
          onClick={pause}
          disabled={!running || !canPause(events)}
        >
          Pause instrumentale (P)
        </button>
        <button type="button" className={ui.button} onClick={() => mark(false)} disabled={!running}>
          Non chanté (S)
        </button>
        <button type="button" className={ui.button} onClick={undo} disabled={!running}>
          Annuler (⌫)
        </button>
        <button type="button" className={ui.button} onClick={finish} disabled={!running}>
          Fin (Entrée)
        </button>
      </div>
      <ol className={styles.lines}>
        {lines.map((line, k) => (
          <li
            key={`${line.sectionId}-${line.lineIndex}-${k}`}
            className={
              running && k === index ? styles.current : k < index ? styles.done : undefined
            }
          >
            {line.section && <span className={styles.section}>{line.section}</span>}
            <span className={styles.time}>
              {k < starts.length ? (starts[k] === null ? '—' : clock(starts[k]!)) : ''}
            </span>
            <span>
              {line.text}
              {ends[k] != null && (
                <span className={styles.pause}> · pause à {clock(ends[k]!)}</span>
              )}
            </span>
          </li>
        ))}
      </ol>
      {endMs !== null && (
        <form action={action} className={ui.row}>
          <input type="hidden" name="hymn_id" value={hymnId} />
          <input type="hidden" name="track_id" value={trackId} />
          <input type="hidden" name="cues" value={JSON.stringify(cues)} />
          <span className={ui.muted}>
            {cues.length} vers synchronisé(s), fin à {clock(endMs)}.
          </span>
          <SubmitButton variant="primary" disabled={cues.length === 0}>
            Enregistrer la synchronisation
          </SubmitButton>
        </form>
      )}
    </div>
  );
}
