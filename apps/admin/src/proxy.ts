import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

import { b2Config } from './lib/backblaze';
import { audioOrigin, supabaseConfig } from './lib/env';

/** Pages accessibles sans session. */
const PUBLIC_PATHS = ['/connexion', '/acces-refuse'];

/**
 * Avant chaque page : CSP stricte avec nonce (9.12), rafraîchissement de la
 * session Supabase, redirection vers la connexion sans session. Le contrôle
 * des rôles et du second facteur se fait ensuite côté serveur (lib/auth) et,
 * surtout, dans la base (RLS, has_role exigeant aal2).
 */
export async function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64');
  const dev = process.env.NODE_ENV === 'development';
  const csp = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${dev ? " 'unsafe-eval'" : ''}`,
    `style-src 'self'${dev ? " 'unsafe-inline'" : ` 'nonce-${nonce}'`}`,
    "img-src 'self' data:",
    "font-src 'self'",
    // Écoute des enregistrements (Backblaze B2) sur la fiche d'un cantique ;
    // blob: pour lire la durée d'un fichier avant son envoi.
    `media-src blob:${audioOrigin() ? ` ${audioOrigin()}` : ''}`,
    // Envoi direct d'un enregistrement vers Backblaze (adresses « pod-….backblaze.com »).
    `connect-src 'self'${b2Config() ? ' https://*.backblaze.com' : ''}`,
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join('; ');

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-nonce', nonce);
  requestHeaders.set('Content-Security-Policy', csp);
  let response = NextResponse.next({ request: { headers: requestHeaders } });

  const { url, publishableKey } = supabaseConfig();
  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (list) => {
        for (const { name, value } of list) request.cookies.set(name, value);
        response = NextResponse.next({ request: { headers: requestHeaders } });
        for (const { name, value, options } of list) response.cookies.set(name, value, options);
      },
    },
  });
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = request.nextUrl.pathname;
  if (!user && !PUBLIC_PATHS.some((p) => path === p || path.startsWith(`${p}/`))) {
    const login = request.nextUrl.clone();
    login.pathname = '/connexion';
    login.search = '';
    const redirect = NextResponse.redirect(login);
    for (const cookie of response.cookies.getAll()) redirect.cookies.set(cookie);
    redirect.headers.set('Content-Security-Policy', csp);
    return redirect;
  }

  response.headers.set('Content-Security-Policy', csp);
  return response;
}

export const config = {
  matcher: [
    {
      source: '/((?!_next/static|_next/image|favicon.ico).*)',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
};
