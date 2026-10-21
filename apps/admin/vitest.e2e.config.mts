import { fileURLToPath } from 'node:url';

import { defineConfig } from 'vitest/config';

/** Parcours administrateur de bout en bout (navigateur réel) : `pnpm --filter @lad/admin e2e`, après `build`. */
export default defineConfig({
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  test: {
    include: ['e2e/**/*.e2e.ts'],
    testTimeout: 240_000,
    // Un seul compte d'essai avec code à usage unique : un fichier après
    // l'autre (deux connexions simultanées réutiliseraient le même code).
    fileParallelism: false,
    hookTimeout: 60_000,
  },
});
