#!/usr/bin/env bash
# Vérifie une sauvegarde (tâche 10.6) : restauration complète dans un Postgres
# Supabase NEUF, de la même version que le projet, puis comparaison de
# l'empreinte (nombre de lignes, dernière release, empreinte du catalogue)
# avec celle relevée sur la source au moment de la sauvegarde.
#
# Usage : tools/backup/verify-restore.sh <dossier contenant roles.sql,
#         schema.sql, data.sql et source-counts.txt>
# Prérequis : docker, psql, pg_isready.
set -euo pipefail

dir=${1:?dossier de sauvegarde attendu}
image=${SUPABASE_POSTGRES_IMAGE:-public.ecr.aws/supabase/postgres:17.11.0.003}
port=${RESTORE_PORT:-54329}
name=lad-restore-$$
here=$(cd "$(dirname "$0")" && pwd)

docker run -d --name "$name" -e POSTGRES_PASSWORD=postgres -p "127.0.0.1:${port}:5432" "$image" >/dev/null
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

url="postgresql://postgres:postgres@127.0.0.1:${port}/postgres"
# Restauration en super-utilisateur : les rôles réservés de Supabase
# (supabase_realtime_admin…) ne se modifient pas autrement.
admin="postgresql://supabase_admin:postgres@127.0.0.1:${port}/postgres"
for _ in $(seq 1 90); do
  pg_isready -d "$url" -q && break
  sleep 2
done
# L'image Supabase finit d'initialiser ses rôles après avoir accepté les connexions.
sleep 5

# Rôles des services Supabase (Realtime, Storage…) absents d'une image Postgres
# seule, mais présents dans tout projet Supabase : créés vides au préalable,
# pour que l'export des rôles (qui les modifie sans les créer) s'applique.
created=$({ grep -oE 'CREATE ROLE ("[^"]+"|[A-Za-z_][A-Za-z0-9_$]*)' "$dir/roles.sql" || true; } |
  sed -E 's/^CREATE ROLE //; s/"//g' | sort -u)
mentioned=$({ grep -oE '(ROLE|TO|GRANT|BY) ("[^"]+"|[A-Za-z_][A-Za-z0-9_$]*)' "$dir/roles.sql" || true; } |
  sed -E 's/^[A-Z]+ //; s/"//g' | { grep -vE '^(DEFAULT|CURRENT_USER|SESSION_USER|PUBLIC|SET)$' || true; } | sort -u)
echo "Rôles attendus avant restauration : $(echo $mentioned)"
for role in $(comm -23 <(echo "$mentioned") <(echo "$created")); do
  psql "$admin" --quiet --variable ON_ERROR_STOP=1 --variable role="$role" <<'SQL'
select format('create role %I nologin', :'role')
 where not exists (select 1 from pg_roles where rolname = :'role') \gexec
SQL
done

echo "Restauration (rôles, schéma, données) dans une base neuve…"
psql "$admin" --quiet --single-transaction --variable ON_ERROR_STOP=1 \
  --file "$dir/roles.sql" \
  --file "$dir/schema.sql" \
  --command 'set session_replication_role = replica' \
  --file "$dir/data.sql"

psql "$url" --no-align --tuples-only --file "$here/counts.sql" | sort > "$dir/restored-counts.txt"
if diff -u <(sort "$dir/source-counts.txt") "$dir/restored-counts.txt"; then
  echo "Restauration vérifiée : contenu identique à la source."
else
  echo "ÉCHEC : la base restaurée diffère de la source." >&2
  exit 1
fi
