# Performance (tâche 10.4)

## Mesuré automatiquement

| Indicateur | Résultat | Mesure |
|---|---|---|
| Recherche dans le recueil réel (1 143 cantiques) | ≤ 14 ms | test Flutter sur le catalogue réel (Phase 4) |
| Serveur de projection → écran (boucle locale) | médiane ≈ 0,1 ms (serveur), 1 ms (jusqu'à l'affichage dans Chrome), max ≈ 8 ms | `projection_server_test`, `projection_browser_test` |
| Console ordinateur seul → fenêtre projetée | 5–7 ms | test de bout en bout `apps/web` |
| Catalogue complet téléchargé (console web) | ≈ 450 Ko compressés | API de développement |
| Exigence « < 300 ms en réseau local » | respectée avec une large marge en local | à confirmer sur Wi-Fi réel |

## À mesurer sur appareils (avec la recette)

| Indicateur | Cible | iPhone | Android bas de gamme |
|---|---|---|---|
| Démarrage à froid jusqu'à l'accueil | < 2 s | | |
| Recherche (frappe → résultats) | < 1 s (spec) | | |
| Taille installée | à consigner | | |
| Projection sur Wi-Fi de l'église (changement visible) | < 300 ms | | |
| Batterie : 1 h 30 de projection pilotée | à consigner | | |

Mesure du démarrage : `flutter run --release --trace-startup` (fichier
`build/start_up_info.json`) ou chronomètre sur 5 lancements, médiane.
