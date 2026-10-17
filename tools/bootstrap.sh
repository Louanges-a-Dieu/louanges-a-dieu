#!/usr/bin/env bash
# Installe les dépendances du monorepo et vérifie l'outillage épinglé.
set -euo pipefail
cd "$(dirname "$0")/.."

need() { command -v "$1" >/dev/null 2>&1 || { echo "✗ $1 introuvable — voir README (Prérequis)"; exit 1; }; }

need node
need git
expected_node="$(cat .nvmrc)"
actual_node="$(node -p 'process.versions.node.split(".")[0]')"
[ "$actual_node" = "$expected_node" ] || { echo "✗ Node $expected_node attendu, $actual_node trouvé"; exit 1; }

corepack enable >/dev/null 2>&1 || true
need pnpm
pnpm install --frozen-lockfile

if command -v fvm >/dev/null 2>&1; then
  FLUTTER="fvm flutter"; fvm install
else
  FLUTTER="flutter"; need flutter
  expected_flutter="$(node -p 'JSON.parse(require("fs").readFileSync(".fvmrc","utf8")).flutter')"
  actual_flutter="$(flutter --version --machine | node -p 'JSON.parse(require("fs").readFileSync(0)).frameworkVersion')"
  [ "$actual_flutter" = "$expected_flutter" ] || echo "⚠ Flutter $expected_flutter attendu (.fvmrc), $actual_flutter trouvé"
fi
(cd apps/mobile && $FLUTTER pub get)

command -v supabase >/dev/null 2>&1 || echo "⚠ CLI Supabase absente (nécessaire pour la base locale)"
command -v docker >/dev/null 2>&1 || echo "⚠ Docker absent (nécessaire pour la base locale)"

echo "✓ Dépendances installées. Vérifier : pnpm turbo run lint typecheck test"
