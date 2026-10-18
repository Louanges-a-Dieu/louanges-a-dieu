/**
 * Configuration publique du projet Supabase (ADR-011 : jamais de clé
 * « secret » ni « service_role » dans le back-office ; tout passe par la
 * session de l'éditeur et la RLS).
 */
export function supabaseConfig() {
  const url = (process.env.SUPABASE_URL ?? '').replace(/\/+$/, '');
  const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY ?? '';
  if (!url || !publishableKey) {
    throw new Error('SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY sont requis');
  }
  return { url, publishableKey };
}
