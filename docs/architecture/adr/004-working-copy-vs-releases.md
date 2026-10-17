# ADR-004 — Copie de travail et releases publiées

**Contexte.** T-009 : une modification admin reste en brouillon jusqu'à validation. Le schéma V1
porte un statut unique par cantique : modifier un cantique publié modifierait le contenu public.

**Décision.** Les éditeurs travaillent sur les tables éditoriales (copie de travail). La
publication crée une **release de catalogue immuable** (`catalog_releases`) dont le contenu
est figé dans `published_hymns(release_id, hymn_id, payload jsonb, payload_hash)`. Le public
ne lit que la release courante.

**Conséquences.** Publication atomique, retour arrière possible, synchronisation incrémentale
simple (diff entre releases). Coût : duplication du contenu publié (négligeable : ~1 Mo par release).
