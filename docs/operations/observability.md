# Observabilité (tâche 10.5, Q-16)

Principe : savoir **qu'une erreur s'est produite et où**, sans jamais collecter de donnée
permettant d'identifier une personne ou d'ouvrir un lien privé.

## Serveur (`apps/web`, `apps/admin`)

`src/instrumentation.ts` → `@lad/observability/next` :

- **Toujours** : chaque erreur serveur est écrite en une ligne JSON dans les journaux de
  l'hébergeur (Vercel → Logs), par exemple :

  ```json
  {"level":"error","app":"web","time":"…","message":"Échec pour [adresse]","digest":"42",
   "method":"GET","path":"/programme/[jeton]?ref=…","route":"/programme/[token]","routeType":"render"}
  ```

- **Si `SENTRY_DSN` est défini** : l'erreur est aussi envoyée à Sentry, après filtrage.

Filtrage (testé avec le vrai SDK et un faux serveur Sentry) : jeton des liens de programme et
code de projection masqués, valeurs de recherche masquées, adresses e-mail et jetons longs
retirés des messages, **ni utilisateur, ni cookie, ni en-tête, ni corps de requête**, ni
valeurs des variables locales (`includeLocalVariables: false`), ni lignes de code voisines.

Aucun suivi dans le navigateur : les CSP restent fermées à toute origine externe.

## Application mobile

`lib/core/observability/crash_reporting.dart` (Sentry Flutter), activé seulement si
`SENTRY_DSN` est fourni au build (`config/<env>.json`). Désactivés : utilisateur, requêtes,
captures d'écran, arborescence d'écran, sessions, traces ; messages filtrés comme côté
serveur ; données des fils d'Ariane supprimées.

## Mise en service (propriétaire)

1. Créer une organisation Sentry au nom du projet (`louangesaDieu04@gmail.com`), région UE.
2. Créer deux projets : `louanges-mobile` (Flutter) et `louanges-web` (Next.js) ; noter
   leurs DSN (valeurs publiques).
3. Renseigner `SENTRY_DSN` : Vercel (projets `web` et `admin`, avec `APP_ENV=production`) et
   `apps/mobile/config/prod.json`.
4. Dans Sentry : désactiver « Store IP addresses » (paramètres de sécurité de l'organisation),
   activer le filtrage des données sensibles côté serveur (« Data Scrubber »).
5. Déclarer la collecte de **diagnostics de plantage** dans les fiches des stores (voir
   `docs/stores/`).

Sans DSN, tout fonctionne et rien n'est envoyé ; les journaux JSON du serveur restent
disponibles.
