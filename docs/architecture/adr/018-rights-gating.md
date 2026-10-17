# ADR-018 — Publication conditionnée par les droits

**Décision.** La vue `publishable_hymns` applique la règle du propriétaire (Q-02) : les statuts
`unknown`, `pending`, `cleared`, `public_domain` sont publiables ; `restricted` ne l'est pas.
La règle est centralisée et peut évoluer sans modifier les applications.

**Précision (2026-10-17).** La vue est créée `WITH (security_invoker = true)` : une vue Postgres
ordinaire s'exécute avec les droits de son propriétaire et contournerait la RLS.
