import type { NextConfig } from 'next';

/**
 * CSP du site public (10.3). Les pages statiques (console de projection mise en
 * cache hors ligne) ne peuvent pas porter de nonce : les scripts en ligne de
 * Next sont donc admis, mais aucune origine externe, ni cadre, ni plugin.
 * Seule exception : la console télécharge le recueil depuis Supabase.
 */
function contentSecurityPolicy() {
  const supabase = (process.env.SUPABASE_URL ?? '').replace(/\/+$/, '');
  return [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    `connect-src 'self'${supabase ? ` ${supabase}` : ''}`,
    "worker-src 'self'",
    "manifest-src 'self'",
    "object-src 'none'",
    "base-uri 'none'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join('; ');
}

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  poweredByHeader: false,
  headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Content-Security-Policy', value: contentSecurityPolicy() },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        ],
      },
      {
        // Service worker du mode « ordinateur seul » : toujours la dernière version.
        source: '/sw.js',
        headers: [
          { key: 'Cache-Control', value: 'no-cache' },
          { key: 'Service-Worker-Allowed', value: '/' },
        ],
      },
      {
        // Programmes partagés (ADR-012) : jamais indexés, jamais mis en cache,
        // et le jeton contenu dans l'adresse n'est transmis à aucun autre site.
        source: '/programme/:token*',
        headers: [
          { key: 'X-Robots-Tag', value: 'noindex, nofollow, noarchive' },
          { key: 'Referrer-Policy', value: 'no-referrer' },
          { key: 'Cache-Control', value: 'private, no-store' },
        ],
      },
    ];
  },
};

export default nextConfig;
