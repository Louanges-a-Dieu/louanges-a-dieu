# ADR-001 — Monorepo

**Contexte.** Trois applications (mobile Flutter, back-office, web public/projection), une base
Supabase et des contrats partagés. Le projet doit être transférable simplement.

**Décision.** Un dépôt unique : `apps/mobile`, `apps/admin`, `apps/web`, `packages/*`,
`supabase/`, `docs/`. Les TS sont gérés par un workspace pnpm + Turborepo. Le dossier
`supabase/` suit la convention de la CLI Supabase (au lieu de `database/` suggéré par la spec
technique §12, qui autorise une organisation documentée).

**Conséquences.** Une CI unique avec filtres de chemins ; contrats et fixtures partagés ;
admin et web public restent des déploiements séparés (surfaces d'attaque distinctes).
