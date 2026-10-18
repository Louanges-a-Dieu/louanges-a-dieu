import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

import { supabaseConfig } from '../env';

/** Client Supabase avec la session de l'éditeur (cookies), côté serveur uniquement. */
export async function createClient() {
  const { url, publishableKey } = supabaseConfig();
  const store = await cookies();
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
