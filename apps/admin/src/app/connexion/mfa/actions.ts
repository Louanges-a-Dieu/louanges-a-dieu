'use server';

import { redirect } from 'next/navigation';
import { z } from 'zod';

import { createClient } from '@/lib/supabase/server';

export interface MfaState {
  factorId?: string;
  qrCode?: string;
  secret?: string;
  error?: string;
}

/** Nouvel enrôlement TOTP (les enrôlements inachevés sont d'abord retirés). */
export async function startEnrollment(): Promise<MfaState> {
  const supabase = await createClient();
  const { data: factors } = await supabase.auth.mfa.listFactors();
  for (const factor of factors?.all ?? []) {
    if (factor.factor_type === 'totp' && factor.status === 'unverified') {
      await supabase.auth.mfa.unenroll({ factorId: factor.id });
    }
  }
  const { data, error } = await supabase.auth.mfa.enroll({
    factorType: 'totp',
    friendlyName: `Louanges à Dieu (${new Date().toISOString().slice(0, 10)})`,
  });
  if (error || !data) return { error: 'La configuration du second facteur a échoué.' };
  return { factorId: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret };
}

const Verify = z.object({
  factorId: z.uuid(),
  code: z
    .string()
    .trim()
    .regex(/^\d{6}$/),
});

/** Vérifie un code TOTP : la session passe au niveau aal2. */
export async function verifyFactor(state: MfaState, form: FormData): Promise<MfaState> {
  const parsed = Verify.safeParse({ factorId: form.get('factorId'), code: form.get('code') });
  if (!parsed.success)
    return { ...state, error: 'Saisissez les 6 chiffres affichés par l’application.' };
  const supabase = await createClient();
  const { error } = await supabase.auth.mfa.challengeAndVerify(parsed.data);
  if (error) {
    return {
      ...state,
      error:
        error.status === 429
          ? 'Trop d’essais : patientez quelques minutes.'
          : 'Code incorrect. Vérifiez l’heure du téléphone et réessayez.',
    };
  }
  redirect('/');
}
