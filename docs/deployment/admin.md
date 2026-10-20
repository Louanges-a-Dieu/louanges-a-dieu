# Back-office `apps/admin` (Phase 9)

Hébergement prévu : **Vercel** (Q-15), projet distinct de `apps/web`, sur un compte au nom du
projet. Domaine dédié recommandé (par exemple `admin.<domaine>`), jamais indexé.

## Variables d'environnement

| Variable | Valeur |
|---|---|
| `SUPABASE_URL` | `https://<projet>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | clé `sb_publishable_…` (publique) |
| `AUDIO_BASE_URL` | facultative : adresse HTTPS des enregistrements (Backblaze B2, voir `audio-backblaze.md`) ; permet d'écouter un enregistrement sur la fiche d'un cantique |

**Aucune clé secrète** (ADR-011) : chaque action passe par la session de l'éditeur ; la base
applique la RLS, les déclencheurs de workflow et le journal. En local : copier `.env.example`
en `.env.local`.

## Accès

1. **Connexion** sans mot de passe : code reçu par e-mail (nécessite le service d'e-mail,
   voir `auth-email.md`, et le modèle contenant `{{ .Token }}`).
2. **Second facteur TOTP obligatoire** pour tout rôle éditorial : enrôlement guidé à la
   première connexion (Google Authenticator, Microsoft Authenticator, 2FAS…). La règle est
   appliquée **dans la base** (`has_role()` exige une session `aal2`, migration 0015) : sans
   second facteur, aucun droit éditorial, même en appelant l'API directement.
3. **Premier super administrateur** : après sa première connexion, le propriétaire exécute
   une fois dans le SQL Editor :

   ```sql
   insert into public.user_roles (user_id, role)
   select id, 'super_admin' from auth.users where email = '<adresse du responsable>';
   ```

   Les autres membres sont ajoutés depuis la page **Équipe** (la personne doit s'être
   connectée une fois). Le dernier super administrateur ne peut pas être retiré.

## Pages

| Page | Rôle | Contenu |
|---|---|---|
| Tableau de bord | éditeur | compteurs par statut, anomalies ouvertes, progression, dernière release |
| Cantiques | éditeur | recherche sans accents (numéro, titre, texte), filtres statut / anomalies / droits / édition, **validation par lots** (Q-03 : chaque refus est expliqué) |
| Cantique | éditeur | informations, sections (type, numéro, texte, ordre), références, liens, **registre des droits**, statut, anomalies, historique, **aperçu comme sur mobile** (contenu exact d'une publication) |
| Anomalies | éditeur | file filtrable ; résoudre, ignorer (justification obligatoire), rouvrir |
| Publication | éditeur | **diff** de la prochaine release, publication, historique, **retour arrière** (nouvelle release au contenu d'une précédente, reçue par les apps comme une mise à jour) |
| Import | éditeur | `catalog.draft.json` validé par le contrat Zod, **simulation** (diff de réimport) puis import ; jamais d'écrasement (A-20 / A-21) |
| Journal | éditeur | toutes les modifications, avec l'auteur |
| Équipe | super administrateur | membres, attribution et retrait de rôles |

L'archivage d'un cantique est réservé au super administrateur (règle de la base).

## Sécurité (9.12)

- CSP stricte à **nonce** par requête (`src/proxy.ts`) : `script-src 'self' 'nonce-…'
  'strict-dynamic'`, `connect-src 'self'` (le navigateur ne parle jamais à Supabase),
  `frame-ancestors 'none'`, `form-action 'self'`. Toutes les pages sont rendues à la demande
  (nécessaire au nonce). Aucun attribut `style` en ligne.
- En-têtes : `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: no-referrer`,
  `X-Robots-Tag: noindex`, `Cache-Control: private, no-store`, HSTS, `Permissions-Policy`.
- Toutes les entrées des actions serveur sont validées par **Zod** ; chemins de retour
  internes uniquement (pas de redirection ouverte).
- **Limitation de débit** : celle de Supabase Auth (par IP : 30 vérifications de code par
  5 min, 30 envois de code par heure ; envois d'e-mails : voir `auth-email.md`). Les appels
  partent du serveur du back-office : ces limites sont donc **communes** à toute l'équipe.
  Elles freinent une attaque (deviner un code TOTP est irréaliste à ce rythme) ; un abus
  pourrait bloquer temporairement les connexions. Parade si nécessaire : CAPTCHA d'Auth.

## Tests

- `pnpm --filter @lad/admin test` : validations, transitions, aperçu ; **accès par l'API
  réelle** (anonyme, compte sans rôle, éditeur sans second facteur : aucun accès ; avec : accès).
- `pnpm --filter @lad/admin e2e` (après `build`, Chrome, base de dev) : parcours complet —
  session sans second facteur → code TOTP → import → validation par lots → publication →
  **T-009** → retour arrière → anomalie justifiée → journal → équipe, sans violation de CSP.
  L'édition de test est supprimée à la fin.
- Comptes de test (base de développement uniquement) : `node tools/pgtap/create-test-editor.ts`
  (super administrateur avec second facteur, `apps/admin/e2e/.test-editor.json`, non versionné).
