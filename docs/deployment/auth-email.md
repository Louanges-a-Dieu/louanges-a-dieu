# Connexion par e-mail (Supabase Auth + Resend)

L'application se connecte **sans mot de passe** (Q-13) : l'utilisateur reçoit un e-mail
contenant un **code** à saisir et un **lien** qui rouvre l'application. Les deux sont gérés par
l'app (`apps/mobile/lib/core/auth/auth_service.dart`).

## Pourquoi un service d'envoi dédié

Le projet Supabase (offre gratuite, créé après le 3 juin 2026) envoie par défaut **2 e-mails
par heure** et **interdit de modifier les modèles** (donc d'y ajouter le code). Brancher un
serveur SMTP dédié lève ces deux limites.

Service retenu : **Resend** — offre gratuite de 3 000 e-mails par mois (100 par jour), guide
officiel pour Supabase : <https://resend.com/docs/send-with-supabase-smtp>.

## Procédure (propriétaire)

### Étape 1 — Compte Resend au nom du projet

1. Créer un compte sur <https://resend.com> avec l'adresse du projet `louangesaDieu04@gmail.com`.
2. Activer la double authentification ; noter les codes de secours dans le coffre.

### Étape 2 — Domaine d'expédition

Les e-mails partent d'une adresse sur un domaine que vous contrôlez : un **sous-domaine
dédié**, qui isole la réputation d'envoi du domaine principal. **Choisi (2026-10-22)** :
`louanges.eglisedabidjan.com`, adresse d'expédition `connexion@louanges.eglisedabidjan.com`.
Le domaine est enregistré chez Infomaniak mais ses **DNS sont chez Cloudflare** : c'est là que
se font les enregistrements (Resend propose de les ajouter automatiquement dans Cloudflare).
Conseillé en plus : `TXT _dmarc.louanges` → `v=DMARC1; p=none;`.

1. Resend → **Domains → Add Domain** → saisir le sous-domaine ; région **Ireland (eu-west-1)**
   (même région que la base Supabase).
2. Resend affiche des enregistrements DNS (en général : un `TXT` DKIM, un `MX` et un `TXT` SPF
   sur un sous-domaine `send`). Les ajouter **tels quels** chez le gestionnaire DNS du domaine.
3. Revenir dans Resend → **Verify DNS Records**. La vérification peut prendre de quelques
   minutes à quelques heures.

### Étape 3 — Clé d'API Resend

Resend → **API Keys → Create API Key** : nom `supabase-auth`, permission **Sending access**
(envoi uniquement), limitée au domaine de l'étape 2. Copier la clé **directement** dans
Supabase (étape 4) et dans le coffre. **Ne jamais la transmettre par messagerie ou chat.**

### Étape 4 — Brancher Resend dans Supabase

Tableau de bord Supabase → projet → **Authentication → Emails → SMTP Settings** → activer
**Enable Custom SMTP** :

| Champ | Valeur |
|---|---|
| Sender email | `connexion@louanges.eglisedabidjan.com` (adresse du domaine vérifié) |
| Sender name | `Louanges à Dieu` |
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | la clé d'API de l'étape 3 |

Enregistrer.

### Étape 5 — Réglages de sécurité Auth

- **Authentication → Rate Limits** : « Rate limit for sending emails » → `30` par heure
  (suffisant ; à ajuster selon l'usage).
- **Authentication → Providers → Email** : « Email OTP Expiration » → `600` secondes (10 min) ;
  « Email OTP Length » : laisser `8`.
- **Authentication → URL Configuration → Redirect URLs** : ajouter
  `org.louangesadieu.app://login-callback/` et `http://localhost:8080`.

### Étape 6 — Modèles d'e-mail en français (avec le code)

**Authentication → Emails → Templates**. Le même contenu pour **Magic Link** (utilisateur
existant) et **Confirm signup** (première connexion).

Objet :

```text
Votre code de connexion — Louanges à Dieu
```

Corps (HTML) :

```html
<div style="font-family: Georgia, 'Times New Roman', serif; max-width: 480px; margin: 0 auto; color: #1F1A17;">
  <h2 style="font-weight: 600; margin-bottom: 24px;">Louanges à Dieu</h2>
  <p>Voici votre code de connexion :</p>
  <p style="font-size: 30px; letter-spacing: 6px; font-weight: 600; margin: 16px 0;">{{ .Token }}</p>
  <p>Saisissez-le dans l’application. Vous pouvez aussi toucher ce lien <strong>depuis votre téléphone</strong> :</p>
  <p><a href="{{ .ConfirmationURL }}" style="color: #8A6A35;">Se connecter à Louanges à Dieu</a></p>
  <p style="color: #6B625B; font-size: 13px; margin-top: 32px;">
    Ce code expire dans 10 minutes. Si vous n’avez pas demandé cette connexion, ignorez simplement ce message.
  </p>
</div>
```

Astuce : pour le second modèle, copier la vue **Source** du premier (Cmd + A, Cmd + C) plutôt
que recoller depuis ce document ; un collage partiel a déjà abîmé un modèle.

### Étape 7 — Vérification

Le développeur relit la configuration (lecture seule via l'API de gestion : SMTP actif,
modèles contenant `{{ .Token }}`, adresses de retour) puis un essai réel de connexion est fait
depuis l'aperçu web avec l'adresse du projet.

## Tests sans e-mail

`node tools/pgtap/create-test-user.ts` crée, sur la base de **développement uniquement**, deux
comptes à e-mail confirmé et mot de passe aléatoire (fichiers non versionnés dans
`apps/mobile/config/`) :

- `dev-test-user.json` : compte **durable**, sans rôle, utilisé par les tests web et admin ;
- `dev-test-user-disposable.json` : compte **jetable**, utilisé par
  `test/integration/supabase_user_sync_test.dart` (synchronisation réelle à deux appareils),
  qui le **supprime** à la fin : relancer le script avant un nouveau passage complet.
