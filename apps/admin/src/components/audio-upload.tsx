'use client';

import { useEffect, useState, useTransition, type FormEvent } from 'react';

import type { UploadTicket } from '@/app/(espace)/cantiques/[id]/actions';
import { MAX_AUDIO_BYTES, audioExtension, formatClock } from '@/lib/audio';

import styles from './audio-upload.module.css';
import ui from './ui.module.css';

type Phase = 'idle' | 'preparing' | 'sending' | 'attaching';

/**
 * Dépôt d'un enregistrement depuis la fiche : le fichier choisi part
 * directement du navigateur vers Backblaze (adresse d'envoi préparée par le
 * serveur), puis il est rattaché au cantique. La durée est lue sur le fichier.
 */
export function AudioUpload({
  hymnId,
  mediaLabels,
  rightsLabels,
  className,
  prepare,
  attach,
}: {
  hymnId: string;
  mediaLabels: Record<string, string>;
  rightsLabels: Record<string, string>;
  className?: string;
  prepare: (request: {
    hymn_id: string;
    media_type: string;
    file_name: string;
    size: number;
  }) => Promise<UploadTicket>;
  attach: (form: FormData) => Promise<void>;
}) {
  const [file, setFile] = useState<File | null>(null);
  const [mediaType, setMediaType] = useState('melody');
  const [rights, setRights] = useState('unknown');
  const [duration, setDuration] = useState('');
  const [phase, setPhase] = useState<Phase>('idle');
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [, startTransition] = useTransition();
  const busy = phase !== 'idle';

  // Pas de départ de la page en plein envoi.
  useEffect(() => {
    if (phase !== 'sending') return;
    const warn = (event: BeforeUnloadEvent) => event.preventDefault();
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [phase]);

  function choose(next: File | null) {
    setError(null);
    setDuration('');
    setFile(next);
    if (!next) return;
    if (!audioExtension(next.name)) {
      setError('Format refusé : fichier .mp3, .m4a ou .aac uniquement.');
    } else if (next.size > MAX_AUDIO_BYTES) {
      setError('Fichier trop lourd (100 Mo au plus).');
    } else {
      readDuration(next).then((seconds) => {
        if (seconds) setDuration(formatClock(Math.round(seconds) * 1000));
      });
    }
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!file || busy) return;
    setError(null);
    setProgress(0);
    try {
      setPhase('preparing');
      const [ticket, sha1] = await Promise.all([
        prepare({ hymn_id: hymnId, media_type: mediaType, file_name: file.name, size: file.size }),
        sha1Hex(file),
      ]);
      if (!ticket.ok) throw new Error(ticket.error);
      setPhase('sending');
      await send(ticket, file, sha1, setProgress);
      setPhase('attaching');
      const form = new FormData();
      form.set('hymn_id', hymnId);
      form.set('media_type', mediaType);
      form.set('storage_key', ticket.storageKey);
      form.set('duration', duration);
      form.set('rights_status', rights);
      // Rattachement : la page se recharge avec le message de résultat.
      startTransition(() => attach(form));
    } catch (e) {
      setPhase('idle');
      setError(e instanceof Error ? e.message : 'Envoi impossible.');
    }
  }

  return (
    <form onSubmit={submit}>
      <div className={className}>
        <label className={ui.field}>
          <span className={ui.label}>Fichier (.mp3, .m4a, .aac)</span>
          <input
            className={ui.input}
            type="file"
            accept=".mp3,.m4a,.aac,audio/mpeg,audio/mp4,audio/aac"
            required
            disabled={busy}
            onChange={(e) => choose(e.target.files?.[0] ?? null)}
          />
        </label>
        <label className={ui.field}>
          <span className={ui.label}>Version</span>
          <select
            className={ui.select}
            value={mediaType}
            disabled={busy}
            onChange={(e) => setMediaType(e.target.value)}
          >
            {Object.entries(mediaLabels).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </select>
        </label>
        <label className={ui.field}>
          <span className={ui.label}>Durée (lue sur le fichier)</span>
          <input
            className={ui.input}
            value={duration}
            placeholder="3:05"
            disabled={busy}
            onChange={(e) => setDuration(e.target.value)}
          />
        </label>
        <label className={ui.field}>
          <span className={ui.label}>Droits</span>
          <select
            className={ui.select}
            value={rights}
            disabled={busy}
            onChange={(e) => setRights(e.target.value)}
          >
            {Object.entries(rightsLabels).map(([v, l]) => (
              <option key={v} value={v}>
                {l}
              </option>
            ))}
          </select>
        </label>
        <button type="submit" className={ui.buttonPrimary} disabled={!file || busy || !!error}>
          {phase === 'idle' && 'Envoyer et ajouter'}
          {phase === 'preparing' && 'Préparation…'}
          {phase === 'sending' && `Envoi… ${Math.round(progress * 100)} %`}
          {phase === 'attaching' && 'Ajout au cantique…'}
        </button>
      </div>
      {phase === 'sending' && (
        <progress
          className={styles.progress}
          value={progress}
          max={1}
          aria-label="Envoi du fichier"
        />
      )}
      {error && (
        <p className={ui.error} role="alert">
          {error}
        </p>
      )}
    </form>
  );
}

/** Durée du fichier en secondes, lue dans le navigateur (null si illisible). */
function readDuration(file: File): Promise<number | null> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const audio = new Audio();
    const done = (seconds: number | null) => {
      URL.revokeObjectURL(url);
      resolve(seconds);
    };
    audio.preload = 'metadata';
    audio.onloadedmetadata = () =>
      done(Number.isFinite(audio.duration) && audio.duration > 0 ? audio.duration : null);
    audio.onerror = () => done(null);
    audio.src = url;
  });
}

/** Empreinte SHA-1 exigée par Backblaze (contrôle d'intégrité à l'arrivée). */
async function sha1Hex(file: File): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-1', await file.arrayBuffer());
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

/** Envoi direct vers Backblaze (b2_upload_file), avec progression. */
function send(
  ticket: Extract<UploadTicket, { ok: true }>,
  file: File,
  sha1: string,
  onProgress: (fraction: number) => void,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', ticket.uploadUrl);
    xhr.setRequestHeader('Authorization', ticket.authorizationToken);
    // Chemin déjà limité à « A-Za-z0-9._-/ » : rien à encoder.
    xhr.setRequestHeader('X-Bz-File-Name', ticket.storageKey);
    xhr.setRequestHeader('Content-Type', ticket.contentType);
    xhr.setRequestHeader('X-Bz-Content-Sha1', sha1);
    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) onProgress(e.loaded / e.total);
    };
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) return resolve();
      let message = `erreur ${xhr.status}`;
      try {
        message = (JSON.parse(xhr.responseText) as { message?: string }).message ?? message;
      } catch {
        // Réponse non JSON : code HTTP seul.
      }
      reject(new Error(`Backblaze a refusé le fichier : ${message}.`));
    };
    xhr.onerror = () =>
      reject(
        new Error(
          'Envoi bloqué : connexion coupée, ou Backblaze n’autorise pas encore les envois depuis ' +
            'ce site (règle CORS, voir docs/deployment/audio-backblaze.md).',
        ),
      );
    xhr.send(file);
  });
}
