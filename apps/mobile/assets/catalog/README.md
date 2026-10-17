# Instantané du catalogue embarqué

`catalog_snapshot.json.gz` est **généré** (jamais versionné : il contient les paroles) par :

```bash
node packages/content_tools/src/cli.ts export-snapshot --config apps/mobile/config/<env>.json
```

Il permet la consultation et la recherche hors connexion dès l'installation (ADR-005).
Sans ce fichier, l'application télécharge le catalogue au premier accès réseau.
