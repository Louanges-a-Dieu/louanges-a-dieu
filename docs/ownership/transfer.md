# Checklist de transfert de propriété (tâche 10.11)

À compléter et **signer par le propriétaire** à la remise du projet. Une case ne se coche
que lorsque le propriétaire a vérifié lui-même.

## Comptes (détail : `accounts.md`)

- [ ] Chaque service de l'inventaire appartient au propriétaire ou au titulaire désigné
- [ ] Double authentification active partout, codes de secours dans le coffre
- [ ] Au moins deux administrateurs désignés par le propriétaire sur chaque service qui le permet
- [ ] Domaine et DNS au nom du propriétaire

## Secrets

- [ ] Coffre de mots de passe du projet créé ; tous les secrets y figurent
- [ ] Mot de passe de la base de données **changé** après le développement (il a circulé dans
      une conversation pendant le développement)
- [ ] Jeton d'accès Supabase du développeur **révoqué** ; nouveau jeton créé par le propriétaire
- [ ] Clé d'envoi Android, clé API App Store Connect, clé de sauvegarde (age) : générées par le
      propriétaire, dans le coffre ; clé de sauvegarde aussi hors ligne
- [ ] Aucun secret détenu exclusivement par le développeur

## Dépôt et automatisation

- [ ] Dépôt privé dans l'organisation GitHub du propriétaire ; protection de `main`
      (job `ci-ok` requis, revue obligatoire)
- [ ] Environnements `staging` et `production` configurés (approbation du propriétaire pour
      `production`) avec les secrets et variables de `accounts.md`
- [ ] Une exécution réussie de : `ci`, `deploiement-base` (staging), `sauvegarde`
- [ ] Accès du développeur réduits (collaborateur externe) ou révoqués

## Capacité à continuer sans le développeur

- [ ] Le propriétaire a suivi `README.md` sur un poste neuf : installation, tests, lancement
- [ ] Le propriétaire a déployé une migration en staging avec `deploiement-base`
- [ ] Le propriétaire a restauré une sauvegarde (`docs/operations/backup-restore.md`)
- [ ] Le propriétaire a publié une release du catalogue depuis le back-office

| Rôle | Nom | Date | Signature |
|---|---|---|---|
| Propriétaire | | | |
| Développeur | | | |
