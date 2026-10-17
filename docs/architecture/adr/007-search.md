# ADR-007 — Recherche

**Décision.** Sur l'appareil : SQLite FTS5 (`unicode61 remove_diacritics 2`) alimenté par une
**normalisation applicative unique** (minuscules, diacritiques, `’`→`'`, `œ`→`oe`, espaces
insécables, ponctuation). Recherche par numéro (`37`, `37bis`, `37 bis`) traitée à part.
Serveur : Postgres FTS + `unaccent` pour le back-office. pgvector réservé à la V3.

**Conséquences.** La même table de cas de test valide la normalisation Dart et SQL.
