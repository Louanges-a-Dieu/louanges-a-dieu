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
fichiers publics. Une clé d'écriture ne servira qu'à un futur outil de dépôt du back-office, et
restera côté serveur.

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

Fiche du cantique → **Enregistrements audio** → **Ajouter un enregistrement** :

- **Chemin du fichier** : chemin dans le compartiment, par exemple `cantiques/0006/melodie.mp3`
  (jamais l'adresse web complète : elle est refusée).
- **Version** : Mélodie, Accompagnement, Chorale, Soprano, Alto, Ténor, Basse, Instrumental ou
  Enregistrement.
- **Durée** : facultative (« 3:05 ») ; l'app la lit sur le fichier.
- **Droits** : un enregistrement « Restreint » n'est jamais diffusé.

Si `AUDIO_BASE_URL` est configurée pour le back-office, un lecteur permet d'écouter le fichier
directement sur la fiche (vérification du chemin).

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
