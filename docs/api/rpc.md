# API — fonctions RPC Supabase

Les applications n'utilisent que la clé **publishable** et la session de l'utilisateur.
Toutes les fonctions sont appelées par `POST /rest/v1/rpc/<nom>` (ou `supabase.rpc(...)`).

## Catalogue publié — accessible sans compte (`anon`)

| Fonction | Entrée | Sortie |
|---|---|---|
| `get_catalog_manifest()` | — | `{ releaseId, editionId, publishedAt, hymnCount, contentHash }` ou `null` |
| `get_catalog_snapshot(p_release_id?)` | numéro de release (dernière par défaut) | `{ releaseId, editionId, publishedAt, contentHash, hymns: PublishedHymn[] }` |
| `get_catalog_delta(p_from_release)` | release connue du client | `{ fromRelease, toRelease, fullSnapshotRequired, upserts: PublishedHymn[], removedIds: uuid[] }` |

`PublishedHymn` suit le contrat `packages/shared_contracts/src/hymn.ts`. Chaque ligne porte son
texte **verbatim** et, si un marqueur de fin de ligne est reconnu, `repeat: { count, marker }`.

## Programme partagé — accessible sans compte

| Fonction | Entrée | Sortie |
|---|---|---|
| `get_shared_program(p_token)` | jeton du lien | `{ title, serviceDate, items: [{ position, label, notes, hymn }] }` ou `null` |

`hymn` vaut `{ id, numberLabel, title }` (version publiée), `{ unavailable: true }` si le
cantique n'est pas publié, ou `null` pour une section libre. Lien inconnu, révoqué, expiré ou
programme non publié : `null` (réponses indistinguables).

## Utilisateur connecté (`authenticated`)

| Fonction | Rôle |
|---|---|
| `sync_push_favorites(p_changes)` | `[{ hymnId, deleted? }]` — ajout / pierre tombale |
| `sync_push_playlist(p_playlist)` | `{ id, name, description?, deleted?, items: [{ hymnId, order }] }` — éléments remplacés en bloc |
| `sync_push_worship_service(p_service)` | `{ id, title, serviceDate?, status?, deleted?, items: [{ id?, hymnId?, label?, notes?, order }] }` |
| `sync_pull(p_since)` | `{ revision, favorites, playlists, worshipServices }` modifiés depuis `p_since` |
| `create_share_link(p_service_id, p_expires_at?)` | crée ou remplace le lien, renvoie le jeton |
| `revoke_share_link(p_service_id)` | révoque immédiatement le lien |

Politique de conflit : la dernière écriture reçue par le serveur l'emporte (ADR-006).

## Back-office (rôle `editor` ou `super_admin`)

| Fonction | Rôle |
|---|---|
| `set_hymns_status(p_hymn_ids, p_status)` | validation par lots ; renvoie `(hymn_id, ok, error)` par cantique |
| `publish_release(p_edition_id, p_notes?)` | crée une release (idempotente si rien n'a changé) |

Transitions autorisées : `draft → review → published`, `review → draft`, `published → draft`
(automatique à toute modification de contenu), archivage et désarchivage par `super_admin`.
La validation est refusée si le cantique n'a aucune section, a une anomalie bloquante ouverte
ou des droits `restricted`.

## Amorçage du premier super_admin

Aucun compte n'est privilégié par défaut. Après la première inscription du responsable, le
propriétaire exécute une fois (SQL Editor du tableau de bord) :

```sql
insert into public.user_roles (user_id, role)
select id, 'super_admin' from auth.users where email = '<adresse du responsable>';
```

Les rôles suivants sont attribués depuis le back-office par ce super_admin.
