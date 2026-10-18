/**
 * Critère d'acceptation de la Phase 9, contre la VRAIE API (base de
 * développement) : sans rôle, ou avec un rôle mais sans second facteur, on ne
 * lit aucun brouillon et on ne publie rien, même en appelant l'API
 * directement. Avec le second facteur, l'éditeur lit la copie de travail.
 *
 * Nécessite apps/admin/.env.local, apps/mobile/config/dev-test-user.json et
 * apps/admin/e2e/.test-editor.json ; ignoré sinon (CI).
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { createClient } from '@supabase/supabase-js';
import { describe, expect, it } from 'vitest';

import { totp } from '../../../../tools/pgtap/test-users.ts';

const admin = resolve(import.meta.dirname, '../..');
const files = {
  env: resolve(admin, '.env.local'),
  user: resolve(admin, '../mobile/config/dev-test-user.json'),
  editor: resolve(admin, 'e2e/.test-editor.json'),
};
const available = Object.values(files).every(existsSync);

function client() {
  const env = Object.fromEntries(
    readFileSync(files.env, 'utf8')
      .split('\n')
      .filter((l) => l.includes('='))
      .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).trim()]),
  );
  return createClient(env.SUPABASE_URL!, env.SUPABASE_PUBLISHABLE_KEY!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function expectNoEditorialAccess(supabase: ReturnType<typeof client>) {
  const { data: drafts } = await supabase.from('hymns').select('id').limit(5);
  expect(drafts ?? []).toEqual([]);
  const { data: issues } = await supabase.from('import_issues').select('id').limit(5);
  expect(issues ?? []).toEqual([]);
  const { data: editions } = await supabase.from('editions').select('id').limit(1);
  expect(editions ?? []).toEqual([]);
  const publish = await supabase.rpc('publish_release', {
    p_edition_id: '00000000-0000-4000-8000-000000000000',
  });
  expect(publish.error?.code).toBe('42501');
  const imported = await supabase.rpc('import_catalog_draft', {
    p_draft: { format: 'lad.catalog-draft' },
  });
  expect(imported.error?.code).toBe('42501');
  const audit = await supabase.rpc('admin_audit_log');
  expect(audit.data ?? []).toEqual([]);
  const update = await supabase
    .from('hymns')
    .update({ title: 'piraté' })
    .neq('id', '00000000-0000-4000-8000-000000000000')
    .select('id');
  expect(update.data ?? []).toEqual([]);
}

describe.skipIf(!available)('accès éditorial par l’API (serveur réel)', () => {
  it('anonyme : aucun accès', async () => {
    await expectNoEditorialAccess(client());
  });

  it('compte sans rôle : aucun accès', async () => {
    const supabase = client();
    const user = JSON.parse(readFileSync(files.user, 'utf8')) as {
      email: string;
      password: string;
    };
    const { error } = await supabase.auth.signInWithPassword(user);
    expect(error).toBeNull();
    await expectNoEditorialAccess(supabase);
  });

  it('éditeur sans second facteur (aal1) : aucun accès ; avec second facteur : accès', async () => {
    const supabase = client();
    const editor = JSON.parse(readFileSync(files.editor, 'utf8')) as {
      email: string;
      password: string;
      totpSecret: string;
      factorId: string;
    };
    const { error } = await supabase.auth.signInWithPassword(editor);
    expect(error).toBeNull();
    expect((await supabase.auth.mfa.getAuthenticatorAssuranceLevel()).data?.currentLevel).toBe(
      'aal1',
    );
    await expectNoEditorialAccess(supabase);

    const verified = await supabase.auth.mfa.challengeAndVerify({
      factorId: editor.factorId,
      code: totp(editor.totpSecret),
    });
    expect(verified.error).toBeNull();
    const { data: drafts } = await supabase.from('hymns').select('id').limit(5);
    expect(drafts?.length).toBe(5);
    const stats = await supabase.rpc('editorial_stats');
    expect((stats.data as { total: number }).total).toBeGreaterThan(1000);
  });
});
