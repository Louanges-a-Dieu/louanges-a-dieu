import { afterEach, describe, expect, it, vi } from 'vitest';

import { checkYoutubeVideo, youtubeId } from '../src/lib/video';

describe('youtubeId : identifiant extrait du lien collé', () => {
  it.each([
    ['https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PL1', 'dQw4w9WgXcQ'],
    ['https://m.youtube.com/watch?feature=share&v=dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://youtu.be/dQw4w9WgXcQ?si=abc', 'dQw4w9WgXcQ'],
    ['youtu.be/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/shorts/a_b-c1D2e3F', 'a_b-c1D2e3F'],
    ['https://www.youtube.com/embed/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/live/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['  dQw4w9WgXcQ  ', 'dQw4w9WgXcQ'],
  ])('%s → %s', (link, id) => expect(youtubeId(link)).toBe(id));

  it.each([
    'https://vimeo.com/123456789',
    'https://www.youtube.com/@chaine',
    'https://www.youtube.com/playlist?list=PL123',
    'https://www.youtube.com/watch?v=court',
    'https://evil.example/watch?v=dQw4w9WgXcQ',
    'pas un lien',
    '',
  ])('%s est refusé', (link) => expect(youtubeId(link)).toBeNull());
});

describe('checkYoutubeVideo : vérification oEmbed', () => {
  afterEach(() => vi.unstubAllGlobals());

  function respond(response: Response | Error) {
    const fetchMock = vi.fn<(url: string) => Promise<Response>>(async () => {
      if (response instanceof Error) throw response;
      return response;
    });
    vi.stubGlobal('fetch', fetchMock);
    return fetchMock;
  }

  it('vidéo lisible : titre conservé', async () => {
    const fetchMock = respond(new Response(JSON.stringify({ title: ' Chorale du dimanche ' })));
    expect(await checkYoutubeVideo('dQw4w9WgXcQ')).toEqual({
      status: 'ok',
      title: 'Chorale du dimanche',
    });
    expect(String(fetchMock.mock.calls[0]?.[0])).toContain(
      encodeURIComponent('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    );
  });

  it('privée ou intégration interdite : refusée', async () => {
    respond(new Response('Unauthorized', { status: 401 }));
    expect(await checkYoutubeVideo('dQw4w9WgXcQ')).toEqual({ status: 'refused' });
  });

  it('inexistante : introuvable', async () => {
    respond(new Response('Not Found', { status: 404 }));
    expect(await checkYoutubeVideo('dQw4w9WgXcQ')).toEqual({ status: 'not_found' });
  });

  it('YouTube injoignable : non vérifiée', async () => {
    respond(new Error('réseau'));
    expect(await checkYoutubeVideo('dQw4w9WgXcQ')).toEqual({ status: 'unreachable' });
  });
});
