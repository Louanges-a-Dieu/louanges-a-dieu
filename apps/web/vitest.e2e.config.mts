import { fileURLToPath } from 'node:url';

import { defineConfig } from 'vitest/config';

/** Tests de bout en bout (navigateur réel) : `pnpm --filter @lad/web e2e`, après `build`. */
export default defineConfig({
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  test: {
    include: ['e2e/**/*.e2e.ts'],
    testTimeout: 180_000,
    hookTimeout: 60_000,
  },
});
