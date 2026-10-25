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

// src/monitor.ts
function snapshot(rooms, users, parties, history, totals, time, capabilities) {
  const online = new Set(users.filter((a) => a.build === VERSION && time - a.seen < 15).map((a) => a.user));
  const liveParties = parties.filter((p) => p.members.some((u) => online.has(u)));
  const active = rooms.filter((r) => !["complete", "failed"].includes(r.phase));
  const matches = rooms.map((r) => {
    const players = Object.entries(r.roster).map(([id, m]) => ({ name: m.name, team: m.faction, online: online.has(id), host: id === r.authority }));
    return { id: r.id, playlist: r.playlist, mode: r.config.mode, map: r.config.map, phase: r.phase, epoch: r.epoch, capacity: players.length, online: players.filter((p) => p.online).length, disconnected: players.filter((p) => !p.online).length, host: r.roster[r.authority]?.name || "Selecting host", age_seconds: Math.max(0, Math.floor(time - r.born)), players, live: r.live || null };
  });
  const playlists = Object.entries(PLAYLISTS).map(([id, p]) => ({ id, name: p.name, team_size: p.size / 2, max_players: p.size, searching: users.filter((a) => a.playlist === id && a.queued && online.has(a.user)).length, parties: liveParties.filter((q) => q.playlist === id).length, playing: active.filter((r) => r.playlist === id && r.phase === "running").length, forming: active.filter((r) => r.playlist === id && r.phase !== "running").length }));
  const activeRows = matches.filter((r) => !["complete", "failed"].includes(r.phase));
  const modeNames = { 0: "Extraction", 1: "Iso Deathmatch", 2: "Team Deathmatch", 3: "Capture the Flag", 4: "Bomb Defusal" };
  return {
    release: "10.5-dev",
    protocol: VERSION,
    generated_at: time,
    scope: "master-coordinated matches only",
    offline_practice: "not tracked",
    capabilities,
    summary: { online_players: online.size, queued_players: users.filter((a) => a.queued && online.has(a.user)).length, parties: liveParties.length, playing_matches: active.filter((r) => r.phase === "running").length, forming_matches: active.filter((r) => !["running", "results"].includes(r.phase)).length, results_matches: active.filter((r) => r.phase === "results").length, disconnected_slots: activeRows.reduce((n, r) => n + r.disconnected, 0), ...totals },
    playlists,
    game_types: Object.entries(modeNames).map(([id, name]) => ({ id: Number(id), name, playing: active.filter((r) => r.phase === "running" && r.config.mode === Number(id)).length })),
    matches,
    recent: history.slice(-100).reverse()
  };
}
async function monitorAuthorized(request, token) {
  if (!token || token.length < 32) return false;
  const provided = request.headers.get("Authorization") || "";
  if (!provided.startsWith("Bearer ") || provided.length > 256) return false;
  const hash = (s) => crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  const [a, b] = await Promise.all([hash(provided.slice(7)), hash(token)]);
  const aa = new Uint8Array(a), bb = new Uint8Array(b);
  let difference = 0;
  for (let i = 0; i < aa.length; i++) difference |= aa[i] ^ bb[i];
  return difference === 0;
}
export {
  monitorAuthorized,
  snapshot
};
