# ADR-002 — Riverpod pour l'état Flutter

**Contexte.** La spec impose Riverpod ou Bloc, choix à documenter. Besoins : injection de
dépendances testable, flux réactifs depuis Drift, moteur de synchronisation hors widgets, petite
équipe et maintenance par un successeur.

**Décision.** Riverpod.

**Justification.**
- DI et état unifiés, dépendances vérifiées à la compilation.
- Tests : `ProviderContainer` + `overrides` remplacent n'importe quel service (base, réseau).
- Les requêtes Drift (`Stream`) s'exposent directement en `StreamProvider`.
- Les services (sync, recherche) ne dépendent pas du `BuildContext`.
- Moins de code répétitif que Bloc (événements/états par écran).

Bloc reste pertinent quand il faut tracer chaque événement dans une grande équipe ; ce n'est
pas le besoin ici.

**Conséquences.** Règle de projet : la logique métier vit dans des classes testables
(repositories, services, notifiers), jamais dans les widgets.
