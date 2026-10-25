// ../game/data/network_defaults.json
var network_defaults_default = {
  host_heartbeat_seconds: 20,
  host_stale_seconds: 60,
  browser_refresh_seconds: 15,
  queue_fallback_seconds: 5,
  request_timeout_seconds: 10,
  retry_cap_seconds: 30,
  socket_keepalive_seconds: 20,
  socket_stale_seconds: 90,
  authority_lease_seconds: 60,
  continuity_seconds: 5,
  clock_skew_seconds: 2,
  simulation_hz: 60,
  input_hz: 60,
  snapshot_min_hz: 20,
  snapshot_max_hz: 30
};

// src/control_policy.ts
var CONTROL = Object.freeze(network_defaults_default);

// src/core.ts
var VERSION = "10.5-discord2";
var PLAYLISTS = {
  duel_1v1: { size: 2, mode: 1, name: "1 v 1 Loners" },
  doubles_2v2: { size: 4, mode: 2, name: "2 v 2 Couples" },
  tactical_3v3: { size: 6, mode: 4, name: "3 v 3 Trios" },
  arena_4v4: { size: 8, mode: 2, name: "4 v 4 Quads" },
  bomb_defuse_5v5: { size: 10, mode: 4, name: "5 v 5 Squads" }
};
function modesForPlaylist(playlist) {
  return playlist === "duel_1v1" ? [2, 1, 3, 0, 4] : [2, 3, 0, 4];
}
function majority(ballots, options, size, random = Math.random) {
  if (!options.length) throw Error("No voting options");
  const counts = options.map((option) => ballots.filter((v) => v === option).length);
  const highest = Math.max(...counts);
  const leaders = options.filter((_v, i) => counts[i] === highest);
  return leaders[Math.max(0, Math.min(leaders.length - 1, Math.floor(random() * leaders.length)))];
}
function percentile(a, q) {
  const s = [...a].sort((a2, b) => a2 - b), x = (s.length - 1) * q;
  return s.length ? s[Math.floor(x)] + (s[Math.ceil(x)] - s[Math.floor(x)]) * (x % 1) : 0;
}
var MIN_PEER_UPLOAD_MBPS = 0.55;
function snapshotTicksForHost(host, people, reports, capacity, maximumHz = CONTROL.snapshot_max_hz) {
  if (maximumHz <= 20) return 3;
  const routes = people.filter((peer) => peer !== host).map((peer) => reports[peer]?.[host]);
  const upload = routes.length ? Math.min(...routes.map((route) => route && Number.isFinite(route.bytes) && Number.isFinite(route.seconds) && route.seconds > 0 ? route.bytes * 8 / route.seconds / 1e6 : 0)) : 0;
  if (people.length >= 6 && upload < 0.9) return 3;
  if (maximumHz >= 60 && capacity && capacity.cpu_p95_ms >= 0 && capacity.cpu_p95_ms <= 8 && capacity.samples >= 15 && upload >= (people.length <= 2 ? 1.2 : 2)) return 1;
  return 2;
}
function rankHosts(people, reports, capacity = {}) {
  const candidates = [];
  for (const id of people) {
    const pings = [], jitter = [], upload = [], losses = [];
    const hardware = capacity[id];
    if (hardware && (hardware.allow_host === false || !Number.isFinite(hardware.cpu_p95_ms) || hardware.cpu_p95_ms > 12 || hardware.cpu_p95_ms < 0 || hardware.logical_cpus < 2 || hardware.samples < 15)) continue;
    let valid = true;
    for (const peer of people.filter((p) => p !== id)) {
      const r = reports[peer]?.[id], reverse = reports[id]?.[peer];
      const usable = (r2) => !!r2 && Array.isArray(r2.rtts) && r2.rtts.length >= 45 && r2.rtts.length <= 50 && r2.rtts.every((v) => Number.isFinite(v) && v >= 0 && v <= 250) && Number.isInteger(r2.bytes) && r2.bytes > 0 && r2.bytes <= 5e5 && Number.isFinite(r2.seconds) && r2.seconds >= 0.1 && r2.seconds <= 5;
      if (!usable(r) || !usable(reverse)) {
        valid = false;
        break;
      }
      const throughput = r.bytes * 8 / r.seconds / 1e6;
      if (throughput < MIN_PEER_UPLOAD_MBPS || reverse.bytes * 8 / reverse.seconds / 1e6 < 0.05) {
        valid = false;
        break;
      }
      const mean = r.rtts.reduce((a, b) => a + b, 0) / r.rtts.length;
      pings.push(mean);
      upload.push(throughput);
      losses.push(100 * (1 - Math.min(r.rtts.length, reverse.rtts.length) / 50));
      jitter.push(...r.rtts.slice(1).map((v, i) => Math.abs(v - r.rtts[i])));
    }
    if (!valid || !pings.length || percentile(jitter, 0.95) > 40) continue;
    candidates.push({
      id,
      quality: pings.reduce((a, b) => a + b, 0) / pings.length + 0.25 * Math.max(...pings) + 2 * percentile(jitter, 0.95) + 8 * Math.max(...losses) + 8 / percentile(upload, 0.1) + (hardware ? hardware.cpu_p95_ms * 0.5 : 0),
      upload: percentile(upload, 0.1)
    });
  }
  return candidates.sort(
    (a, b) => a.quality - b.quality || b.upload - a.upload || a.id.localeCompare(b.id)
  ).map((p) => p.id);
}
function balancedTeams(people, ratings) {
  const half = people.length / 2;
  let best = [], difference = Infinity;
  const visit = (i, team) => {
    if (team.length === half) {
      const delta = Math.abs(
        people.reduce(
          (s, p) => s + (team.includes(p) ? 1 : -1) * (ratings[p] || 0),
          0
        )
      );
      if (delta < difference) {
        difference = delta;
        best = [...team];
      }
      return;
    }
    for (let j = i; j < people.length; j++) visit(j + 1, [...team, people[j]]);
  };
  visit(0, []);
  return new Set(best);
}
var b64 = (bytes) => {
  const a = new Uint8Array(bytes);
  let result = "";
  for (let i = 0; i < a.length; i += 8192)
    result += String.fromCharCode(...a.subarray(i, i + 8192));
  return btoa(result);
};
var unb64 = (text) => Uint8Array.from(atob(text), (ch) => ch.charCodeAt(0));
async function hash(text) {
  const a = typeof text === "string" ? new TextEncoder().encode(text) : text;
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", a))).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function publicKey(pem) {
  if (typeof pem !== "string" || pem.length > 8192) throw Error("Invalid key");
  return crypto.subtle.importKey(
    "spki",
    unb64(pem.replace(/-----[^-]+-----|\s/g, "")),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
}
function supportedIceServers(servers) {
  return servers.map((server) => ({
    ...server,
    urls: (Array.isArray(server.urls) ? server.urls : [server.urls]).filter(
      (url) => typeof url === "string" && (url.startsWith("stun:") || url.startsWith("turn:") && !/[?&]transport=(?:tcp|tls)(?:&|$)/i.test(url))
    )
  })).filter((server) => server.urls.length > 0);
}
function partyMatch(groups, ratings, size) {
  const half = size / 2;
  const candidates = groups.slice(0, 32).filter((g) => g.length > 0 && g.length <= half);
  for (let anchor = 0; anchor < candidates.length; anchor++) {
    let best;
    let visits = 0;
    const visit = (i, a, b, picked) => {
      if (++visits > 2e4) return;
      if (a.length === half && b.length === half) {
        const sum = (v) => v.reduce((s, p) => s + (ratings[p] || 0), 0);
        const delta = Math.abs(sum(a) - sum(b));
        if (!best || delta < best.delta) best = { people: picked, team: new Set(a), delta };
        return;
      }
      if (i >= candidates.length) return;
      const g = candidates[i];
      if (a.length + g.length <= half) visit(i + 1, [...a, ...g], b, [...picked, ...g]);
      if (b.length + g.length <= half) visit(i + 1, a, [...b, ...g], [...picked, ...g]);
      visit(i + 1, a, b, picked);
    };
    visit(anchor + 1, [...candidates[anchor]], [], [...candidates[anchor]]);
    if (best) return best;
  }
  return void 0;
}
export {
  MIN_PEER_UPLOAD_MBPS,
  PLAYLISTS,
  VERSION,
  b64,
  balancedTeams,
  hash,
  majority,
  modesForPlaylist,
  partyMatch,
  percentile,
  publicKey,
  rankHosts,
  snapshotTicksForHost,
  supportedIceServers,
  unb64
};
