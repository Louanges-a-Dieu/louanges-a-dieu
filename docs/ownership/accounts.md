# Inventaire des comptes et checklist de propriété

Principe : **aucun élément du projet ne dépend d'un compte personnel du développeur.**
Tout compte est créé avec l'adresse du projet et ses accès sont conservés dans le coffre de
secrets du propriétaire.

- Organisation : **Louanges à Dieu**
- Adresse e-mail du projet : `louangesaDieu04@gmail.com` (confirmée le 2026-10-17)
- Stores : publication via un **compte individuel** (décision Q-17). Le titulaire est une
  personne désignée par le propriétaire — jamais le développeur.

## Règles

1. Double authentification activée sur chaque compte, codes de secours dans le coffre.
2. Au moins **deux administrateurs** désignés par le propriétaire sur chaque service qui le permet.
3. Le développeur reçoit des accès **nominatifs et révocables** (invitation), jamais les
   identifiants du compte propriétaire.
4. Toute clé ou certificat généré est déposé dans le coffre le jour même.

## Checklist

| # | Service | Titulaire | Statut | Remarques |
|---|---|---|---|---|
| 1 | Adresse Gmail du projet `louangesaDieu04@gmail.com` | Propriétaire | ☑ | Activer la double authentification ; codes de secours dans le coffre |
| 2 | Coffre de secrets (ex. Bitwarden Organisation) | Propriétaire | ☐ | Stocke tous les identifiants ci-dessous |
| 3 | GitHub : organisation + dépôt privé `louanges-a-dieu` | Propriétaire | ☐ | Développeur invité comme membre |
| 4 | Supabase : projet de développement `ssvhoqpvxvfkhwxkewwl` ; projets `staging` et `prod` à créer plus tard | Propriétaire | ◐ | Vérifier que le projet appartient à une organisation au nom du projet |
| 5 | Vercel : équipe, projets `admin` et `web` | Propriétaire | ☐ | Vérifier l'offre (Hobby = usage personnel non commercial) |
| 6 | Cloudflare : compte (R2 pour sauvegardes, V2 médias) | Propriétaire | ☐ | — |
| 7 | Nom de domaine / DNS | Propriétaire | ☐ | Sous-domaines prévus : admin, web/projection |
| 8 | Apple Developer Program (individuel) | Titulaire désigné | ☐ | Vendeur affiché = nom légal du titulaire |
| 9 | Google Play Console (personnel) | Titulaire désigné | ☐ | Test fermé obligatoire (≥ 12 testeurs, 14 jours) avant la production |
| 9b | Service d'envoi d'e-mails (SMTP : Resend, Brevo, Postmark…) + domaine d'expédition vérifié | Propriétaire | ☐ | Indispensable avant la production (connexion par e-mail) — voir docs/deployment/auth-email.md |
| 10 | Sentry (suivi des plantages, Q-16) : organisation au nom du projet, région UE, projets `louanges-mobile` et `louanges-web` | Propriétaire | ☐ | `docs/operations/observability.md` ; facultatif (sans DSN, rien n'est envoyé) |
| 11 | Clé d'envoi Android + clé API App Store Connect | Propriétaire | ☐ | `docs/deployment/mobile-signing.md` |
| 12 | Clé de chiffrement des sauvegardes (age) + bucket R2 `louanges-sauvegardes` | Propriétaire | ☐ | Clé privée dans le coffre **et** hors ligne — `docs/operations/backup-restore.md` |
| 13 | Environnements GitHub `staging` et `production` (approbation du propriétaire pour `production`) | Propriétaire | ☐ | Secrets : `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_DB_URL`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` ; variables : `SUPABASE_PROJECT_REF`, `BACKUP_AGE_RECIPIENT`, `R2_ENDPOINT`, `R2_BACKUP_BUCKET` |

## Transfert final

Voir la checklist signée : `docs/ownership/transfer.md`.
