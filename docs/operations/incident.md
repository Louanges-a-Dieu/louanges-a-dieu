# Gestion des incidents (runbook)

Premier réflexe : **les applications continuent de fonctionner hors ligne** (recueil embarqué,
projection locale). Un incident serveur n'empêche ni la lecture ni la projection.

| Symptôme | Vérifier | Action |
|---|---|---|
| Connexion impossible (« code invalide », pas d'e-mail) | Resend : envois et domaine ; Supabase → Auth → Logs ; limites de débit | Attendre la fin de la limite ; corriger le domaine/SMTP (`auth-email.md`) |
| Back-office : « Accès réservé » | Rôle dans la page Équipe ; second facteur configuré | Un super administrateur ajoute le rôle ; téléphone perdu : retirer le facteur (Supabase → Auth → Users → MFA) puis réenrôler |
| Mauvais contenu publié | Back-office → Publication → historique | **Revenir à ce contenu** sur la release précédente (les apps le reçoivent comme une mise à jour), puis corriger et republier |
| Erreurs serveur | Journaux Vercel (lignes JSON `"level":"error"`) ; Sentry | Corriger ; redéployer (Vercel) |
| Base indisponible | statut Supabase (status.supabase.com) | Attendre ; en cas de perte : `backup-restore.md` → « Restaurer après un incident » |
| Fuite d'un secret | Lequel, depuis quand | Le révoquer **immédiatement** chez le fournisseur, le remplacer dans le coffre et les environnements GitHub/Vercel, consigner |
| Lien de programme diffusé par erreur | — | L'auteur désactive le lien dans l'app (effet immédiat) |
| Projection : l'écran ne se connecte pas | Même réseau ? Réseau « invité » qui isole les appareils ? | Utiliser le point d'accès du téléphone ; ou le mode ordinateur seul (`/projection`) |

Après chaque incident : date, durée, cause, correction, mesure pour éviter qu'il se reproduise
— à consigner dans `docs/operations/incidents-log.md`.
