import type { Metadata } from 'next';

import { ProjectionConsole } from './console';

export const metadata: Metadata = {
  title: 'Projection — Louanges à Dieu',
  manifest: '/manifest.webmanifest',
};

/**
 * Mode « ordinateur seul » (Phase 8.4). Page statique : la console télécharge
 * le recueil (clé publique uniquement, ADR-011) puis fonctionne sans Internet.
 */
export default function ProjectionPage() {
  return (
    <ProjectionConsole
      config={{
        url: (process.env.SUPABASE_URL ?? '').replace(/\/+$/, ''),
        publishableKey: process.env.SUPABASE_PUBLISHABLE_KEY ?? '',
      }}
    />
  );
}
