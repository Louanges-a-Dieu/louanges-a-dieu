"""Adresse de connexion à la base liée (sauvegarde, .github/workflows/backup.yml).

Lit l'adresse du pooler (mode session) relevée par `supabase link` dans
supabase/.temp/pooler-url et y ajoute le mot de passe SUPABASE_DB_PASSWORD.

    python3 -I tools/backup/db-url.py
"""

import os
import urllib.parse as u
from pathlib import Path

pooler = Path(__file__).resolve().parents[2] / 'supabase/.temp/pooler-url'
p = u.urlsplit(pooler.read_text().strip())
user = u.quote(u.unquote(p.username or 'postgres'), safe='.')
password = u.quote(os.environ['SUPABASE_DB_PASSWORD'], safe='')
print(u.urlunsplit((p.scheme, f'{user}:{password}@{p.hostname}:{p.port or 5432}', p.path, p.query, '')))
