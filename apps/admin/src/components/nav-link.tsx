'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { ReactNode } from 'react';

/**
 * Lien de navigation qui signale la page courante (aria-current). Sans
 * préchargement : chaque page vérifie la session et le second facteur côté
 * serveur, inutile de le faire pour tout le menu à chaque page.
 */
export function NavLink({ href, children }: { href: string; children: ReactNode }) {
  const pathname = usePathname();
  const current = href === '/' ? pathname === '/' : pathname.startsWith(href);
  return (
    <Link href={href} prefetch={false} aria-current={current ? 'page' : undefined}>
      {children}
    </Link>
  );
}
