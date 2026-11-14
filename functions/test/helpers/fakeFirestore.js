/**
 * Minimal in-memory Firestore that behaves like the real one for the calls
 * functions/livekit.js makes. Documents live at real paths
 * ("courses/c1/recordings/eg1"), so tests assert the EXACT documents written
 * instead of "some write happened".
 */

class Timestamp {
  constructor(ms) { this._ms = ms; }
  toMillis() { return this._ms; }
  static fromMillis(ms) { return new Timestamp(ms); }
}

const SERVER_TIMESTAMP = Object.freeze({ __serverTimestamp: true });

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v) && !(v instanceof Timestamp) && v !== SERVER_TIMESTAMP;
}

function resolveSentinels(value, nowMs) {
  if (value === SERVER_TIMESTAMP) return new Timestamp(nowMs);
  if (Array.isArray(value)) return value.map((v) => resolveSentinels(v, nowMs));
  if (isPlainObject(value)) {
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      if (v !== undefined) out[k] = resolveSentinels(v, nowMs);
    }
    return out;
  }
  return value;
}

function deepMerge(target, source) {
  const out = { ...target };
  for (const [k, v] of Object.entries(source)) {
    out[k] = isPlainObject(v) && isPlainObject(out[k]) ? deepMerge(out[k], v) : v;
  }
  return out;
}

function clone(v) {
  if (v instanceof Timestamp) return v;
  if (Array.isArray(v)) return v.map(clone);
  if (isPlainObject(v)) return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, clone(x)]));
  return v;
}

let autoId = 0;

class FakeFirestore {
  constructor() {
    this.docs = new Map(); // path -> data
    this.writes = []; // { op, path, data, merge }
    this.failWritesTo = null; // RegExp: writes to matching paths throw (failure injection)
  }

  // ── test helpers ──────────────────────────────────────────────────────
  seed(path, data) { this.docs.set(path, resolveSentinels(clone(data), Date.now())); }
  get(path) { return this.docs.has(path) ? clone(this.docs.get(path)) : undefined; }
  has(path) { return this.docs.has(path); }
  paths(prefix = "") { return [...this.docs.keys()].filter((p) => p.startsWith(prefix)).sort(); }
  writesTo(path) { return this.writes.filter((w) => w.path === path); }

  // ── Firestore API ─────────────────────────────────────────────────────
  collection(name) { return new CollectionRef(this, name); }
  collectionGroup(name) { return new Query(this, null, name); }

  _write(op, path, data, merge) {
    if (this.failWritesTo && this.failWritesTo.test(path)) {
      throw new Error(`injected write failure for ${path}`);
    }
    const resolved = resolveSentinels(clone(data), Date.now());
    this.writes.push({ op, path, data: resolved, merge: !!merge });
    if (op === "update") {
      if (!this.docs.has(path)) throw new Error(`NOT_FOUND: No document to update: ${path}`);
      this.docs.set(path, { ...this.docs.get(path), ...resolved });
    } else if (merge && this.docs.has(path)) {
      this.docs.set(path, deepMerge(this.docs.get(path), resolved));
    } else {
      this.docs.set(path, resolved);
    }
  }
}

class CollectionRef {
  constructor(db, path, parentDoc = null) {
    this._db = db;
    this.path = path;
    this.id = path.split("/").pop();
    this.parent = parentDoc;
  }
  doc(id) {
    const docId = id === undefined ? `auto_${++autoId}` : String(id);
    return new DocRef(this._db, `${this.path}/${docId}`, this);
  }
  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
  orderBy(field, dir = "asc") { return new Query(this._db, this.path, null).orderBy(field, dir); }
  where(field, op, value) { return new Query(this._db, this.path, null).where(field, op, value); }
  limit(n) { return new Query(this._db, this.path, null).limit(n); }
  get() { return new Query(this._db, this.path, null).get(); }
}

class DocRef {
  constructor(db, path, parent) {
    this._db = db;
    this.path = path;
    this.id = path.split("/").pop();
    this.parent = parent;
  }
  collection(name) { return new CollectionRef(this._db, `${this.path}/${name}`, this); }
  async get() { return snapshot(this._db, this); }
  async set(data, opts) { this._db._write("set", this.path, data, opts && opts.merge); }
  async update(data) { this._db._write("update", this.path, data, false); }
}

function snapshot(db, ref) {
  const exists = db.docs.has(ref.path);
  return { exists, id: ref.id, ref, data: () => (exists ? clone(db.docs.get(ref.path)) : undefined) };
}

function refForPath(db, path) {
  const parts = path.split("/");
  let ref = null;
  let col = null;
  for (let i = 0; i < parts.length; i += 2) {
    col = new CollectionRef(db, parts.slice(0, i + 1).join("/"), ref);
    ref = new DocRef(db, parts.slice(0, i + 2).join("/"), col);
  }
  return ref;
}

function sortable(v) {
  if (v instanceof Timestamp) return v.toMillis();
  return v;
}

class Query {
  constructor(db, collectionPath, groupName) {
    this._db = db;
    this._collectionPath = collectionPath;
    this._groupName = groupName;
    this._filters = [];
    this._order = null;
    this._limit = null;
  }
  where(field, op, value) {
    if (op !== "==") throw new Error(`FakeFirestore supports only '==' (got ${op})`);
    this._filters.push([field, value]);
    return this;
  }
  orderBy(field, dir = "asc") { this._order = [field, dir]; return this; }
  limit(n) { this._limit = n; return this; }
  async get() {
    let paths = [...this._db.docs.keys()].filter((p) => {
      const parts = p.split("/");
      if (this._groupName) return parts[parts.length - 2] === this._groupName;
      return parts.slice(0, -1).join("/") === this._collectionPath;
    });
    paths = paths.filter((p) => this._filters.every(([f, v]) => this._db.docs.get(p)[f] === v));
    if (this._order) {
      const [f, dir] = this._order;
      // Like Firestore: documents without the ordered field are excluded.
      paths = paths.filter((p) => this._db.docs.get(p)[f] !== undefined);
      paths.sort((a, b) => {
        const x = sortable(this._db.docs.get(a)[f]);
        const y = sortable(this._db.docs.get(b)[f]);
        return dir === "desc" ? (y > x ? 1 : y < x ? -1 : 0) : (x > y ? 1 : x < y ? -1 : 0);
      });
    }
    if (this._limit != null) paths = paths.slice(0, this._limit);
    const docs = paths.map((p) => snapshot(this._db, refForPath(this._db, p)));
    return { empty: docs.length === 0, size: docs.length, docs };
  }
}

module.exports = { FakeFirestore, Timestamp, SERVER_TIMESTAMP };
