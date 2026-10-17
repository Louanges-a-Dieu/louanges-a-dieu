# ADR-011 — Aucune clé service_role dans les applications

**Décision.** Les apps n'utilisent que la clé publique (anon) et la session de l'utilisateur.
L'import passe par le back-office avec la session de l'éditeur, sous RLS. Les migrations sont
appliquées par la CLI Supabase avec un jeton d'accès stocké dans les environnements GitHub.

**Conséquences.** Un contrôle CI échoue si `service_role` apparaît dans le code des apps ou dans
une variable `NEXT_PUBLIC_*`.
