# ADR-015 — Outils de contenu en TypeScript, contrats Zod

**Décision.** Le pipeline d'import (`packages/content_tools`) est écrit en TypeScript. Les
contrats de données (catalogue, release, programme partagé, diapositives) sont définis en Zod
dans `packages/shared_contracts` et exportés en JSON Schema. Des fixtures JSON partagées sont
validées à la fois en TS et en Dart.

**Conséquences.** Pas de quatrième langage (Python) dans le projet ; validation identique pour
l'import, le back-office et la CI.
