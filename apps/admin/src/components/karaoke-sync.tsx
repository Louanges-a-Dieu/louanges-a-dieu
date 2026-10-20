'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

import { cuesFromTaps, type SyncLine } from '@/lib/karaoke';

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
 * sur Espace au début de chaque vers (S : vers non chanté ; Retour arrière :
 * annuler le dernier appui ; Entrée : fin). Le résultat est envoyé au
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
  const [starts, setStarts] = useState<(number | null)[]>([]);
  const [endMs, setEndMs] = useState<number | null>(null);
  const [running, setRunning] = useState(false);
  const index = starts.length;
  const now = () => Math.round((audio.current?.currentTime ?? 0) * 1000);

  const start = () => {
    const el = audio.current;
    if (!el) return;
    setStarts([]);
    setEndMs(null);
    el.currentTime = 0;
    void el.play();
    setRunning(true);
  };

  const mark = useCallback(
    (sung: boolean) => {
      if (!running || index >= lines.length) return;
      setStarts((s) => [...s, sung ? now() : null]);
    },
    [running, index, lines.length],
  );

  const undo = useCallback(() => {
    if (!running) return;
    setStarts((s) => {
      const previous = s.slice(0, -1);
      const last = [...previous].reverse().find((t) => t !== null);
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
      else if (e.key === 'Backspace') undo();
      else if (e.key === 'Enter') finish();
      else return;
      e.preventDefault();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [running, mark, undo, finish]);

  const cues = endMs === null ? [] : cuesFromTaps(lines, starts, endMs);

  return (
    <div className={styles.sync}>
      <p className={ui.hint}>
        « Démarrer », puis <kbd>Espace</kbd> au tout début de chaque vers surligné ; <kbd>S</kbd> si
        l’enregistrement ne chante pas ce vers ; <kbd>⌫</kbd> pour annuler le dernier appui ;{' '}
        <kbd>Entrée</kbd> à la fin de l’enregistrement. Les vers suivent l’ordre chanté (refrain
        après chaque couplet).
      </p>
      <audio ref={audio} src={src} preload="auto" controls className={styles.audio} />
      <div className={ui.row}>
        <button type="button" className={ui.button} onClick={start}>
          {running ? 'Recommencer' : 'Démarrer'}
        </button>
        <button type="button" className={ui.button} onClick={() => mark(true)} disabled={!running}>
          Vers suivant (Espace)
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
            {line.text}
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
