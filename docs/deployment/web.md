# Site public `apps/web` (programmes partagés)

Hébergement prévu : **Vercel** (Q-15), sur un compte au nom du projet (voir
`docs/ownership/accounts.md`).

## Variables d'environnement

| Variable | Valeur | Remarque |
|---|---|---|
| `SUPABASE_URL` | `https://<projet>.supabase.co` | publique |
| `SUPABASE_PUBLISHABLE_KEY` | clé `sb_publishable_…` | publique ; **jamais** de clé secrète ou `service_role` |

En local : copier `apps/web/.env.example` en `apps/web/.env.local` (non versionné).

L'application mobile doit connaître l'adresse du site pour composer les liens :
`PUBLIC_WEB_URL` dans `apps/mobile/config/<env>.json` (HTTPS obligatoire hors `dev`).

## Page `/programme/<jeton>`

- Rendue côté serveur **à chaque requête** (aucun cache) : un lien désactivé cesse de
  fonctionner immédiatement.
- En-têtes : `X-Robots-Tag: noindex, nofollow, noarchive`, `Referrer-Policy: no-referrer`
  (le jeton ne fuit vers aucun autre site), `Cache-Control: private, no-store` ; plus
  `nosniff` et `X-Frame-Options: DENY` sur tout le site.
- Contenu (Q-09) : titre, date, numéros et titres des cantiques, moments libres et notes.
  Ni paroles, ni identité ou e-mail du créateur.
- Lien inconnu, désactivé, expiré ou programme non publié : **même** page « Programme
  indisponible » (impossible de deviner si un jeton a existé). Une panne du service affiche
  un message distinct, qui ne dit rien du jeton.

## Tests

- `pnpm --filter @lad/web test` : validation des réponses, jeton, appel avec la seule clé
  publique, rendu de la page.
- `test/integration/shared-program.real.test.ts` : partage de bout en bout avec le **vrai**
  serveur de développement (lien réutilisé, désactivé, dépublié, expiré, jeton au hasard).
  Exécuté seulement si `apps/web/.env.local` et `apps/mobile/config/dev-test-user.json`
  existent (ignoré en CI).

## En-têtes de sécurité

Tout le site : `nosniff`, `X-Frame-Options: DENY`, `Permissions-Policy` et une **CSP**
(`next.config.ts`) : aucune origine externe sauf Supabase (téléchargement du recueil par la
console), `object-src 'none'`, `frame-ancestors 'none'`, `base-uri 'none'`. Les pages
statiques ne pouvant porter de nonce, les scripts en ligne de Next sont admis. Le test de bout
en bout vérifie l'absence de toute violation.

## Page `/projection` (mode « ordinateur seul », Phase 8.4)

Page statique : `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY` sont lues **à la compilation**
(valeurs publiques). Le service worker `/sw.js` (en-tête `Cache-Control: no-cache`) ne met en
cache que `/projection`, `/projection-ecran/*`, `/_next/static/*`, le manifeste et les icônes ;
jamais les pages `/programme/*`. Voir `docs/architecture/projection.md`.

Test de bout en bout : `pnpm --filter @lad/web e2e` (après `pnpm build`, Chrome requis).
Next ne lit pas `.env.local` quand `NODE_ENV=test` : le test démarre le serveur en mode
production.
