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


**Complément (2026-10-24, propriétaire).** Dépôt depuis le back-office : le navigateur envoie le
fichier directement à Backblaze (API native, `b2_upload_file`, règle CORS
`envoi-back-office`) avec une adresse d'envoi préparée par le serveur. La clé B2 (restreinte au
compartiment, lecture et écriture) reste côté serveur : exception limitée à ADR-011, qui ne
concerne que les clés Supabase. Karaoké : l'app préfère l'instrumental, qui reprend la
synchronisation de l'enregistrement principal s'il n'a pas la sienne.
