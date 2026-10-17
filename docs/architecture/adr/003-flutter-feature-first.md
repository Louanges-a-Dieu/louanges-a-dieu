# ADR-003 — Architecture Flutter feature-first

**Décision.** `lib/app` (bootstrap, routes, flavors), `lib/core` (design system, base Drift,
sync, recherche, réseau, l10n, logs), `lib/features/<feature>/{data,domain,presentation}`.
Navigation `go_router`. Modèles de domaine immuables. Repositories abstraits côté domaine.

**Conséquences.** Les évolutions V2 (audio, partitions, chorale) s'ajoutent comme nouvelles
features sans toucher aux existantes. Une feature n'importe jamais la couche `data` d'une autre.
