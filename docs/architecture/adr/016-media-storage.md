# ADR-016 — Stockage média (V2)

**Décision.** Les médias V2 (audio, partitions, preuves de droits) iront sur Cloudflare R2
derrière une abstraction `MediaStorage` (URLs signées pour les contenus restreints). Au MVP,
R2 sert uniquement aux sauvegardes de la base.

**Révision (2026-10-20, propriétaire).** Les enregistrements audio sont hébergés sur **Backblaze B2**
(compartiment public, en lecture seule). La base ne garde que la clé relative du fichier
(`audio_tracks.storage_key`, MP3 ou AAC, contrainte de la migration 0019). Le contenu publié
porte une clé `audio` pour les seuls cantiques qui ont un enregistrement diffusable (droits non
restreints). L'app compose l'adresse avec `AUDIO_BASE_URL` (HTTPS) ; si elle est vide, aucun
bouton « Écouter » n'apparaît. Les sauvegardes de la base restent un sujet distinct.

