/**
 * DÉVELOPPEMENT UNIQUEMENT — outils communs pour créer des comptes de test sur
 * la base de développement (jamais en production).
 */
import { createHmac, randomBytes, randomUUID } from 'node:crypto';

import type pg from 'pg';

/** Crée (ou recrée) un compte à e-mail confirmé et mot de passe aléatoire. */
export async function createAuthUser(client: pg.Client, email: string) {
  const password = randomBytes(24).toString('base64url');
  const id = randomUUID();
  await client.query('delete from auth.users where email = $1', [email]);
  await client.query(
    `insert into auth.users (
       instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
       raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
       confirmation_token, recovery_token, email_change_token_new, email_change)
     values ('00000000-0000-0000-0000-000000000000', $1, 'authenticated', 'authenticated', $2,
             extensions.crypt($3, extensions.gen_salt('bf')), now(),
             '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')`,
    [id, email, password],
  );
  await client.query(
    `insert into auth.identities (id, user_id, provider_id, identity_data, provider, created_at, updated_at)
     values (gen_random_uuid(), $1::uuid, $3::text, jsonb_build_object('sub', $3::text, 'email', $2::text),
             'email', now(), now())`,
    [id, email, id],
  );
  return { id, email, password };
}

function base32Decode(input: string): Buffer {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const c of input.replace(/=+$/, '').toUpperCase()) {
    const v = alphabet.indexOf(c);
    if (v < 0) throw new Error('Secret TOTP invalide');
    bits += v.toString(2).padStart(5, '0');
  }
  const bytes = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) bytes.push(parseInt(bits.slice(i, i + 8), 2));
  return Buffer.from(bytes);
}

/** Code TOTP (RFC 6238 : SHA-1, 6 chiffres, 30 s), comme une application d'authentification. */
export function totp(secret: string, at = Date.now()): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(at / 1000 / 30)));
  const hmac = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const offset = hmac[hmac.length - 1]! & 0xf;
  const code = (hmac.readUInt32BE(offset) & 0x7fffffff) % 1_000_000;
  return String(code).padStart(6, '0');
}
