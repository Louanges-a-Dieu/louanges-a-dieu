# ADR-008 — Fidélité textuelle

**Décision.** Le texte des cantiques est stocké **verbatim** (seule normalisation : Unicode NFC ;
espaces insécables conservés). Les marqueurs `(bis)`, `(ter)`, `(4x)`… restent dans le texte et
sont **en plus** annotés structurellement par ligne. Aucune métadonnée n'est déduite ou inventée :
inconnu = `NULL`, champ masqué.

**Conséquences.** Test d'import obligatoire : reconstitution ligne à ligne identique à la source.
L'annotation par ligne prépare la synchronisation audio de la V2.
