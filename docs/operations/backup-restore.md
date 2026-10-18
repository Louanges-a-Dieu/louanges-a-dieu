# Sauvegarde et restauration (tâche 10.6)

## Ce qui est en place

| Niveau | Quoi | Où |
|---|---|---|
| Supabase | Sauvegardes quotidiennes automatiques (offre **Pro** ; l'offre gratuite n'en fournit pas de téléchargeables) | tableau de bord → Database → Backups |
| Projet | **Sauvegarde hebdomadaire** : rôles, schéma, données ; **restauration vérifiée** à chaque fois dans une base Supabase neuve de même version ; archive chiffrée (age) | `.github/workflows/backup.yml` → Cloudflare R2 |

La vérification restaure l'export complet dans un conteneur `supabase/postgres` neuf
(`tools/backup/verify-restore.sh`) et compare son empreinte à celle relevée sur la source
(`tools/backup/counts.sql` : nombre de lignes des tables importantes, dernière release,
empreinte du catalogue publié). Une sauvegarde qui ne se restaure pas à l'identique fait
**échouer** le workflow (notification GitHub).

## Mise en service (propriétaire, une fois)

1. **Clé de chiffrement** (sur votre ordinateur) : `age-keygen -o louanges-backup.key`.
   La ligne « public key: age1… » est la clé publique ; le fichier est la clé **privée** :
   la ranger dans le coffre de mots de passe **et** sur un support hors ligne. Sans elle,
   aucune sauvegarde ne peut être relue.
2. **Cloudflare R2** (compte au nom du projet) : créer le bucket `louanges-sauvegardes`,
   une règle de cycle de vie (suppression après 180 jours), et un jeton API « Object Read &
   Write » limité à ce bucket.
3. **GitHub** (dépôt → Settings → Environments → `production`) :
   - secrets : `SUPABASE_DB_URL` (chaîne de connexion de la base de production, mode
     « session », port 5432), `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` ;
   - variables : `BACKUP_AGE_RECIPIENT` (clé publique age), `R2_ENDPOINT`
     (`https://<compte>.r2.cloudflarestorage.com`), `R2_BACKUP_BUCKET`.
4. Lancer une première fois **à la main** (Actions → sauvegarde → Run workflow) et vérifier
   le message « Restauration vérifiée ».

## Restaurer après un incident

1. Créer un **nouveau** projet Supabase (même région `eu-west-1`), noter sa chaîne de
   connexion `NOUVELLE_URL`.
2. Télécharger l'archive voulue depuis R2, puis la déchiffrer :
   `age --decrypt -i louanges-backup.key -o sauvegarde.tar.gz <archive>.tar.gz.age`
   et `tar -xzf sauvegarde.tar.gz`.
3. Restaurer (psql 17) :

   ```sh
   psql "$NOUVELLE_URL" --single-transaction --variable ON_ERROR_STOP=1 \
     --file sauvegarde/roles.sql --file sauvegarde/schema.sql \
     --command 'set session_replication_role = replica' --file sauvegarde/data.sql
   ```

4. Contrôler : `psql "$NOUVELLE_URL" -At -f tools/backup/counts.sql | sort` doit être
   identique à `sort sauvegarde/source-counts.txt`.
5. Reconfigurer Auth (`docs/deployment/auth-email.md`), puis pointer les applications vers
   le nouveau projet (variables Vercel ; build mobile). Les applications mobiles gardent
   leur catalogue hors ligne pendant l'opération.

## Exercice

Restauration complète **à l'identique** à chaque sauvegarde (automatique). Une fois par
an, refaire la procédure « Restaurer après un incident » vers un projet temporaire, puis
le supprimer ; consigner la date ci-dessous.

| Date | Archive | Résultat | Par |
|---|---|---|---|
| — | — | — | — |
