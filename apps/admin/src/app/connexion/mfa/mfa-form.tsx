'use client';

import { useActionState, useState, useTransition } from 'react';

import { SubmitButton } from '@/components/buttons';
import ui from '@/components/ui.module.css';

import { startEnrollment, verifyFactor, type MfaState } from './actions';

/** Second facteur : enrôlement (première fois) ou simple vérification. */
export function MfaForm({ factorId }: { factorId: string | null }) {
  const [enrollment, setEnrollment] = useState<MfaState | null>(null);
  const [starting, startTransition] = useTransition();
  const initial: MfaState = factorId ? { factorId } : {};
  const [state, action] = useActionState<MfaState, FormData>(verifyFactor, initial);
  const current = enrollment ?? state;

  if (!factorId && !enrollment?.factorId) {
    return (
      <div>
        <p>
          Le back-office exige un second facteur. Installez une application d’authentification
          (Google Authenticator, Microsoft Authenticator, 2FAS…) sur votre téléphone, puis :
        </p>
        {enrollment?.error && <p className={ui.error}>{enrollment.error}</p>}
        <button
          type="button"
          className={ui.buttonPrimary}
          disabled={starting}
          onClick={() => startTransition(async () => setEnrollment(await startEnrollment()))}
        >
          Configurer le second facteur
        </button>
      </div>
    );
  }

  return (
    <form action={action}>
      {enrollment?.qrCode && (
        <div className={ui.card}>
          <p>Scannez ce code avec l’application d’authentification :</p>
          {/* eslint-disable-next-line @next/next/no-img-element -- image SVG en data: générée par Supabase */}
          <img src={enrollment.qrCode} alt="Code QR du second facteur" width={200} height={200} />
          <p className={ui.hint}>
            Ou saisissez cette clé : <code>{enrollment.secret}</code>
          </p>
        </div>
      )}
      {state.error && (
        <p className={ui.error} role="alert">
          {state.error}
        </p>
      )}
      <input type="hidden" name="factorId" value={current.factorId ?? state.factorId ?? ''} />
      <label className={ui.field}>
        <span className={ui.label}>Code à 6 chiffres affiché par l’application</span>
        <input
          className={ui.input}
          name="code"
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern="[0-9]{6}"
          maxLength={6}
          required
          autoFocus
        />
      </label>
      <SubmitButton variant="primary">Vérifier</SubmitButton>
    </form>
  );
}
