# Import du recueil source

Le recueil n'est **jamais ressaisi** : il est importé depuis le fichier Word de l'édition de
référence (Q-01 : `Louanges à Dieu - 6ème édition (révisée v8).docx`, 30/09/2026).

```text
.docx ──► import ──► catalog.draft.json + report.html ──► load ──► cantiques en BROUILLON
                                                                     │
                       relecture éditoriale (back-office, Phase 9) ◄─┘
                                                                     │
                                       validation ──► publication (release)
```

## 1. Importer

```bash
node packages/content_tools/src/cli.ts import "<recueil.docx>" \
  --edition-name "Louanges à Dieu — 6ᵉ édition révisée (2026)" --edition-number 6
```

Sorties dans `content/out/` (hors Git, car elles contiennent les paroles) :

- `catalog.draft.json` : catalogue brouillon (contrat `CatalogDraft`) ;
- `report.html` : rapport d'anomalies, à ouvrir dans un navigateur.

La commande échoue si le **contrôle de fidélité** n'est pas conforme : le texte est relu par une
méthode indépendante et comparé vers par vers au catalogue produit.

## 2. Charger en brouillon

```bash
source ~/.config/louanges-a-dieu/supabase.env
node packages/content_tools/src/cli.ts load content/out/catalog.draft.json --as <uuid-éditeur> [--dry-run]
```

- Le chargement agit **en tant que l'éditeur indiqué** : droits, journal et règles du workflow
  s'appliquent.
- Tout cantique entre en **brouillon** ; rien n'est publié.
- Un cantique déjà en base n'est **jamais écrasé** : si la source a changé, une anomalie A-20
  est ouverte pour décision.
- Recharger le même fichier ne crée rien (idempotent).
- Outil de **développement** : en production, l'import passera par le back-office (Phase 9).

## Règles de structuration

| Élément | Reconnu par |
|---|---|
| Numéro | paragraphe centré en gras : `37`, `37bis` |
| Titre | premier paragraphe centré après le numéro (conservé tel qu'imprimé) |
| Strophe | commence par un retrait (1ʳᵉ ligne, ou gauche dans le second régime), se termine par un espacement après |
| Refrain | paragraphe encadré |
| Répétitions | `(bis)`, `(ter)`, `(4x)` laissés dans le texte ; annotés à la publication |
| Référence | paragraphe aligné à droite `— Psaumes 47 —` |
| « bis » | relation « même mélodie » proposée vers le numéro principal |

Rien d'autre n'est déduit : auteurs, compositeurs, thèmes, tonalités restent **vides**.

## Codes d'anomalie

| Code | Gravité | Signification |
|---|---|---|
| A-01 | à vérifier | Numéro absent de la séquence (ex. 666) |
| A-02 | info / à vérifier | Écart avec l'index alphabétique imprimé |
| A-03 | info | Second régime de mise en forme des strophes |
| A-04 | info | Sauts de ligne manuels (vers séparés automatiquement) |
| A-05 | à vérifier | Section de plus de 12 vers : séparation de strophes manquante ? |
| A-06 | à vérifier | Section d'un seul vers |
| A-07 | à vérifier | Refrain non italique, ou italique hors refrain |
| A-08 | à vérifier | Titre différent du premier vers (ex. « O » / « Ô ») |
| A-09 | à vérifier | Marqueur de répétition non standard, ambigu ou en milieu de vers |
| A-10 | info | Parenthèse conservée comme texte (réponse chantée) |
| A-11 | info | Orthographes différentes d'un livre biblique |
| A-12 | info / à vérifier | Texte en double ou proche d'un autre cantique |
| A-15 | **bloquant** | Cantique sans aucun vers |
| A-16 | **bloquant** | Numéro en double ou cantique principal introuvable |
| A-17 | à vérifier | Paragraphe inattendu |
| A-18 | **bloquant** | Référence biblique non analysable |
| A-19 | **bloquant** | Titre introuvable |
| A-20 | à vérifier | Réimport : la source diffère de la version en base (non écrasée) |
| A-21 | à vérifier | Réimport : cantique en base absent de la source |

Un cantique avec une anomalie **bloquante** ouverte ne peut pas être validé (contrôle en base).
Les autres peuvent être validés par lots (Q-03) après relecture.
