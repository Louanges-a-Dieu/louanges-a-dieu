import { YoutubeId } from '@lad/shared-contracts';

/** Hôtes YouTube dont un lien peut désigner une vidéo. */
const HOSTS = new Set([
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtube-nocookie.com',
  'www.youtube-nocookie.com',
  'youtu.be',
]);

/**
 * Identifiant (11 caractères) d'une vidéo YouTube à partir du lien collé :
 * « youtube.com/watch?v=… », « youtu.be/… », « /shorts/… », « /embed/… »,
 * « /live/… », ou l'identifiant seul. `null` si ce n'est pas une vidéo.
 */
export function youtubeId(input: string): string | null {
  const text = input.trim();
  if (YoutubeId.safeParse(text).success) return text;
  let url: URL;
  try {
    url = new URL(/^https?:\/\//i.test(text) ? text : `https://${text}`);
  } catch {
    return null;
  }
  if (!HOSTS.has(url.hostname.toLowerCase())) return null;
  const parts = url.pathname.split('/').filter(Boolean);
  const candidate =
    url.hostname.toLowerCase() === 'youtu.be'
      ? parts[0]
      : parts[0] === 'watch'
        ? url.searchParams.get('v')
        : ['shorts', 'embed', 'live', 'v'].includes(parts[0] ?? '')
          ? parts[1]
          : null;
  return candidate && YoutubeId.safeParse(candidate).success ? candidate : null;
}

/** Adresse de la vidéo sur YouTube (lien « Ouvrir sur YouTube »). */
export const youtubeWatchUrl = (id: string) => `https://www.youtube.com/watch?v=${id}`;

/** Miniature publique de la vidéo (320 × 180). */
export const youtubeThumbnail = (id: string) => `https://i.ytimg.com/vi/${id}/mqdefault.jpg`;

export type YoutubeCheck =
  | { status: 'ok'; title: string | null }
  | { status: 'refused' }
  | { status: 'not_found' }
  | { status: 'unreachable' };

/**
 * Vérifie auprès de YouTube (oEmbed, sans clé) qu'une vidéo existe et peut
 * être lue dans un lecteur intégré, et lit son titre. Une vidéo non
 * répertoriée répond comme une vidéo publique ; une vidéo privée ou dont
 * l'intégration est désactivée est refusée (401).
 */
export async function checkYoutubeVideo(id: string): Promise<YoutubeCheck> {
  const base = process.env.YOUTUBE_OEMBED_URL || 'https://www.youtube.com/oembed';
  const url = `${base}?format=json&url=${encodeURIComponent(youtubeWatchUrl(id))}`;
  let response: Response;
  try {
    response = await fetch(url, { cache: 'no-store', signal: AbortSignal.timeout(8000) });
  } catch {
    return { status: 'unreachable' };
  }
  if (response.status === 401 || response.status === 403) return { status: 'refused' };
  if (response.status === 400 || response.status === 404) return { status: 'not_found' };
  if (!response.ok) return { status: 'unreachable' };
  try {
    const body = (await response.json()) as { title?: unknown };
    const title = typeof body.title === 'string' ? body.title.trim().slice(0, 300) : '';
    return { status: 'ok', title: title || null };
  } catch {
    return { status: 'ok', title: null };
  }
}
