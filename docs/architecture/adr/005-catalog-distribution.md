# ADR-005 — Distribution du catalogue

**Décision.** Le catalogue publié (~206 Ko gzip) est **embarqué dans l'app** à chaque build
(snapshot de la release courante + empreinte SHA-256), importé dans Drift au premier lancement,
puis mis à jour par deltas au niveau cantique (`get_catalog_delta(from_release)`) ou par
snapshot complet si l'écart est trop grand.

**Conséquences.** Mode avion fonctionnel dès l'installation. Application des mises à jour dans
une transaction ; le catalogue local n'est jamais vidé avant qu'un remplacement valide soit prêt.
