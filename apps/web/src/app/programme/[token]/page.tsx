import type { Metadata } from 'next';
import { Suspense } from 'react';

import { configFromEnv, fetchSharedProgram, SharedProgramServiceError } from '@/lib/shared-program';

import { ProgramView, ServiceErrorView, UnavailableView } from '../program-view';
import styles from '../programme.module.css';

export const metadata: Metadata = {
  title: 'Programme — Louanges à Dieu',
  robots: { index: false, follow: false, nocache: true },
  referrer: 'no-referrer',
};

/** Lu à chaque requête : un lien désactivé cesse de fonctionner aussitôt. */
async function SharedProgramContent({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const program = await fetchSharedProgram(token, configFromEnv()).catch((error: unknown) => {
    if (error instanceof SharedProgramServiceError) return 'service-error' as const;
    throw error;
  });
  if (program === 'service-error') return <ServiceErrorView />;
  return program ? <ProgramView program={program} /> : <UnavailableView />;
}

export default function SharedProgramPage({ params }: { params: Promise<{ token: string }> }) {
  return (
    <main className={styles.main}>
      <Suspense fallback={<p className={styles.muted}>Chargement du programme…</p>}>
        <SharedProgramContent params={params} />
      </Suspense>
    </main>
  );
}
