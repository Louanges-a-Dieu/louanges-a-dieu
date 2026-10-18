# Connexion par e-mail (Supabase Auth)

L'application se connecte **sans mot de passe** (Q-13) : l'utilisateur reçoit un e-mail
contenant un **lien** qui rouvre l'application et, si le modèle d'e-mail le permet, un **code**
à saisir. Les deux sont gérés par l'app (`lib/core/auth/auth_service.dart`).

## État du projet de développement (2026-10-18)

| Réglage | Valeur | Conséquence |
|---|---|---|
| Serveur d'envoi | celui de Supabase (par défaut) | modèles d'e-mail **non modifiables** sur l'offre gratuite pour les projets créés après le 3 juin 2026 : lien seulement, pas de code |
| Limite d'envoi | **2 e-mails par heure** | suffisant pour tester, inutilisable en production |
| URL de retour autorisées | aucune | le lien de connexion ne peut pas rouvrir l'app |

## À configurer par le propriétaire

### 1. Adresses de retour autorisées (indispensable)

Tableau de bord Supabase → **Authentication → URL Configuration → Redirect URLs** :

```text
org.louangesadieu.app://login-callback/
http://localhost:8080
```

La première rouvre l'application mobile (schéma déclaré dans `AndroidManifest.xml` et
`Info.plist`) ; la seconde sert à l'aperçu web de développement.

### 2. Service d'envoi d'e-mails (indispensable avant la production)

Brancher un serveur SMTP dédié (**Authentication → Emails → SMTP Settings**) lève la limite de
2 e-mails/heure et permet de personnaliser les modèles, donc d'y ajouter le **code** :

```html
<p>Votre code de connexion : <strong>{{ .Token }}</strong></p>
<p>Ou touchez ce lien depuis votre téléphone : <a href="{{ .ConfirmationURL }}">Se connecter</a></p>
```

Fournisseurs possibles (offre gratuite suffisante au démarrage) : Resend, Brevo, Postmark,
Amazon SES. Il faut un **nom de domaine d'expédition** vérifié (enregistrements DNS SPF/DKIM),
par exemple un sous-domaine de `eglisedabidjan.com`. Le compte du fournisseur doit être créé au
nom du projet (`docs/ownership/accounts.md`).

## Tests sans e-mail

`node tools/pgtap/create-test-user.ts` crée, sur la base de **développement uniquement**, un
utilisateur de test à e-mail confirmé et mot de passe aléatoire (fichier non versionné
`apps/mobile/config/dev-test-user.json`). Le test `test/integration/supabase_user_sync_test.dart`
s'en sert pour une synchronisation réelle à deux appareils, puis supprime ce compte.
