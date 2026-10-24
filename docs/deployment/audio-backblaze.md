# Enregistrements audio sur Backblaze B2

Décision du propriétaire (2026-10-20, ADR-016 révisé) : les enregistrements des cantiques sont
hébergés sur **Backblaze B2**. La base ne contient que le **chemin** de chaque fichier ; l'app
compose l'adresse publique avec `AUDIO_BASE_URL`. Tant que cette adresse n'est pas configurée, ou
qu'un cantique n'a pas d'enregistrement publié, le bouton « Écouter » n'apparaît pas.

## 1. Créer l'espace de stockage (propriétaire)

1. Créer un compte sur [backblaze.com](https://www.backblaze.com) (B2 Cloud Storage), avec
   l'adresse du projet (louangesaDieu04@gmail.com) ; activer la double authentification.
2. **Buckets → Create a Bucket** :
   - nom : par exemple `louanges-a-dieu-audio` (unique chez Backblaze) ;
   - **Files in Bucket are : Public** (lecture publique, aucune écriture publique) ;
   - chiffrement : activé (SSE-B2) ; verrouillage d'objets : non.
3. Noter l'**adresse publique** affichée pour un fichier (« Friendly URL ») : elle a la forme
   `https://f00X.backblazeb2.com/file/louanges-a-dieu-audio/…`. La partie avant le chemin du
   fichier est `AUDIO_BASE_URL` :

   ```
   https://f00X.backblazeb2.com/file/louanges-a-dieu-audio
   ```

4. Facultatif, plus tard : placer un CDN (Cloudflare, gratuit avec B2 via la Bandwidth Alliance)
   devant le compartiment. Seule `AUDIO_BASE_URL` change ; les données restent les mêmes.

Aucune clé d'application Backblaze n'est nécessaire dans l'app : elle ne fait que lire des
fichiers publics. Seul le back-office a une clé d'écriture (envoi depuis la fiche, ci-dessous),
gardée côté serveur.

## 1 bis. Envoi depuis le back-office (une seule fois, propriétaire)

Le fichier part directement du navigateur vers Backblaze (il ne passe pas par Vercel, limité à
4,5 Mo par envoi) ; le serveur du back-office ne fait que préparer une adresse d'envoi.

1. **Application Keys → Add a New Application Key** :
   - nom : `back-office` ; **Allow access to Bucket(s)** : `CantiquesEA` seulement ;
   - **Type of Access : Read and Write** ; le reste vide.
   - Backblaze affiche une seule fois le `keyID` et l'`applicationKey` : les garder dans le
     gestionnaire de mots de passe. **Ne jamais les coller dans une conversation.**
2. **Vercel → louanges-admin → Settings → Environment Variables** : `B2_KEY_ID` et
   `B2_APPLICATION_KEY` (cocher « Sensitive »), puis **Redeploy**. Pour le back-office local,
   les ajouter à `apps/admin/.env.local`. `AUDIO_BASE_URL` doit aussi être renseignée : elle
   donne le nom du compartiment (sinon `B2_BUCKET`).
3. **Autoriser les envois du navigateur** (règle CORS, impossible depuis le tableau de bord
   Backblaze) : dans l'app Terminal,

   ```
   cd ~/louanges-a-dieu && ~/.local/bin/node tools/backblaze/autoriser-envoi.mts
   ```

   Le script demande une clé (saisie masquée, jamais enregistrée). Il faut le droit de modifier
   le compartiment : si la clé `back-office` est refusée, créer une clé temporaire **All
   buckets / Read and Write**, relancer, puis **supprimer** cette clé temporaire. Les autres
   règles CORS du compartiment sont conservées.

## 2. Préparer et déposer les fichiers

- Format : **MP3** (128 à 192 kb/s, mono ou stéréo) ou **AAC** (`.m4a`). Ce sont les seuls
  acceptés par la base (lisibles sur iOS, Android et navigateurs).
- Chemin conseillé : `cantiques/<numéro sur 4 chiffres><suffixe>/<version>.mp3`, par exemple
  `cantiques/0037bis/melodie.mp3`, `cantiques/0006/chorale.mp3`. Lettres sans accent, chiffres,
  `.`, `_`, `-` et `/` uniquement.
- Dépôt : **Upload/Download** dans le tableau de bord Backblaze (glisser-déposer).
- Droits : ne publier que des enregistrements dont la diffusion est autorisée. Une piste aux droits
  « restricted » (sur la piste ou dans le registre des droits) n'est jamais publiée.

## 3. Rattacher un enregistrement à un cantique (back-office)

**Envoi direct** (si 1 bis est fait) : fiche du cantique → **Enregistrements audio** →
**Ajouter un enregistrement** → choisir le fichier sur l'ordinateur, la version et les droits
(la durée est lue sur le fichier) → **Envoyer et ajouter**. Le fichier est rangé sous
`cantiques/<numéro>/<version>.mp3` (`-2`, `-3`… si ce nom est déjà pris : rien n'est jamais
écrasé), puis rattaché au cantique.

**Fichier déjà sur Backblaze** : **Fichier déjà sur Backblaze : indiquer son chemin** :

- **Chemin du fichier** : chemin dans le compartiment, par exemple `cantiques/0006/melodie.mp3`
  (jamais l'adresse web complète : elle est refusée).
- **Version** : Mélodie, Accompagnement, Chorale, Soprano, Alto, Ténor, Basse, Instrumental ou
  Enregistrement.
- **Durée** : facultative (« 3:05 ») ; l'app la lit sur le fichier.
- **Droits** : un enregistrement « Restreint » n'est jamais diffusé.

Si `AUDIO_BASE_URL` est configurée pour le back-office, le chemin est vérifié (un fichier
introuvable est refusé) et un lecteur permet d'écouter le fichier directement sur la fiche.

**Passages** (facultatif) : une ligne par début de passage, puis la fin.

```
0:00 Couplet 1
0:32 Refrain
1:05 #3
1:40 -
2:10 fin
```

Une section se désigne par son nom (« Couplet 2 », « Refrain ») s'il est unique dans le
cantique, sinon par « #n » (n-ième section imprimée) ; « - » marque un passage sans paroles.
L'app met alors en avant les paroles chantées et permet d'y aller d'un toucher. Vider le texte
retire les passages.

**Karaoké** (facultatif) : *Karaoké : synchroniser vers par vers* sur l'enregistrement
(il faut `AUDIO_BASE_URL` pour le back-office). « Démarrer », puis la touche **Espace** au tout
début de chaque vers surligné (les vers suivent l'ordre chanté, refrain après chaque couplet) ;
**P** dès que le chant s'arrête avant un passage instrumental (le vers s'éteint ; l'app affiche « Reprise dans N s ») ; **S** si l'enregistrement ne chante pas ce vers ; **Retour arrière** pour annuler le dernier
appui ; **Entrée** à la fin. Vérifier les temps affichés, puis « Enregistrer la
synchronisation ». L'app propose alors le **Karaoké** : le vers chanté en grand, rempli au rythme
du chant, avec le précédent et les suivants. Une synchronisation vers par vers remplace les
passages par section (et sert aussi à mettre en avant les paroles dans l'écoute normale).

**Instrumental pour le karaoké** : ajouter l'enregistrement sans la voix en version
**Instrumental**. S'il existe, l'app le joue d'abord dans le karaoké ; sinon un
« Accompagnement » synchronisé, sinon l'enregistrement principal. Un instrumental non
synchronisé reprend les temps de l'enregistrement principal synchronisé (la Mélodie d'abord) :
rien à faire s'il s'agit du même arrangement. Si ses temps diffèrent (introduction plus longue,
autre tempo), le synchroniser lui-même (outil karaoké sur sa piste, en suivant le chant de
mémoire). Les autres versions restent proposées au choix dans le karaoké.

Puis **publier** : l'enregistrement part avec la release suivante. Ajouter, modifier ou retirer
un enregistrement ne repasse **pas** le cantique en brouillon (le texte n'a pas changé) ; tout
est tracé dans le journal. Retirer un enregistrement ne supprime pas le fichier sur Backblaze.

## 4. Configurer les apps

Ajouter l'adresse à la configuration de chaque environnement de l'app
(`apps/mobile/config/<env>.json`) et, pour écouter depuis le back-office, à ses variables
(`AUDIO_BASE_URL`, voir `admin.md`) :

```json
"AUDIO_BASE_URL": "https://f00X.backblazeb2.com/file/louanges-a-dieu-audio"
```

HTTPS obligatoire (l'app refuse de démarrer sinon). Reconstruire l'app.

## Écoute dans l'app

- **Arrière-plan** : la lecture continue écran verrouillé ou app en arrière-plan, avec titre,
  version et commandes sur l'écran verrouillé, dans la notification (Android) et via le casque
  (`just_audio_background`). Elle s'arrête quand on quitte l'écran d'écoute.
- **Hors connexion** : « Télécharger pour écouter sans Internet » enregistre le fichier sur
  l'appareil (dossier de l'app, jamais sauvegardé ailleurs) ; l'écoute utilise alors ce fichier.
  Plus → Hors connexion indique la place occupée et permet de tout supprimer. Un fichier
  remplacé sur Backblaze avec un nouveau chemin est retéléchargé à la demande. Dans un
  navigateur, l'écoute reste en ligne uniquement.
- À vérifier sur appareils réels : `docs/qa/recette.md` (tests A-1 à A-7).
