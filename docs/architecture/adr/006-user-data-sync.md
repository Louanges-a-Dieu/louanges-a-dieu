# ADR-006 — Synchronisation des données utilisateur

**Décision.** Local-first : écriture immédiate dans SQLite + outbox. UUID générés par le client.
Push idempotent sous RLS, pull par `server_revision` (séquence serveur, insensible aux horloges
des appareils), tombstones `deleted_at`. Conflits : last-write-wins par ligne selon l'ordre de
réception serveur ; l'ordre des éléments d'une liste ou d'un programme est traité comme un tout ;
favoris fusionnés par union.

**Conséquences.** Simple et testable ; pas de fusion fine d'ordres concurrents (acceptable pour
l'usage visé). Les visiteurs n'ont que des favoris locaux (Q-05).
