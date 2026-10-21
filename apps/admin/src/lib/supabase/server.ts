import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

import { supabaseConfig } from '../env';

/** Client Supabase avec la session de l'éditeur (cookies), côté serveur uniquement. */
export async function createClient() {
  // Cookies d'abord : la page est ainsi reconnue comme dynamique (jamais
  // précalculée au build, où la configuration peut manquer, comme en CI).
  const store = await cookies();
  const { url, publishableKey } = supabaseConfig();
  return createServerClient(url, publishableKey, {
    cookies: {
      getAll: () => store.getAll(),
      setAll: (list) => {
        try {
          for (const { name, value, options } of list) store.set(name, value, options);
        } catch {
          // Appel depuis un composant serveur : le proxy rafraîchit la session.
        }
      },
    },
  });
}

export type Supabase = Awaited<ReturnType<typeof createClient>>;
