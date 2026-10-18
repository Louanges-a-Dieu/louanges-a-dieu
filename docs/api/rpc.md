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
programme non publié (brouillon ou archivé) : `null` (réponses indistinguables). La page
publique `apps/web` (`/programme/<jeton>`) affiche alors un message unique « Programme
indisponible ».

## Utilisateur connecté (`authenticated`)

| Fonction | Rôle |
|---|---|
| `sync_push_favorites(p_changes)` | `[{ hymnId, deleted? }]` — ajout / pierre tombale |
| `sync_push_playlist(p_playlist)` | `{ id, name, description?, deleted?, items: [{ hymnId, order }] }` — éléments remplacés en bloc |
| `sync_push_worship_service(p_service)` | `{ id, title, serviceDate?, status?, deleted?, items: [{ id?, hymnId?, label?, notes?, order }] }` |
| `sync_pull(p_since)` | `{ revision, favorites, playlists, worshipServices }` modifiés depuis `p_since` |
| `ensure_share_link(p_service_id)` | renvoie le lien actif (non révoqué, non expiré) ou en crée un — partager deux fois donne le **même** lien (0014) |
| `create_share_link(p_service_id, p_expires_at?)` | crée un **nouveau** lien (l'ancien cesse de fonctionner), renvoie le jeton |
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

## Back-office (Phase 9) — session avec second facteur (`aal2`) obligatoire

Depuis la migration 0015, `private.has_role()` ne reconnaît un rôle qu'avec une session
`aal2` (TOTP vérifié) : sans second facteur, un éditeur n'a **aucun** droit éditorial, même
en appelant l'API directement.

| Fonction | Rôle | Effet |
|---|---|---|
| `import_catalog_draft(p_draft, p_dry_run?)` | editor | charge un `catalog.draft.json` (jamais d'écrasement : A-20 / A-21) ; `p_dry_run` = diff de réimport sans écriture. Aussi utilisée par `content-tools load` |
| `preview_release(p_edition_id)` | editor | cantiques `added` / `changed` / `removed` si l'on publiait maintenant |
| `rollback_release(p_edition_id, p_release_id, p_notes?)` | editor | nouvelle release au contenu d'une release précédente |
| `search_hymns_admin(p_query?, p_status?, p_issues?, p_rights?, p_limit?, p_offset?, p_edition_id?)` | editor (RLS) | liste filtrée, recherche sans accents (numéro, titre, premier vers, texte) |
| `editorial_stats(p_edition_id?)` | editor | compteurs du tableau de bord (par édition, migration 0018) |
| `preview_hymn(p_hymn_id)` | editor | contenu exact qu'une publication enverrait (aperçu « comme sur mobile ») |
| `resolve_issues(p_issue_ids, p_status, p_note?)` | editor | résoudre / ignorer (justification obligatoire) / rouvrir ; auteur fixé par le serveur |
| `admin_list_team()`, `admin_grant_role(p_email, p_role)`, `admin_revoke_role(p_user_id, p_role)` | super_admin | équipe ; jamais de retrait du dernier super_admin |
| `admin_audit_log(p_record_id?, p_limit?, p_before?)` | editor | journal avec l'adresse de l'auteur |

## Amorçage du premier super_admin

Aucun compte n'est privilégié par défaut. Après la première inscription du responsable, le
propriétaire exécute une fois (SQL Editor du tableau de bord) :

```sql
insert into public.user_roles (user_id, role)
select id, 'super_admin' from auth.users where email = '<adresse du responsable>';
```

Les rôles suivants sont attribués depuis le back-office par ce super_admin.
