# ADR-009 — Ordre imprimé et ordre chanté

**Contexte.** Le livre imprime le refrain une fois ; il se chante après chaque couplet.

**Décision.** On stocke l'ordre imprimé. L'ordre chanté est calculé côté client. En projection,
le refrain est répété automatiquement après chaque couplet (Q-07), désactivable par programme.
En lecture, l'ordre imprimé est affiché par défaut.

**Conséquences.** Une seule fonction de séquencement, testée sur fixtures partagées Dart/TS.
