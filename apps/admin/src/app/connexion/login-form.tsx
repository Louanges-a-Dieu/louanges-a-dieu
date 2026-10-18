'use client';

import { useActionState } from 'react';

import { SubmitButton } from '@/components/buttons';
import ui from '@/components/ui.module.css';

import { loginAction, type LoginState } from './actions';

export function LoginForm() {
  const [state, action] = useActionState<LoginState, FormData>(loginAction, { step: 'email' });
  return (
    <form action={action}>
      {state.error && (
        <p className={ui.error} role="alert">
          {state.error}
        </p>
      )}
      {state.info && (
        <p className={ui.ok} role="status">
          {state.info}
        </p>
      )}
      {state.step === 'email' ? (
        <>
          <label className={ui.field}>
            <span className={ui.label}>Adresse e-mail</span>
            <input
              className={ui.input}
              type="email"
              name="email"
              autoComplete="email"
              required
              defaultValue={state.email}
            />
          </label>
          <SubmitButton variant="primary" name="intent" value="send">
            Recevoir un code
          </SubmitButton>
        </>
      ) : (
        <>
          <input type="hidden" name="email" value={state.email} />
          <p className={ui.hint}>Code envoyé à {state.email}</p>
          <label className={ui.field}>
            <span className={ui.label}>Code de connexion</span>
            <input
              className={ui.input}
              name="code"
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9]{6,10}"
              required
              autoFocus
            />
          </label>
          <div className={ui.row}>
            <SubmitButton variant="primary" name="intent" value="verify">
              Se connecter
            </SubmitButton>
            <SubmitButton variant="ghost" name="intent" value="restart">
              Changer d’adresse
            </SubmitButton>
          </div>
        </>
      )}
    </form>
  );
}
