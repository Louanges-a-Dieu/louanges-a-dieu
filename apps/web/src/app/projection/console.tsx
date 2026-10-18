'use client';

import {
  goTo,
  hymnSlides,
  programSlides,
  slideLabel,
  stateMessage,
  type ProjectionState,
  type PublishedHymn,
  type Slide,
} from '@lad/shared-contracts';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { syncCatalog, type CatalogConfig, type StoredCatalog } from '@/lib/projection/catalog';
import { keyAction } from '@/lib/projection/keys';
import {
  listSavedPrograms,
  programEntries,
  removeProgram,
  type SavedProgram,
} from '@/lib/projection/saved-programs';
import { searchHymns } from '@/lib/projection/search';
import { openStore, type KeyValueStore } from '@/lib/projection/store';

import styles from './console.module.css';

type Source = { kind: 'hymn'; id: string } | { kind: 'program'; id: string };
type CatalogState = 'loading' | 'fresh' | 'cached' | 'missing';

const CHANNEL = 'lad-projection';
const SCREEN_URL = '/projection-ecran/screen.html?canal=local';

/**
 * Console du mode « ordinateur seul » (8.4, ADR-013) : recueil et programmes
 * conservés sur l'ordinateur, fenêtre projetée reliée par BroadcastChannel.
 * Tout fonctionne sans Internet une fois la page ouverte une première fois.
 */
