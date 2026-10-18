'use server';

import { redirect } from 'next/navigation';
import { z } from 'zod';

import { createClient } from '@/lib/supabase/server';

export interface LoginState {
  step: 'email' | 'code';
  email?: string;
  error?: string;
  info?: string;
}

const Email = z.string().trim().toLowerCase().pipe(z.email());
const Code = z
  .string()
  .trim()
  .regex(/^\d{6,10}$/);

/** Connexion sans mot de passe (Q-13) : code reçu par e-mail. */
export async function loginAction(_: LoginState, form: FormData): Promise<LoginState> {
  const intent = form.get('intent');
  if (intent === 'restart') return { step: 'email' };

  const email = Email.safeParse(form.get('email'));
  if (!email.success) return { step: 'email', error: 'Adresse e-mail invalide.' };
  const supabase = await createClient();

  if (intent === 'send') {
    const { error } = await supabase.auth.signInWithOtp({
      email: email.data,
      options: { shouldCreateUser: true },
    });
    if (error) {
      return {
        step: 'email',
        email: email.data,
        error:
          error.status === 429
            ? 'Trop de demandes : patientez quelques minutes avant de redemander un code.'
            : 'L’envoi du code a échoué. Réessayez plus tard.',
      };
    }
    return {
      step: 'code',
      email: email.data,
      info: 'Un code de connexion vient d’être envoyé à cette adresse.',
    };
  }

  const code = Code.safeParse(form.get('code'));
  if (!code.success) return { step: 'code', email: email.data, error: 'Saisissez le code reçu.' };
  const { error } = await supabase.auth.verifyOtp({
    email: email.data,
    token: code.data,
    type: 'email',
  });
  if (error) {
    return {
      step: 'code',
      email: email.data,
      error:
        error.status === 429
          ? 'Trop d’essais : patientez quelques minutes.'
          : 'Code invalide ou expiré.',
    };
  }
  redirect('/');
}

export async function signOutAction() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect('/connexion');
}
