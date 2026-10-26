# ADR-020 — Vidéos des cantiques sur YouTube

**Contexte.** Le propriétaire veut des vidéos de cantiques (chorale, instrumental…) lues dans
l'application (2026-10-26).

**Décision.** Les vidéos sont hébergées sur **YouTube**, en visibilité **« Non répertoriée »**
avec **« Autoriser l'intégration »** coché, et lues dans l'app avec le lecteur YouTube intégré
(`youtube_player_iframe`, domaine `youtube-nocookie.com`). La base ne garde que l'identifiant
de la vidéo (`hymn_videos.youtube_id`, 11 caractères), jamais une adresse ; le back-office
l'extrait du lien collé et vérifie la vidéo auprès de YouTube (oEmbed : existence,
intégration autorisée, titre). Le payload publié gagne une clé `videos` seulement pour les
cantiques qui en ont (migration 0026), comme `audio` (ADR-016) ; une vidéo aux droits
« Restreint » n'est jamais publiée ; ajouter une vidéo ne repasse pas le cantique en brouillon.

**Raisons.** Gratuit (stockage et diffusion), qualité adaptée au réseau de chaque fidèle
(économie de données), envoi simple depuis YouTube Studio. Héberger les vidéos sur Backblaze
aurait coûté la bande passante et diffusé un seul fichier lourd, sans adaptation au réseau.

**Conséquences.**
- Internet obligatoire ; pas de lecture hors connexion ni écran éteint (règles de YouTube).
  L'app vérifie la connexion avant d'ouvrir le lecteur et explique sinon.
- « Non répertoriée » n'est pas « privée » : qui obtient le lien peut regarder la vidéo
  ailleurs. YouTube peut afficher des publicités.
- Pas de projection TV de la vidéo pour l'instant (choix du propriétaire).
- Les versions déjà installées ignorent la clé `videos` (clés inconnues ignorées).
