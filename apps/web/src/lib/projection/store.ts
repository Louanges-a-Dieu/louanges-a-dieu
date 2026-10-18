/**
 * Petit magasin clé-valeur IndexedDB du mode « ordinateur seul » : recueil
 * téléchargé et programmes préparés, disponibles sans Internet. Données
 * publiques uniquement (cantiques publiés, programmes ouverts par un lien).
 */
export interface KeyValueStore {
  get<T>(key: string): Promise<T | undefined>;
  set(key: string, value: unknown): Promise<void>;
}

const DB_NAME = 'louanges-a-dieu';
const STORE = 'kv';

function request<T>(req: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function openStore(): Promise<KeyValueStore> {
  const open = indexedDB.open(DB_NAME, 1);
  open.onupgradeneeded = () => open.result.createObjectStore(STORE);
  const db = await request(open);
  return {
    async get<T>(key: string) {
      return (await request(db.transaction(STORE).objectStore(STORE).get(key))) as T | undefined;
    },
    async set(key, value) {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).put(value, key);
      await new Promise<void>((resolve, reject) => {
        tx.oncomplete = () => resolve();
        tx.onerror = () => reject(tx.error);
      });
    },
  };
}

/** Magasin en mémoire (tests, navigateur sans IndexedDB). */
export function memoryStore(): KeyValueStore {
  const map = new Map<string, unknown>();
  return {
    get: async <T>(key: string) => map.get(key) as T | undefined,
    set: async (key, value) => void map.set(key, structuredClone(value)),
  };
}
