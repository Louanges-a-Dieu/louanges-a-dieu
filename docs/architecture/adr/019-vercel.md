# ADR-019 — Hébergement web Vercel

**Décision.** `apps/admin` et `apps/web` sont déployés sur Vercel (Q-15), un projet par app,
environnements Preview/Production reliés à Supabase staging/prod.

**Conséquences.** Les apps restent du Next.js standard (pas d'API propriétaire Vercel) pour
pouvoir changer d'hébergeur. L'offre gratuite Hobby est réservée à un usage personnel non
commercial : l'offre adaptée sera vérifiée avant la mise en production.
