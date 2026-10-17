# ADR-013 — Projection sans Internet

**Contexte.** Internet n'est pas fiable pendant les cultes (Q-08). La spec demande un écran
projeté dans un navigateur et un contrôleur distinct, reliés en temps réel.

**Décision.**
1. **Téléphone/tablette pilote** : l'app mobile démarre un serveur local (HTTP + WebSocket) qui
   sert la page de l'écran projeté. L'ordinateur relié au projecteur l'ouvre dans un navigateur
   (adresse locale affichée en QR code), via le Wi-Fi local ou le point d'accès du téléphone.
2. **Ordinateur seul** : app web installable (PWA), catalogue hors ligne, fenêtre de contrôle et
   fenêtre projetée reliées par `BroadcastChannel`.

Supabase Realtime n'est pas utilisé au MVP.

**Conséquences.** Faisabilité à démontrer en tâche 8.0 (serveur local sur iOS et Android,
autorisation « réseau local » iOS, app au premier plan pendant la projection). Sécurité : jeton
de session aléatoire dans l'URL, écran en lecture seule, serveur arrêté en fin de session.
