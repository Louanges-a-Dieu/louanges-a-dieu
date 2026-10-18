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

## Preuve de faisabilité (tâche 8.0, 2026-10-18)

**Vérifié automatiquement sur ordinateur** (test `test/integration/projection_browser_test.dart`) :
le serveur local de l'app (`dart:io`, même code que sur le téléphone) sert la page de l'écran
à un **vrai navigateur Chrome** ; changement de diapositive sans rechargement (T-008) en
6–7 ms ; écran noir ; **coupure puis reprise** (même port, même code) avec conservation de la
dernière diapositive ; **aucune requête hors du serveur local** (polices comprises) ; fin de
session. Latence serveur → écran mesurée : médiane 0,09 ms en boucle locale.

**Non vérifiable sur ce poste** (ni SDK Android, ni Xcode complet) — à faire sur appareils réels,
voir la liste de contrôle de `docs/architecture/projection.md` : point d'accès du téléphone,
autorisation « réseau local » d'iOS, app en arrière-plan, réseau Wi-Fi de l'église.

**Décisions prises pendant la preuve.**
- **Code de session court** : 8 caractères sans ambiguïté (≈ 40 bits) au lieu de 128 bits, pour
  que l'adresse se tape sur l'ordinateur du projecteur (`http://192.168.43.1:47100/s/k7mx2qpa/`).
  Suffisant ici : écran en lecture seule, contenu public (cantiques déjà projetés au mur),
  serveur actif seulement pendant la projection, sur le réseau local ; toute autre adresse
  reçoit le même 404.
- **Port stable 47100** (autre port libre s'il est occupé) : la même adresse d'un culte à l'autre.
- **iOS** : le système coupe le réseau d'une app en arrière-plan ; le serveur est arrêté sans
  fin de session puis relancé à l'identique au retour, et l'écran se reconnecte seul.
- **Android** : l'autorisation `INTERNET` manquait dans le manifeste principal (présente
  seulement en debug) — corrigé ; sans elle, la version publiée n'aurait eu aucun accès réseau.
- **Écran maintenu allumé** : l'API Wake Lock exige une page sécurisée (HTTPS), ce qu'une adresse
  locale `http://` n'est pas ; la page invite alors à désactiver la mise en veille de l'ordinateur.
