# Base de données : migrations et tests

## Environnements

| Environnement | Projet Supabase | Usage |
|---|---|---|
| Développement | `ssvhoqpvxvfkhwxkewwl` | migrations et tests pendant le développement ; peut être réinitialisé |
| Recette / production | à créer avant la Phase 10 | jamais réinitialisés ; migrations par la CI uniquement |

## Secrets locaux

Stockés hors du dépôt dans `~/.config/louanges-a-dieu/supabase.env` (droits 600) :

```bash
export SUPABASE_ACCESS_TOKEN='sbp_fc…'   # jeton scoped, lecture seule (voir docs/ownership)
export SUPABASE_DB_PASSWORD='…'
```

Charger avant toute commande : `source ~/.config/louanges-a-dieu/supabase.env`.

## Appliquer les migrations

```bash
supabase link --project-ref ssvhoqpvxvfkhwxkewwl
supabase db push --linked
```

Nouvelle migration : `supabase migration new <nom>`. Une migration appliquée n'est **jamais**
modifiée : toute correction passe par une nouvelle migration (exemple : 0011).

## Lancer les tests pgTAP

Sans Docker, sur la base de développement :

```bash
pnpm --filter @lad/pgtap-runner test:db          # tous les fichiers
node tools/pgtap/run.ts 04                        # un fichier
```

Chaque fichier s'exécute dans une transaction annulée : aucune trace en base.

**TLS** : l'exécuteur vérifie le serveur avec le certificat CA de Supabase,
`supabase/ca/prod-ca-2021.crt` (public, versionné). À télécharger une fois depuis le tableau de
bord : *Project Settings → Database → SSL Configuration → Download certificate*. En attendant,
`PGTAP_INSECURE_TLS=1` autorise une connexion chiffrée sans vérification du serveur — base de
développement uniquement.

En CI (Docker disponible sur les runners) : `supabase db start`, `supabase db reset`,
`supabase test db`.

## Audit

```bash
supabase db advisors --linked --type all
```

Les seules alertes de sécurité acceptées sont listées dans `docs/architecture/security.md`.
