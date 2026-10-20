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

## 3. Rattacher un enregistrement à un cantique

Le back-office n'a pas encore d'écran pour cela. En attendant, dans l'éditeur SQL du tableau de bord
Supabase (base de développement d'abord) :

```sql
insert into public.audio_tracks (hymn_id, media_type, storage_key, duration_seconds, rights_status)
select h.id, 'melody', 'cantiques/0006/melodie.mp3', 185, 'cleared'
  from public.hymns h
 where h.number_label = '6';
```

- `media_type` : `melody`, `accompaniment`, `choir`, `soprano`, `alto`, `tenor`, `bass`,
  `instrumental` ou `other` (affichés « Mélodie », « Accompagnement », « Chorale »…).
- `duration_seconds` : facultatif (l'app lit la durée sur le fichier).
- Passages (facultatif) : `audio_segments` relie un intervalle (`start_ms`, `end_ms`) à une
  section ; l'écran d'écoute met alors en avant les paroles chantées et permet d'y aller d'un
  toucher. Sans passages, les paroles s'affichent dans l'ordre chanté.

Puis **publier une release** depuis le back-office : seuls les cantiques modifiés changent.

## 4. Configurer les apps

Ajouter l'adresse à la configuration de chaque environnement (`apps/mobile/config/<env>.json`) :

```json
"AUDIO_BASE_URL": "https://f00X.backblazeb2.com/file/louanges-a-dieu-audio"
```

HTTPS obligatoire (l'app refuse de démarrer sinon). Reconstruire l'app.

## Limites actuelles

- Lecture en flux : il faut Internet ; pas d'écoute hors connexion.
- La lecture s'arrête en quittant l'écran (pas de lecture en arrière-plan, écran verrouillé).
- Pas encore d'écran de dépôt ni de rattachement dans le back-office.
