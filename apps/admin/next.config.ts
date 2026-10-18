import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Back-office entièrement personnel (session à chaque page) : rendu dynamique
  // classique, sans Cache Components.
  poweredByHeader: false,
  experimental: {
    // Import d'un catalogue brouillon complet (≈ 1 143 cantiques).
    serverActions: { bodySizeLimit: '10mb' },
  },
  headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'Referrer-Policy', value: 'no-referrer' },
          { key: 'X-Robots-Tag', value: 'noindex, nofollow' },
          { key: 'Cache-Control', value: 'private, no-store' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
          { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' },
        ],
      },
    ];
  },
};

export default nextConfig;
