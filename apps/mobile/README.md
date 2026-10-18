# Application mobile « Louanges à Dieu »

Flutter (iOS, Android, tablettes) — Riverpod, go_router, Drift (SQLite + FTS5).
Architecture : `docs/architecture/` ; avancement : `IMPLEMENTATION_PLAN.md`.

## Configuration

Copier `config/dev.example.json` en `config/dev.json` (non versionné) et renseigner l'URL du
projet Supabase et sa clé **publishable**. Sans backend, l'app fonctionne hors connexion.

## Lancer

```bash
flutter run --dart-define-from-file=config/dev.json          # appareil ou simulateur
```

### Aperçu web (développement uniquement)

Cible web réservée à la prévisualisation des écrans sur un poste sans simulateur ; ce n'est pas
un livrable (le web public est `apps/web`). Dans le navigateur, l'instantané embarqué n'est pas
utilisé : le catalogue est téléchargé depuis le backend de développement.

```bash
flutter run -d web-server --web-port 8080 --dart-define-from-file=config/dev.json
# puis ouvrir http://localhost:8080 dans Chrome (fenêtre étroite pour simuler un téléphone)
```

`web/sqlite3.wasm` et `web/drift_worker.js` proviennent de la release `drift-2.35.2`
(empreintes SHA-256 vérifiées au téléchargement).

## Instantané du catalogue (hors connexion dès l'installation)

```bash
node ../../packages/content_tools/src/cli.ts export-snapshot --config config/dev.json
```

## Tests

```bash
flutter analyze && flutter test
dart run build_runner build --delete-conflicting-outputs   # après modification du schéma Drift
```

Les tests d'écran utilisent `test/support/app_harness.dart` (`testApp`) : application complète
sur une base en mémoire. Les opérations Drift doivent rester dans le temps simulé du test
(pas de `runAsync`) et passer par `settle()` hors des `pump`.
