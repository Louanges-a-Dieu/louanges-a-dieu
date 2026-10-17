# ADR-016 — Stockage média (V2)

**Décision.** Les médias V2 (audio, partitions, preuves de droits) iront sur Cloudflare R2
derrière une abstraction `MediaStorage` (URLs signées pour les contenus restreints). Au MVP,
R2 sert uniquement aux sauvegardes de la base.