export function ProjectionConsole({ config }: { config: CatalogConfig }) {
  const [store, setStore] = useState<KeyValueStore | null>(null);
  const [catalog, setCatalog] = useState<StoredCatalog | null>(null);
  const [catalogState, setCatalogState] = useState<CatalogState>('loading');
  const [offlineReady, setOfflineReady] = useState(false);
  const [programs, setPrograms] = useState<SavedProgram[]>([]);
  const [query, setQuery] = useState('');
  const [source, setSource] = useState<Source | null>(null);
  const [repeatRefrain, setRepeatRefrain] = useState(true);
  const [state, setState] = useState<ProjectionState>({ slides: [], index: 0, blank: false });
  const [screenSeen, setScreenSeen] = useState(0);
  const [now, setNow] = useState(0);
  const channel = useRef<BroadcastChannel | null>(null);
  const stateRef = useRef(state);

  const hymnsById = useMemo(
    () => new Map((catalog?.hymns ?? []).map((h) => [h.id, h] as const)),
    [catalog],
  );

  // Recueil et programmes locaux, puis mise à jour si Internet est là.
  useEffect(() => {
    let cancelled = false;
    void (async () => {
      const kv = await openStore();
      if (cancelled) return;
      setStore(kv);
      setPrograms(await listSavedPrograms(kv));
      const local = await kv.get<StoredCatalog>('catalog');
      if (local) {
        setCatalog(local);
        setCatalogState('cached');
      }
      if (!config.url) {
        if (!local) setCatalogState('missing');
        return;
      }
      const status = await syncCatalog(config, kv);
      if (cancelled) return;
      setCatalogState(status.kind);
      if (status.kind !== 'missing') setCatalog(status.catalog);
    })();
    return () => {
      cancelled = true;
    };
  }, [config]);

  // Service worker : la console et l'écran projeté restent disponibles hors ligne.
  useEffect(() => {
    if (!('serviceWorker' in navigator)) return;
    const onMessage = (event: MessageEvent) => {
      if (event.data?.type === 'warmed') setOfflineReady(true);
    };
    navigator.serviceWorker.addEventListener('message', onMessage);
    void navigator.serviceWorker
      .register('/sw.js', { scope: '/' })
      .then(() => navigator.serviceWorker.ready)
      .then((registration) => {
        const urls = [
          window.location.pathname,
          ...performance.getEntriesByType('resource').map((entry) => entry.name),
        ];
        registration.active?.postMessage({ type: 'warm', urls });
      })
      .catch(() => setOfflineReady(false));
    return () => navigator.serviceWorker.removeEventListener('message', onMessage);
  }, []);

  // Diapositives de la source choisie (recalculées après changement d'option).
  const slides = useMemo((): Slide[] => {
    if (!source) return [];
    const options = { repeatRefrain, maxLines: 6 };
    if (source.kind === 'hymn') {
      const hymn = hymnsById.get(source.id);
      return hymn ? hymnSlides(hymn, options) : [];
    }
    const program = programs.find((p) => p.id === source.id);
    return program ? programSlides(programEntries(program, hymnsById), options) : [];
  }, [source, repeatRefrain, hymnsById, programs]);

  // Option changée sur la même source : on reste sur la même section si elle
  // existe encore (ajustement pendant le rendu, sans effet en cascade).
  // Autre cantique ou programme : on repart du début.
  const [shownSource, setShownSource] = useState<Source | null>(null);
  if (state.slides !== slides) {
    const sameSource = shownSource === source;
    const current = JSON.stringify(state.slides[state.index] ?? null);
    const same = sameSource ? slides.findIndex((s) => JSON.stringify(s) === current) : -1;
    setShownSource(source);
    setState({ slides, index: same >= 0 ? same : 0, blank: state.blank });
  }

  // Fenêtre projetée : état envoyé à chaque changement, toutes les 2 s, et
  // dès qu'une fenêtre s'annonce.
  useEffect(() => {
    stateRef.current = state;
    channel.current?.postMessage(stateMessage(state));
  }, [state]);

  useEffect(() => {
    const bc = new BroadcastChannel(CHANNEL);
    channel.current = bc;
    bc.onmessage = (event) => {
      if (event.data?.type === 'hello') {
        setScreenSeen(Date.now());
        bc.postMessage(stateMessage(stateRef.current));
      }
    };
    const timer = setInterval(() => {
      setNow(Date.now());
      bc.postMessage(stateMessage(stateRef.current));
    }, 2000);
    return () => {
      clearInterval(timer);
      bc.close();
      channel.current = null;
    };
  }, []);

  const act = useCallback((action: ReturnType<typeof keyAction>) => {
    setState((s) => {
      switch (action) {
        case 'next':
          return goTo(s, s.index + 1);
        case 'previous':
          return goTo(s, s.index - 1);
        case 'first':
          return goTo(s, 0);
        case 'last':
          return goTo(s, s.slides.length - 1);
        case 'blank':
          return { ...s, blank: !s.blank };
        default:
          return s;
      }
    });
  }, []);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (target?.closest('input, textarea, select')) return;
      const action = keyAction(event.key);
      if (action) {
        event.preventDefault();
        act(action);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [act]);

  const results = useMemo(
    () => (catalog ? searchHymns(catalog.hymns, query, 30) : []),
    [catalog, query],
  );
  const current = state.slides[state.index] ?? null;
  const next = state.slides[state.index + 1] ?? null;
  const screenConnected = screenSeen > 0 && now - screenSeen < 6000;

  return (
    <div className={styles.console}>
      <header className={styles.header}>
        <div>
          <p className={styles.brand}>Louanges à Dieu</p>
          <h1 className={styles.title}>Projection</h1>
        </div>
        <ReadinessBadge
          catalogState={catalogState}
          count={catalog?.hymns.length ?? 0}
          offlineReady={offlineReady}
        />
      </header>

      <aside className={styles.sources}>
        <label className={styles.searchLabel} htmlFor="recherche">
          Cantique (numéro, titre ou premier vers)
        </label>
        <input
          id="recherche"
          className={styles.search}
          type="search"
          value={query}
          autoComplete="off"
          placeholder="37bis, Gloire…"
          disabled={!catalog}
          onChange={(e) => setQuery(e.target.value)}
        />
        {query && (
          <ul className={styles.list} aria-label="Résultats">
            {results.length === 0 && <li className={styles.muted}>Aucun cantique trouvé</li>}
            {results.map((h) => (
              <li key={h.id}>
                <button
                  type="button"
                  className={styles.item}
                  onClick={() => {
                    setSource({ kind: 'hymn', id: h.id });
                    setQuery('');
                  }}
                >
                  <HymnLine hymn={h} />
                </button>
              </li>
            ))}
          </ul>
        )}

        <h2 className={styles.sectionTitle}>Programmes préparés</h2>
        {programs.length === 0 ? (
          <p className={styles.muted}>
            Ouvrez le lien de partage d’un programme (avec Internet) et touchez « Préparer pour la
            projection hors ligne ».
          </p>
        ) : (
          <ul className={styles.list}>
            {programs.map((p) => (
              <li key={p.id} className={styles.programRow}>
                <button
                  type="button"
                  className={styles.item}
                  aria-current={source?.kind === 'program' && source.id === p.id}
                  onClick={() => setSource({ kind: 'program', id: p.id })}
                >
                  <span className={styles.itemTitle}>{p.title}</span>
                  {p.serviceDate && <span className={styles.muted}>{p.serviceDate}</span>}
                </button>
                <button
                  type="button"
                  className={styles.remove}
                  aria-label={`Retirer ${p.title}`}
                  onClick={async () => {
                    if (!store) return;
                    await removeProgram(store, p.id);
                    setPrograms(await listSavedPrograms(store));
                  }}
                >
                  ×
                </button>
              </li>
            ))}
          </ul>
        )}
      </aside>

      <main className={styles.stage}>
        <div className={styles.toolbar}>
          <button
            type="button"
            className={styles.primary}
            onClick={() => window.open(SCREEN_URL, 'lad-ecran', 'popup,width=1280,height=720')}
          >
            Ouvrir l’écran projeté
          </button>
          <span className={screenConnected ? styles.ok : styles.muted}>
            {screenConnected ? 'Écran projeté ouvert' : 'Aucun écran projeté'}
          </span>
          <label className={styles.option}>
            <input
              type="checkbox"
              checked={repeatRefrain}
              onChange={(e) => setRepeatRefrain(e.target.checked)}
            />
            Répéter le refrain après chaque couplet
          </label>
        </div>
        <p className={styles.help}>
          Faites glisser la fenêtre projetée sur l’écran du projecteur et cliquez dedans pour le
          plein écran. Raccourcis : → ou Page suivante, ← ou Page précédente, B ou « . » pour
          l’écran noir.
        </p>

        <Preview slide={current} blank={state.blank} />
        <p className={styles.muted}>
          {state.slides.length === 0
            ? 'Choisissez un cantique ou un programme.'
            : next
              ? `Ensuite : ${slideLabel(next)}`
              : 'Dernière diapositive'}
        </p>

        <div className={styles.controls}>
          <button
            type="button"
            className={styles.secondary}
            disabled={state.index === 0}
            onClick={() => act('previous')}
          >
            ‹ Précédente
          </button>
          <button
            type="button"
            className={state.blank ? styles.blankOn : styles.secondary}
            aria-pressed={state.blank}
            disabled={state.slides.length === 0}
            onClick={() => act('blank')}
          >
            Écran noir
          </button>
          <button
            type="button"
            className={styles.primary}
            disabled={state.index >= state.slides.length - 1}
            onClick={() => act('next')}
          >
            Suivante ›
          </button>
        </div>

        {state.slides.length > 0 && (
          <ol className={styles.slides} aria-label="Toutes les diapositives">
            {state.slides.map((slide, i) => (
              <li key={i}>
                <button
                  type="button"
                  className={i === state.index ? styles.slideCurrent : styles.slide}
                  aria-current={i === state.index}
                  onClick={() => setState((s) => goTo(s, i))}
                >
                  <span className={slide.kind === 'lyrics' ? styles.slideIndent : undefined}>
                    {slideLabel(slide)}
                  </span>
                  {slide.kind === 'lyrics' && (
                    <span className={styles.muted}> — {slide.lines[0]}</span>
                  )}
                </button>
              </li>
            ))}
          </ol>
        )}
      </main>
    </div>
  );
}

