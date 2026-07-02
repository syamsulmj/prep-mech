// IndexedDB "outbox" for offline item-toggle mutations.
// One record per item URL (keyPath "url") so re-tapping an item overwrites its pending state.
const DB_NAME = "prepmech"
const DB_VERSION = 1
const STORE = "outbox"

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION)
    req.onupgradeneeded = () => {
      const db = req.result
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, {keyPath: "url"})
      }
    }
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error)
  })
}

function store(db, mode) {
  return db.transaction(STORE, mode).objectStore(STORE)
}

// Upsert: putting the same url overwrites the previous pending state (last tap wins).
export async function queueItem(url, status) {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const req = store(db, "readwrite").put({url, status, ts: Date.now()})
    req.onsuccess = () => resolve()
    req.onerror = () => reject(req.error)
  })
}

export async function allItems() {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const req = store(db, "readonly").getAll()
    req.onsuccess = () => resolve(req.result || [])
    req.onerror = () => reject(req.error)
  })
}

export async function removeItem(url) {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const req = store(db, "readwrite").delete(url)
    req.onsuccess = () => resolve()
    req.onerror = () => reject(req.error)
  })
}
