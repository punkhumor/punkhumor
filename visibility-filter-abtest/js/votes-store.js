/** Shared vote store: jsonblob (full list) + counterapi (durable tallies). */

const VOTE_BLOB_ID = "019fd160-4c05-761e-adaf-51047f77c55b";
const VOTE_BLOB_URL = `https://jsonblob.com/api/jsonBlob/${VOTE_BLOB_ID}`;
const COUNTER_NS = "vf-abtest-d882-live";
const COUNTER_BASE = `https://api.counterapi.dev/v1/${COUNTER_NS}`;

export function newVoteId() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return `v-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

export async function fetchRemoteVotes() {
  const res = await fetch(VOTE_BLOB_URL, {
    headers: { Accept: "application/json" },
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`blob ${res.status}`);
  const etag = res.headers.get("ETag");
  const data = await res.json();
  const votes = Array.isArray(data?.votes) ? data.votes : [];
  return { votes, etag, updatedAt: data?.updatedAt || null };
}

export async function putRemoteVotes(votes, etag) {
  const body = {
    votes,
    updatedAt: new Date().toISOString(),
  };
  const headers = {
    "Content-Type": "application/json",
    Accept: "application/json",
  };
  if (etag) headers["If-Match"] = etag;
  const res = await fetch(VOTE_BLOB_URL, {
    method: "PUT",
    headers,
    body: JSON.stringify(body),
  });
  if (res.status === 412) return { conflict: true };
  if (!res.ok) throw new Error(`blob put ${res.status}`);
  return { conflict: false, votes };
}

export async function appendRemoteVote(vote) {
  let lastErr = null;
  for (let i = 0; i < 6; i++) {
    try {
      const { votes, etag } = await fetchRemoteVotes();
      if (votes.some((v) => v.id === vote.id)) return votes;
      const next = votes.concat([vote]);
      const put = await putRemoteVotes(next, etag);
      if (put.conflict) continue;
      return next;
    } catch (err) {
      lastErr = err;
      await new Promise((r) => setTimeout(r, 120 + i * 80));
    }
  }
  throw lastErr || new Error("append failed");
}

export async function bumpRemoteTally(prefer) {
  const key = prefer === "B" ? "preferB" : "preferA";
  const res = await fetch(`${COUNTER_BASE}/${key}/up`, { cache: "no-store" });
  if (!res.ok) throw new Error(`counter ${res.status}`);
  const data = await res.json();
  return Number(data?.count) || 0;
}

export async function fetchRemoteTallies() {
  const read = async (key) => {
    try {
      const res = await fetch(`${COUNTER_BASE}/${key}/`, { cache: "no-store" });
      if (!res.ok) return null;
      const data = await res.json();
      return Number(data?.count);
    } catch {
      return null;
    }
  };
  const [A, B] = await Promise.all([read("preferA"), read("preferB")]);
  return { A, B };
}

export function mergeVotes(...lists) {
  const map = new Map();
  for (const list of lists) {
    for (const v of list || []) {
      if (!v || v.id == null) continue;
      map.set(String(v.id), v);
    }
  }
  return Array.from(map.values()).sort((a, b) => (a.at || 0) - (b.at || 0));
}