function HymnLine({ hymn }: { hymn: PublishedHymn }) {
  return (
    <>
      <span className={styles.number}>{hymn.numberLabel}</span>
      <span className={styles.itemTitle}>{hymn.title}</span>
    </>
  );
}

function ReadinessBadge({
  catalogState,
  count,
  offlineReady,
}: {
  catalogState: CatalogState;
  count: number;
  offlineReady: boolean;
}) {
  if (catalogState === 'loading') return <p className={styles.badge}>Préparation du recueil…</p>;
  if (catalogState === 'missing') {
    return (
      <p className={styles.badgeError}>
        Recueil non téléchargé : ouvrez cette page une fois avec Internet.
      </p>
    );
  }
  return (
    <p className={offlineReady || catalogState === 'cached' ? styles.badgeOk : styles.badge}>
      {count} cantiques · {offlineReady ? 'Prêt sans Internet' : 'Utilisable'}
    </p>
  );
}

function Preview({ slide, blank }: { slide: Slide | null; blank: boolean }) {
  return (
    <div className={styles.preview} data-theme="projection" aria-label="Aperçu de l’écran projeté">
      {blank ? (
        <p className={styles.previewBlank}>Écran noir</p>
      ) : slide === null ? null : slide.kind === 'title' ? (
        <div className={styles.previewContent}>
          <p className={styles.previewNumber}>{slide.numberLabel}</p>
          <p className={styles.previewTitle}>{slide.title}</p>
        </div>
      ) : slide.kind === 'section' ? (
        <div className={styles.previewContent}>
          <p className={styles.previewTitle}>{slide.label}</p>
        </div>
      ) : (
        <div
          className={
            slide.sectionType === 'refrain' ? styles.previewRefrain : styles.previewContent
          }
        >
          <p className={styles.previewSection}>
            {slide.numberLabel} · {slideLabel(slide)}
          </p>
          {slide.lines.map((line, i) => (
            <p key={i} className={styles.previewLine}>
              {line}
            </p>
          ))}
        </div>
      )}
    </div>
  );
}
