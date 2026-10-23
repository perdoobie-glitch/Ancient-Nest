// src/ownership.ts
async function ownership(env, steamId) {
  const base = { provider: "steam", has_access: false, checked_at: null };
  if (!/^[1-9][0-9]{0,9}$/.test(env.STEAM_APP_ID || "") || Number(env.STEAM_APP_ID) > 4294967295 || !env.STEAM_PUBLISHER_KEY) return { ...base, status: "not_configured", message: "Steam ownership checks require the game App ID and a server-side publisher key." };
  const url = new URL("https://partner.steam-api.com/ISteamUser/CheckAppOwnership/v4/");
  url.searchParams.set("key", env.STEAM_PUBLISHER_KEY);
  url.searchParams.set("steamid", steamId);
  url.searchParams.set("appid", env.STEAM_APP_ID);
  try {
    const response = await fetch(url, { redirect: "manual", signal: AbortSignal.timeout(6e3) });
    if (!response.ok) throw Error("provider_unavailable");
    const data = await response.json();
    const value = data.appownership;
    if (!value || typeof value.ownsapp !== "boolean") throw Error("invalid_provider_response");
    const granted = value.ownsapp === true && value.usercanceled !== true;
    return { ...base, status: granted ? "verified" : "not_owned", has_access: granted, checked_at: Math.floor(Date.now() / 1e3), permanent: value.permanent === true, message: granted ? "Steam reports an active game license. This does not establish a cash transaction." : "Steam reports no active game license." };
  } catch {
    return { ...base, status: "unavailable", message: "Steam ownership could not be checked. No access was granted." };
  }
}

// src/ranking.ts
var RANK_NAMES = ["Forgebound", "Striker", "Sentinel", "Vanguard", "Praetorian", "War Marshal", "Ascendant"];
function rank(rp) {
  const stage = Math.min(21, Math.floor(Math.max(0, rp) / 150) + 1);
  const name = stage === 21 ? "Angel" : RANK_NAMES[Math.floor((stage - 1) / 3)];
  const tier = ["I", "II", "III"][(stage - 1) % 3];
  return { number: stage, name, tier, league: stage === 21 ? "Angel" : name + " " + tier };
}
function performance(scores) {
  return scores.map((score) => {
    const above = scores.filter((s) => s > score).length;
    const tied = scores.filter((s) => s === score).length;
    return scores.length < 2 ? 100 : 100 - 50 * (above + (tied - 1) / 2) / (scores.length - 1);
  });
}
function elo(before, ownAverage, opponentAverage, outcome) {
  const expected = 1 / (1 + 10 ** ((opponentAverage - ownAverage) / 400));
  let delta = Math.round(32 * (outcome - expected));
  if (outcome === 1) delta = Math.max(1, delta);
  if (outcome === 0) delta = Math.min(-1, delta);
  return Math.max(1, before + delta);
}
function serviceCard(cards, includeUnplayed = false) {
  const played = cards.filter((c) => c.matches > 0), included = includeUnplayed ? cards : played;
  const mean = (values) => values.length ? values.reduce((a, b) => a + b, 0) / values.length : null;
  const weight = included.reduce((n, c) => n + Math.max(1, c.matches), 0);
  const eloAverage = weight ? included.reduce((n, c) => n + c.elo * Math.max(1, c.matches), 0) / weight : null;
  const eloValue = eloAverage === null ? 1 : Math.round(eloAverage);
  const rated = played.filter((c) => c.matches >= 3 && c.player_rating !== null);
  const rating = mean(rated.map((c) => c.player_rating));
  const rankInfo = rank(eloValue);
  const totals = Object.fromEntries(["matches", "wins", "losses", "draws", "kills", "deaths", "assists", "flags_captured", "flags_stopped"].map((key) => [key, cards.reduce((sum, c) => sum + c[key], 0)]));
  return { scope: "service", league: rankInfo.league, rank_level: rankInfo.number, elo: eloValue, elo_average: eloAverage, player_rating: rating === null ? null : Math.round(rating), rating_grade: ratingGrade(rating), ...totals, kd: totals.deaths ? totals.kills / totals.deaths : null, playlists_played: played.length, playlists_rated: rated.length, playlists_total: cards.length, averaging: includeUnplayed ? "match_weighted_all_playlists" : "match_weighted_played_playlists", rating_averaging: "equally_weighted_rated_playlists", has_record: played.length > 0 };
}
function ratingGrade(value) {
  if (value === null || !Number.isFinite(value)) return null;
  const rating = Math.round(Math.max(0, Math.min(100, value)));
  for (const [low, grade] of [[97, "A+"], [93, "A"], [90, "A\u2212"], [87, "B+"], [83, "B"], [80, "B\u2212"], [77, "C+"], [73, "C"], [70, "C\u2212"], [67, "D+"], [63, "D"], [60, "D\u2212"], [0, "F"]]) if (rating >= low) return grade;
  return "F";
}

// src/stats.ts
var ServiceError = class extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
  status;
  code;
};
var bad = (code, status = 400) => {
  throw new ServiceError(status, code);
};
var stamp = () => Math.floor(Date.now() / 1e3);
var hash = async (s) => [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)))].map((v) => v.toString(16).padStart(2, "0")).join("");
var id = (v) => {
  if (typeof v !== "string" || !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(v)) return bad("invalid_uuid");
  return v;
};
var tag = (v) => {
  if (typeof v !== "string" || !/^[A-Za-z0-9_.:-]{1,100}$/.test(v)) return bad("invalid_identifier");
  return v;
};
var count = (v) => {
  if (typeof v !== "number" || !Number.isInteger(v) || v < 0 || v > 1e4) return bad("invalid_counter");
  return v;
};
var avg = (a) => a.reduce((s, n) => s + n, 0) / a.length;
var PLAYLISTS = { duel_1v1: { name: "1v1 Duel", size: 2 }, doubles_2v2: { name: "2v2 Doubles", size: 4 }, tactical_3v3: { name: "3v3 Tactical", size: 6 }, arena_4v4: { name: "4v4 Arena", size: 8 }, bomb_defuse_5v5: { name: "5v5 Bomb Defuse", size: 10 } };
function playlist(value) {
  if (typeof value !== "string" || !Object.hasOwn(PLAYLISTS, value)) return bad("unsupported_playlist");
  return value;
}
async function profile(env, accountId, selection = "duel_1v1") {
  const selected = playlist(selection);
  const stored = (await env.ACCOUNTS_DB.prepare("SELECT * FROM player_playlist_stats WHERE account_id=?").bind(accountId).all()).results;
  const recent = (await env.ACCOUNTS_DB.prepare(`WITH ordered AS (
 SELECT r.*,m.playlist_id,m.game_type,m.map_id,m.hosting,ROW_NUMBER() OVER(PARTITION BY m.playlist_id ORDER BY ledger.rowid DESC) AS position
 FROM player_match_results r JOIN matches m ON m.id=r.match_id JOIN match_results ledger ON ledger.match_id=r.match_id
 WHERE r.account_id=? AND m.playlist_id IS NOT NULL)
 SELECT * FROM ordered WHERE position<=20 ORDER BY playlist_id,position`).bind(accountId).all()).results;
  const cards = Object.fromEntries(Object.entries(PLAYLISTS).map(([key, spec]) => {
    const stats = stored.find((r) => r.playlist_id === key) || { playlist_id: key, rp: 1, matches: 0, wins: 0, losses: 0, draws: 0, kills: 0, deaths: 0, assists: 0, flags_captured: 0, flags_stopped: 0 };
    const history = recent.filter((r) => r.playlist_id === key);
    const rankInfo = rank(stats.rp);
    const rating = stats.matches >= 3 && history.length >= 3 ? Math.round(avg(history.slice(0, 5).map((r) => r.performance))) : null;
    return [key, { ...stats, scope: "matchmaking", playlist_name: spec.name, elo: stats.rp, league: rankInfo.league, rank_level: rankInfo.number, rank: rankInfo, player_rating: rating, rating_grade: ratingGrade(rating), placement_matches: Math.min(3, stats.matches), placement_required: 3, kd: stats.deaths ? stats.kills / stats.deaths : null, recent_matches: history }];
  }));
  return { account_id: accountId, selected_playlist: selected, ...cards[selected], playlists: cards, service_card: serviceCard(Object.values(cards)) };
}
async function internalRatings(req, env, data) {
  await authorized(req, env);
  if (!Array.isArray(data.account_ids) || data.account_ids.length < 1 || data.account_ids.length > 10) bad("invalid_accounts");
  const ids = [...new Set(data.account_ids.map(id))];
  const ratings = {};
  for (const accountId of ids) {
    const account = await env.ACCOUNTS_DB.prepare("SELECT id FROM accounts WHERE id=? AND disabled=0").bind(accountId).first();
    if (!account) bad("unknown_account", 404);
    const rows = (await env.ACCOUNTS_DB.prepare("SELECT playlist_id,rp FROM player_playlist_stats WHERE account_id=?").bind(accountId).all()).results;
    ratings[accountId] = Object.fromEntries(Object.keys(PLAYLISTS).map((key) => [key, rows.find((r) => r.playlist_id === key)?.rp ?? 1]));
  }
  return { ratings };
}
async function authorized(req, env) {
  if (!env.COORDINATOR_API_KEY || env.COORDINATOR_API_KEY.length < 43) bad("coordinator_not_configured", 503);
  const expected = await hash("Bearer " + env.COORDINATOR_API_KEY), actual = await hash(req.headers.get("Authorization") || "");
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ actual.charCodeAt(i);
  if (diff) bad("coordinator_authorization_required", 401);
}
async function coordinator(req, env, data) {
  await authorized(req, env);
  const path = new URL(req.url).pathname.replace(/\/$/, "");
  const matchId = id(data.match_id);
  if (path === "/api/internal/matches/register") {
    if (data.scope !== "matchmaking") bad("only_matchmaking_is_rated");
    if (!["free_for_all", "team_deathmatch", "bomb_defuse", "capture_the_flag", "extraction"].includes(String(data.game_type))) bad("unsupported_game_type");
    if (!["player_hosted", "dedicated_server"].includes(String(data.hosting))) bad("unsupported_hosting");
    const map = tag(data.map_id), authority = tag(data.authority_id);
    if (!Array.isArray(data.roster) || data.roster.length < 2 || data.roster.length > 10) bad("human_roster_requires_2_to_10");
    if (data.roster.some((p) => !p || typeof p !== "object" || Array.isArray(p))) bad("invalid_roster_entry");
    const roster2 = data.roster.map((p) => ({ account_id: id(p.account_id), team: count(p.team) })).sort((a, b) => a.account_id.localeCompare(b.account_id));
    if (new Set(roster2.map((p) => p.account_id)).size !== roster2.length) bad("duplicate_player");
    if (data.game_type === "free_for_all") {
      if (roster2.some((p, i) => p.team !== i)) bad("ffa_teams_must_follow_sorted_account_order");
    } else {
      const a = roster2.filter((p) => p.team === 0).length, b = roster2.filter((p) => p.team === 1).length;
      if (!a || a !== b || a + b !== roster2.length) bad("balanced_human_teams_required");
    }
    const playlistId = playlist(data.playlist_id ?? Object.entries(PLAYLISTS).find(([_key, spec]) => spec.size === roster2.length)?.[0]);
    if (PLAYLISTS[playlistId].size !== roster2.length) bad("playlist_capacity_mismatch");
    const base = { scope: "matchmaking", game_type: data.game_type, hosting: data.hosting, map_id: map, authority_id: authority, roster: roster2 };
    const digest2 = await hash(JSON.stringify({ ...base, playlist_id: playlistId }));
    const existing = await env.ACCOUNTS_DB.prepare("SELECT registration_hash,status,playlist_id FROM matches WHERE id=?").bind(matchId).first();
    if (existing) {
      if (existing.registration_hash !== digest2 && (existing.playlist_id !== null || existing.registration_hash !== await hash(JSON.stringify(base)))) bad("match_id_conflict", 409);
      return { registered: true, duplicate: true, match_id: matchId, status: existing.status };
    }
    for (const player of roster2) {
      const account = await env.ACCOUNTS_DB.prepare("SELECT steam_id FROM accounts WHERE id=? AND disabled=0").bind(player.account_id).first();
      if (!account) bad("unknown_account", 404);
      if (env.REQUIRE_OWNERSHIP === "true" && !(await ownership(env, account.steam_id)).has_access) bad("game_license_required", 403);
    }
    const statements2 = [env.ACCOUNTS_DB.prepare("INSERT INTO matches(id,registration_hash,game_type,hosting,map_id,epoch,authority_id,created_at,expires_at,playlist_id) VALUES(?,?,?,?,?,1,?,?,?,?)").bind(matchId, digest2, data.game_type, data.hosting, map, authority, stamp(), stamp() + 14400, playlistId)];
    for (const p of roster2) {
      statements2.push(env.ACCOUNTS_DB.prepare("INSERT INTO player_playlist_stats(account_id,playlist_id) VALUES(?,?) ON CONFLICT DO NOTHING").bind(p.account_id, playlistId));
      statements2.push(env.ACCOUNTS_DB.prepare("INSERT INTO match_roster(match_id,account_id,team,starting_rp) SELECT ?,account_id,?,rp FROM player_playlist_stats WHERE account_id=? AND playlist_id=?").bind(matchId, p.team, p.account_id, playlistId));
      statements2.push(env.ACCOUNTS_DB.prepare("INSERT INTO active_participants(account_id,match_id) VALUES(?,?)").bind(p.account_id, matchId));
    }
    try {
      await env.ACCOUNTS_DB.batch(statements2);
    } catch {
      bad("match_registration_conflict_or_player_busy", 409);
    }
    return { registered: true, match_id: matchId, epoch: 1 };
  }
  const found = await env.ACCOUNTS_DB.prepare("SELECT * FROM matches WHERE id=?").bind(matchId).first();
  if (!found) bad("unknown_match", 404);
  const match = found;
  if (path === "/api/internal/matches/review") {
    const reason = tag(data.reason);
    const evidence = JSON.stringify({ reason, reports: data.reports || [], sample_report: data.sample_report || null, absent: data.absent || [] });
    await env.ACCOUNTS_DB.batch([
      env.ACCOUNTS_DB.prepare("INSERT INTO match_reviews(match_id,reason,evidence,created_at) VALUES(?,?,?,?) ON CONFLICT(match_id) DO NOTHING").bind(matchId, reason, evidence, stamp()),
      env.ACCOUNTS_DB.prepare("UPDATE matches SET status='void' WHERE id=? AND status='active'").bind(matchId),
      env.ACCOUNTS_DB.prepare("DELETE FROM active_participants WHERE match_id=? AND EXISTS(SELECT 1 FROM matches WHERE id=? AND status='void')").bind(matchId, matchId)
    ]);
    return { status: "pending_review", rank_changed: false };
  }
  if (path === "/api/internal/matches/migrate") {
    const authority = tag(data.authority_id), epoch = count(data.previous_epoch);
    if (match.status !== "active" || match.expires_at < stamp()) bad("match_not_active", 409);
    const changed = await env.ACCOUNTS_DB.prepare("UPDATE matches SET epoch=epoch+1,authority_id=? WHERE id=? AND epoch=? AND status='active' RETURNING epoch").bind(authority, matchId, epoch).first();
    if (!changed) bad("stale_authority_epoch", 409);
    return changed;
  }
  if (path === "/api/internal/matches/void") {
    await env.ACCOUNTS_DB.batch([env.ACCOUNTS_DB.prepare("UPDATE matches SET status='void' WHERE id=? AND status='active'").bind(matchId), env.ACCOUNTS_DB.prepare("DELETE FROM active_participants WHERE match_id=? AND EXISTS(SELECT 1 FROM matches WHERE id=? AND status='void')").bind(matchId, matchId)]);
    return { status: match.status === "finalized" ? "finalized" : "void" };
  }
  if (path !== "/api/internal/matches/result") bad("not_found", 404);
  if (count(data.epoch) !== match.epoch || tag(data.authority_id) !== match.authority_id) bad("stale_authority_epoch", 409);
  const roster = (await env.ACCOUNTS_DB.prepare("SELECT * FROM match_roster WHERE match_id=? ORDER BY account_id").bind(matchId).all()).results;
  if (!Array.isArray(data.players) || data.players.length !== roster.length) bad("complete_roster_required");
  if (data.players.some((p) => !p || typeof p !== "object" || Array.isArray(p))) bad("invalid_player_entry");
  const players = data.players.map((p) => ({ account_id: id(p.account_id), kills: count(p.kills), deaths: count(p.deaths), assists: count(p.assists), flags_captured: count(p.flags_captured), flags_stopped: count(p.flags_stopped) })).sort((a, b) => a.account_id.localeCompare(b.account_id));
  if (players.some((p, i) => p.account_id !== roster[i].account_id)) bad("roster_does_not_match");
  if (match.game_type !== "capture_the_flag" && players.some((p) => p.flags_captured || p.flags_stopped)) bad("flags_not_supported_in_this_game_type");
  let winner = null;
  if (match.game_type !== "free_for_all") {
    if (data.winner_team !== null && data.winner_team !== 0 && data.winner_team !== 1) bad("invalid_winner");
    winner = data.winner_team;
  }
  const digest = await hash(JSON.stringify({ match_id: matchId, epoch: match.epoch, authority_id: match.authority_id, winner_team: winner, players }));
  const prior = await env.ACCOUNTS_DB.prepare("SELECT result_hash FROM match_results WHERE match_id=?").bind(matchId).first();
  if (prior) {
    if (prior.result_hash !== digest) bad("conflicting_result", 409);
    return { committed: true, duplicate: true, match_id: matchId };
  }
  if (match.status !== "active" || match.expires_at < stamp()) bad("match_not_active", 409);
  const scores = players.map((p) => 4 * p.kills - 4 * p.deaths + p.assists + 4 * p.flags_captured + 4 * p.flags_stopped), ratings = performance(scores), time = stamp();
  const statements = [env.ACCOUNTS_DB.prepare("INSERT INTO match_results(match_id,result_hash,committed_at,epoch,authority_id) VALUES(?,?,?,?,?)").bind(matchId, digest, time, match.epoch, match.authority_id)];
  for (let i = 0; i < players.length; i++) {
    const p = players[i], r = roster[i], own = roster.filter((p2) => p2.team === r.team), opponents = roster.filter((p2) => p2.team !== r.team);
    const outcome = match.game_type === "free_for_all" ? avg(scores.filter((_s, j) => j !== i).map((s) => scores[i] > s ? 1 : scores[i] === s ? 0.5 : 0)) : winner === null ? 0.5 : r.team === winner ? 1 : 0;
    const next = elo(r.starting_rp, avg(own.map((p2) => p2.starting_rp)), avg(opponents.map((p2) => p2.starting_rp)), outcome);
    const ownMean = avg(own.map((p2) => p2.starting_rp)), otherMean = avg(opponents.map((p2) => p2.starting_rp));
    const expected = 1 / (1 + 10 ** ((otherMean - ownMean) / 400));
    let legacyDelta = Math.round(32 * (outcome - expected));
    if (outcome === 1) legacyDelta = Math.max(1, legacyDelta);
    if (outcome === 0) legacyDelta = Math.min(-1, legacyDelta);
    const after = match.playlist_id === null ? Math.max(0, Math.min(3200, r.starting_rp + legacyDelta)) : next;
    if (match.playlist_id !== null) statements.push(env.ACCOUNTS_DB.prepare("INSERT INTO rating_floor_audit(match_id,account_id,raw_delta,applied_delta,floor_credit) VALUES(?,?,?,?,?)").bind(matchId, p.account_id, legacyDelta, after - r.starting_rp, Math.max(0, after - r.starting_rp - legacyDelta)));
    statements.push(env.ACCOUNTS_DB.prepare("INSERT INTO player_match_results(match_id,account_id,kills,deaths,assists,flags_captured,flags_stopped,score_units,performance,outcome,rp_before,rp_after,committed_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)").bind(matchId, p.account_id, p.kills, p.deaths, p.assists, p.flags_captured, p.flags_stopped, scores[i], ratings[i], outcome, r.starting_rp, after, time));
    if (match.playlist_id === null) statements.push(env.ACCOUNTS_DB.prepare("UPDATE player_stats SET rp=?,matches=matches+1,wins=wins+?,kills=kills+?,deaths=deaths+?,assists=assists+?,flags_captured=flags_captured+?,flags_stopped=flags_stopped+? WHERE account_id=?").bind(after, outcome === 1 ? 1 : 0, p.kills, p.deaths, p.assists, p.flags_captured, p.flags_stopped, p.account_id));
    else statements.push(env.ACCOUNTS_DB.prepare("UPDATE player_playlist_stats SET rp=?,matches=matches+1,wins=wins+?,losses=losses+?,draws=draws+?,kills=kills+?,deaths=deaths+?,assists=assists+?,flags_captured=flags_captured+?,flags_stopped=flags_stopped+? WHERE account_id=? AND playlist_id=?").bind(after, outcome === 1 ? 1 : 0, outcome === 0 ? 1 : 0, outcome === 0.5 ? 1 : 0, p.kills, p.deaths, p.assists, p.flags_captured, p.flags_stopped, p.account_id, match.playlist_id));
  }
  if (roster.length === 2) {
    const previous = await env.ACCOUNTS_DB.prepare(`SELECT COUNT(*) AS total FROM matches m JOIN match_roster a ON a.match_id=m.id AND a.account_id=? JOIN match_roster b ON b.match_id=m.id AND b.account_id=? WHERE m.status='finalized' AND m.playlist_id=? AND m.created_at>=?`).bind(roster[0].account_id, roster[1].account_id, match.playlist_id, stamp() - 3600).first();
    if ((previous?.total || 0) >= 9) statements.push(env.ACCOUNTS_DB.prepare("INSERT INTO match_reviews(match_id,reason,status,evidence,created_at) VALUES(?,'repeated_opponents','flagged',?,?) ON CONFLICT(match_id) DO NOTHING").bind(matchId, JSON.stringify({ prior_hour_matches: previous.total, automatic_penalty: false }), time));
  }
  statements.push(env.ACCOUNTS_DB.prepare("UPDATE matches SET status='finalized',result_hash=?,finalized_at=? WHERE id=?").bind(digest, time, matchId), env.ACCOUNTS_DB.prepare("DELETE FROM active_participants WHERE match_id=?").bind(matchId));
  try {
    await env.ACCOUNTS_DB.batch(statements);
  } catch {
    const conflict = await env.ACCOUNTS_DB.prepare("SELECT result_hash FROM match_results WHERE match_id=?").bind(matchId).first();
    if (conflict?.result_hash === digest) return { committed: true, duplicate: true, match_id: matchId };
    bad("result_commit_conflict", 409);
  }
  return { committed: true, duplicate: false, match_id: matchId };
}
async function publicServiceCard(env, accountId) {
  const target = id(accountId);
  const account = await env.ACCOUNTS_DB.prepare("SELECT username FROM accounts WHERE id=? AND disabled=0").bind(target).first();
  if (!account) bad("unknown_account", 404);
  const value = await profile(env, target);
  return { account_id: target, username: account.username, service_card: value.service_card };
}
async function reviewSummary(req, env) {
  await authorized(req, env);
  const rows = (await env.ACCOUNTS_DB.prepare("SELECT reason,status,COUNT(*) AS total FROM match_reviews GROUP BY reason,status").all()).results;
  const audit = await env.ACCOUNTS_DB.prepare("SELECT COALESCE(SUM(floor_credit),0) AS total FROM rating_floor_audit").first();
  return { reviews: rows, floor_credit_total: audit?.total || 0, policy: "No points from disputed results. Repeated-opponent flags are reviewed without automatic penalties." };
}

// src/worker.ts
var STEAM = "https://steamcommunity.com/openid/login";
var NS = "http://specs.openid.net/auth/2.0";
var SESSION = "__Host-an_session";
var ATTEMPT = "__Host-an_auth";
var encoder = new TextEncoder();
var now = () => Math.floor(Date.now() / 1e3);
var Failure = class extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
  status;
  code;
};
function fail(status, code) {
  throw new Failure(status, code);
}
function json(value, status = 200, headers = {}) {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer", ...headers } });
}
function b64(bytes2) {
  let str = "";
  for (const byte of bytes2) str += String.fromCharCode(byte);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function bytes(value) {
  const input = value.replace(/-/g, "+").replace(/_/g, "/");
  if (input.length > 2e4) fail(400, "invalid_encoding");
  try {
    return Uint8Array.from(atob(input), (ch) => ch.charCodeAt(0));
  } catch {
    fail(400, "invalid_encoding");
  }
}
function random(size = 32) {
  return b64(crypto.getRandomValues(new Uint8Array(size)));
}
async function hash2(value) {
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value)))].map((x) => x.toString(16).padStart(2, "0")).join("");
}
function eq(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
function origin(env) {
  let url;
  try {
    url = new URL(env.SITE_ORIGIN);
  } catch {
    fail(503, "account_origin_not_configured");
  }
  if (url.protocol !== "https:" || url.pathname !== "/" || url.search || url.hash) fail(503, "account_origin_not_configured");
  return url.origin;
}
function cookie(req, name) {
  return (req.headers.get("Cookie") || "").split(";").map((x) => x.trim()).find((x) => x.startsWith(name + "="))?.slice(name.length + 1) || "";
}
function setCookie(name, value, seconds) {
  return `${name}=${value}; Path=/; Max-Age=${seconds}; Secure; HttpOnly; SameSite=Lax`;
}
function redirect(url, cookies = []) {
  const headers = new Headers({ "Location": url, "Cache-Control": "no-store", "Referrer-Policy": "no-referrer" });
  for (const item of cookies) headers.append("Set-Cookie", item);
  return new Response(null, { status: 303, headers });
}
async function body(req) {
  if (!req.headers.get("Content-Type")?.startsWith("application/json")) fail(415, "json_required");
  if (Number(req.headers.get("Content-Length") || 0) > 16384) fail(413, "request_too_large");
  const reader = req.body?.getReader();
  const chunks = [];
  let size = 0;
  if (reader) {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      size += part.value.byteLength;
      if (size > 16384) {
        await reader.cancel();
        fail(413, "request_too_large");
      }
      chunks.push(part.value);
    }
  }
  const combined = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    combined.set(chunk, offset);
    offset += chunk.length;
  }
  const value = new TextDecoder().decode(combined);
  try {
    const parsed = JSON.parse(value);
    if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") throw Error();
    return parsed;
  } catch {
    fail(400, "invalid_json");
  }
}
function field(value, max = 8192) {
  if (typeof value !== "string" || !value || value.length > max) fail(400, "invalid_field");
  return value;
}
async function codeHash(code, env) {
  if (!/^[A-HJ-NP-Z2-9]{8}$/.test(code)) fail(400, "invalid_link_code");
  return hash2(`${env.CODE_PEPPER}|${code}`);
}
async function limit(req, env, name, max, seconds = 60) {
  const stamp2 = now();
  const bucket = await hash2(`${env.CODE_PEPPER}|${req.headers.get("CF-Connecting-IP") || "local"}|${name}|${Math.floor(stamp2 / seconds)}`);
  const row = await env.ACCOUNTS_DB.prepare("INSERT INTO rate_limits(bucket,hits,expires_at) VALUES(?,1,?) ON CONFLICT(bucket) DO UPDATE SET hits=hits+1 RETURNING hits").bind(bucket, stamp2 + seconds * 2).first();
  if (!row || row.hits > max) fail(429, "too_many_requests");
}
function pemBytes(pem) {
  if (pem.length > 8192) fail(400, "invalid_public_key");
  return bytes(pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, ""));
}
function der(tag2, content) {
  const n = content.length;
  const len = n < 128 ? [n] : n < 256 ? [129, n] : [130, n >> 8, n & 255];
  return new Uint8Array([tag2, ...len, ...content]);
}
async function publicKey(pem) {
  let raw = pemBytes(pem);
  if (pem.startsWith("-----BEGIN RSA PUBLIC KEY-----")) {
    const alg = new Uint8Array([48, 13, 6, 9, 42, 134, 72, 134, 247, 13, 1, 1, 1, 5, 0]);
    raw = der(48, new Uint8Array([...alg, ...der(3, new Uint8Array([0, ...raw]))]));
  } else if (!pem.startsWith("-----BEGIN PUBLIC KEY-----")) fail(400, "invalid_public_key");
  try {
    const key = await crypto.subtle.importKey("spki", raw, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
    const size = key.algorithm.modulusLength;
    if (size < 2048 || size > 4096) fail(400, "invalid_public_key");
    return key;
  } catch {
    fail(400, "invalid_public_key");
  }
}
async function prove(pem, signature, message) {
  const key = await publicKey(pem);
  if (!await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, bytes(signature), encoder.encode(message))) fail(401, "game_key_proof_failed");
}
var cachedKeys;
async function signingKeys(env) {
  if (cachedKeys?.source === env.ACCOUNT_SIGNING_KEY) return cachedKeys;
  try {
    const privateKey = await crypto.subtle.importKey("pkcs8", pemBytes(env.ACCOUNT_SIGNING_KEY), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, true, ["sign"]);
    const jwk = await crypto.subtle.exportKey("jwk", privateKey);
    const pub = await crypto.subtle.importKey("jwk", { kty: "RSA", n: jwk.n, e: jwk.e, alg: "RS256", ext: true }, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, true, ["verify"]);
    cachedKeys = { source: env.ACCOUNT_SIGNING_KEY, privateKey, publicKey: pub };
    return cachedKeys;
  } catch {
    fail(503, "account_signing_not_configured");
  }
}
async function assertion(device, account, env) {
  const timestamp = now();
  const header = b64(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT", kid: "accounts-v1" })));
  const payload = b64(encoder.encode(JSON.stringify({ iss: origin(env), aud: "ancient-nest-matchmaking", sub: account.id, username: account.username, device_id: device.id, key_hash: device.key_hash, iat: timestamp, exp: timestamp + 900, jti: random(16) })));
  const data = header + "." + payload;
  return data + "." + b64(new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", (await signingKeys(env)).privateKey, encoder.encode(data))));
}
async function verifyAssertion(token, env) {
  const parts = token.split(".");
  if (parts.length !== 3) fail(401, "invalid_assertion");
  let head, claims;
  try {
    head = JSON.parse(new TextDecoder().decode(bytes(parts[0])));
    claims = JSON.parse(new TextDecoder().decode(bytes(parts[1])));
  } catch {
    fail(401, "invalid_assertion");
  }
  if (head.alg !== "RS256" || head.typ !== "JWT" || head.kid !== "accounts-v1") fail(401, "invalid_assertion");
  if (!await crypto.subtle.verify("RSASSA-PKCS1-v1_5", (await signingKeys(env)).publicKey, bytes(parts[2]), encoder.encode(parts[0] + "." + parts[1]))) fail(401, "invalid_assertion");
  if (claims.iss !== origin(env) || claims.aud !== "ancient-nest-matchmaking" || typeof claims.exp !== "number" || typeof claims.iat !== "number" || claims.exp <= now() || claims.iat > now() + 30 || claims.exp - claims.iat > 900 || typeof claims.sub !== "string" || typeof claims.device_id !== "string" || typeof claims.key_hash !== "string") fail(401, "invalid_assertion");
  const device = await env.ACCOUNTS_DB.prepare("SELECT * FROM game_devices WHERE id=? AND account_id=? AND key_hash=? AND revoked=0 AND expires_at>?").bind(claims.device_id, claims.sub, claims.key_hash, now()).first();
  const account = await env.ACCOUNTS_DB.prepare("SELECT * FROM accounts WHERE id=? AND disabled=0").bind(claims.sub).first();
  if (!device || !account) fail(401, "revoked_account_device");
  return { ...claims, username: account.username };
}
async function webSession(req, env, required = true) {
  const parts = cookie(req, SESSION).split(".");
  if (parts.length !== 2 || !parts.every((x) => /^[A-Za-z0-9_-]{43}$/.test(x))) {
    if (required) fail(401, "sign_in_required");
    return null;
  }
  const row = await env.ACCOUNTS_DB.prepare("SELECT s.*,a.steam_id,a.username,a.disabled FROM web_sessions s JOIN accounts a ON a.id=s.account_id WHERE s.token_hash=? AND s.csrf_hash=? AND s.expires_at>? AND a.disabled=0").bind(await hash2(parts[0]), await hash2(parts[1]), now()).first();
  if (!row) {
    if (required) fail(401, "sign_in_required");
    return null;
  }
  return { ...row, csrf: parts[1] };
}
async function browserSession(req, env) {
  if (req.headers.get("Origin") !== origin(env)) fail(403, "origin_not_allowed");
  const session = await webSession(req, env, true);
  if (!session || !eq(session.csrf, req.headers.get("X-CSRF-Token") || "")) fail(403, "csrf_check_failed");
  return session;
}
async function startSteam(req, env) {
  await limit(req, env, "steam-start", 15);
  const state = random(), browser = random();
  const callback = `${origin(env)}/api/auth/steam/callback?state=${state}`;
  await env.ACCOUNTS_DB.prepare("INSERT INTO auth_attempts(state_hash,browser_hash,return_to,expires_at) VALUES(?,?,?,?)").bind(await hash2(state), await hash2(browser), callback, now() + 600).run();
  const url = new URL(STEAM);
  url.search = new URLSearchParams({ "openid.ns": NS, "openid.mode": "checkid_setup", "openid.return_to": callback, "openid.realm": origin(env) + "/", "openid.identity": `${NS}/identifier_select`, "openid.claimed_id": `${NS}/identifier_select` }).toString();
  return redirect(url.toString(), [setCookie(ATTEMPT, browser, 600)]);
}
async function steamCallback(req, env) {
  await limit(req, env, "steam-callback", 30);
  const u = new URL(req.url);
  for (const name of new Set(u.searchParams.keys())) if (u.searchParams.getAll(name).length !== 1) fail(400, "duplicate_sign_in_field");
  const state = u.searchParams.get("state") || "";
  const browser = cookie(req, ATTEMPT);
  if (!/^[A-Za-z0-9_-]{43}$/.test(state) || !browser) fail(401, "invalid_sign_in_state");
  const attempt = await env.ACCOUNTS_DB.prepare("SELECT * FROM auth_attempts WHERE state_hash=? AND browser_hash=? AND expires_at>? AND consumed=0").bind(await hash2(state), await hash2(browser), now()).first();
  if (!attempt) fail(401, "expired_sign_in");
  if (u.searchParams.get("openid.mode") === "cancel") return redirect(origin(env) + "/account/?error=cancelled", [setCookie(ATTEMPT, "", 0)]);
  const value = (name) => u.searchParams.get("openid." + name) || "";
  const claimed = value("claimed_id");
  const id2 = claimed.match(/^https:\/\/steamcommunity\.com\/openid\/id\/(\d{17})$/)?.[1];
  const nonce = value("response_nonce");
  const signed = new Set(value("signed").split(","));
  for (const name of ["op_endpoint", "claimed_id", "identity", "return_to", "response_nonce", "assoc_handle"]) if (!signed.has(name)) fail(401, "invalid_steam_response");
  if (value("ns") !== NS || value("mode") !== "id_res" || value("op_endpoint") !== STEAM || !id2 || value("identity") !== claimed || value("return_to") !== attempt.return_to || nonce.length > 256) fail(401, "invalid_steam_response");
  const nonceTime = Date.parse(nonce.slice(0, 20));
  if (!Number.isFinite(nonceTime) || Math.abs(now() - nonceTime / 1e3) > 300) fail(401, "expired_steam_response");
  const params = new URLSearchParams();
  for (const [name, item] of u.searchParams) if (name.startsWith("openid.")) {
    if (item.length > 4096) fail(400, "invalid_steam_response");
    params.append(name, item);
  }
  params.set("openid.mode", "check_authentication");
  const response = await fetch(STEAM, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: params.toString(), signal: AbortSignal.timeout(1e4), redirect: "manual" });
  const result = await response.text();
  if (!response.ok || result.length > 4096 || !/^is_valid:true\r?$/m.test(result)) fail(401, "steam_verification_failed");
  try {
    await env.ACCOUNTS_DB.prepare("INSERT INTO provider_nonces(nonce_hash,expires_at) VALUES(?,?)").bind(await hash2(nonce), now() + 600).run();
  } catch {
    fail(401, "steam_response_already_used");
  }
  const consumed = await env.ACCOUNTS_DB.prepare("UPDATE auth_attempts SET consumed=1 WHERE state_hash=? AND consumed=0 RETURNING state_hash").bind(await hash2(state)).first();
  if (!consumed) fail(401, "sign_in_already_used");
  const accountId = crypto.randomUUID();
  const generated = "Player_" + accountId.replace(/-/g, "").slice(0, 12);
  await env.ACCOUNTS_DB.prepare("INSERT INTO accounts(id,steam_id,username,username_key,created_at) VALUES(?,?,?,?,?) ON CONFLICT(steam_id) DO NOTHING").bind(accountId, id2, generated, generated.toLowerCase(), now()).run();
  const account = await env.ACCOUNTS_DB.prepare("SELECT * FROM accounts WHERE steam_id=? AND disabled=0").bind(id2).first();
  if (!account) fail(403, "account_unavailable");
  const token = random(), csrf = random();
  await env.ACCOUNTS_DB.prepare("INSERT INTO web_sessions(token_hash,account_id,csrf_hash,expires_at,created_at) VALUES(?,?,?,?,?)").bind(await hash2(token), account.id, await hash2(csrf), now() + 604800, now()).run();
  return redirect(origin(env) + "/account/", [setCookie(SESSION, token + "." + csrf, 604800), setCookie(ATTEMPT, "", 0)]);
}
async function route(req, env) {
  const path = new URL(req.url).pathname.replace(/\/$/, "");
  const method = req.method;
  if (!path.startsWith("/api/")) return env.ASSETS ? env.ASSETS.fetch(req) : new Response("Website assets not configured", { status: 503 });
  if (!env.ACCOUNTS_DB || !env.CODE_PEPPER || env.CODE_PEPPER.length < 32 || !env.ACCOUNT_SIGNING_KEY) return json({ error: "account_service_not_configured", configured: false }, 503);
  origin(env);
  if (path === "/api/internal/reviews" && method === "POST") {
    await limit(req, env, "review-summary", 60);
    return json(await reviewSummary(req, env));
  }
  if (path === "/api/internal/players/ratings" && method === "POST") {
    await limit(req, env, "coordinator-ratings", 120);
    return json(await internalRatings(req, env, await body(req)));
  }
  if (path.startsWith("/api/internal/matches/") && method === "POST") {
    await limit(req, env, "coordinator", 120);
    return json(await coordinator(req, env, await body(req)));
  }
  if (path === "/api/profile" && method === "GET") {
    const session = await webSession(req, env, true);
    return json(await profile(env, session.account_id, new URL(req.url).searchParams.get("playlist") || "duel_1v1"));
  }
  if (path === "/api/account/ownership" && method === "POST") {
    await limit(req, env, "ownership", 10);
    const session = await browserSession(req, env);
    return json(await ownership(env, session.steam_id));
  }
  if (path === "/api/auth/steam" && method === "GET") return startSteam(req, env);
  if (path === "/api/auth/steam/callback" && method === "GET") return steamCallback(req, env);
  if (path === "/api/account" && method === "GET") {
    const session = await webSession(req, env, false);
    if (!session) return json({ configured: true, authenticated: false });
    const devices = await env.ACCOUNTS_DB.prepare("SELECT id,key_hash,created_at,expires_at FROM game_devices WHERE account_id=? AND revoked=0").bind(session.account_id).all();
    return json({ configured: true, authenticated: true, csrf: session.csrf, account: { id: session.account_id, username: session.username, steamId: session.steam_id }, devices: devices.results, statistics: "matchmaking", ownership: { status: env.STEAM_APP_ID && env.STEAM_PUBLISHER_KEY ? "check_available" : "not_configured", provider: "steam", required: env.REQUIRE_OWNERSHIP === "true" } });
  }
  if (path === "/api/account/username" && method === "POST") {
    await limit(req, env, "username", 15);
    const session = await browserSession(req, env);
    const data = await body(req);
    const username = field(data.username, 20).trim();
    if (!/^[A-Za-z0-9_]{3,20}$/.test(username)) fail(400, "username_use_3_to_20_letters_numbers_underscores");
    try {
      await env.ACCOUNTS_DB.prepare("UPDATE accounts SET username=?,username_key=? WHERE id=?").bind(username, username.toLowerCase(), session.account_id).run();
    } catch {
      fail(409, "username_already_taken");
    }
    return json({ username });
  }
  if (path === "/api/account/logout" && method === "POST") {
    const session = await browserSession(req, env);
    await env.ACCOUNTS_DB.prepare("DELETE FROM web_sessions WHERE token_hash=?").bind(session.token_hash).run();
    return json({ ok: true }, 200, { "Set-Cookie": setCookie(SESSION, "", 0) });
  }
  if (path === "/api/account/delete" && method === "POST") {
    const session = await browserSession(req, env);
    const data = await body(req);
    if (now() - session.created_at > 600) fail(403, "sign_in_again_before_deleting_account");
    if (data.confirm !== session.username) fail(400, "type_username_to_confirm");
    await env.ACCOUNTS_DB.batch([env.ACCOUNTS_DB.prepare("DELETE FROM game_links WHERE approved_by=?").bind(session.account_id), env.ACCOUNTS_DB.prepare("DELETE FROM accounts WHERE id=?").bind(session.account_id)]);
    return json({ ok: true }, 200, { "Set-Cookie": setCookie(SESSION, "", 0) });
  }
  if (path === "/api/account/device/revoke" && method === "POST") {
    const session = await browserSession(req, env);
    const data = await body(req);
    await env.ACCOUNTS_DB.prepare("DELETE FROM game_devices WHERE id=? AND account_id=?").bind(field(data.device_id, 64), session.account_id).run();
    return json({ ok: true });
  }
  if (path === "/api/game/link/start" && method === "POST") {
    await limit(req, env, "link-start", 8);
    const data = await body(req);
    const pem = field(data.public_key);
    await publicKey(pem);
    const deviceSecret = random();
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const picks = crypto.getRandomValues(new Uint8Array(8));
    const code = [...picks].map((n) => alphabet[n % alphabet.length]).join("");
    const id2 = crypto.randomUUID(), challenge = random();
    const keyHash = await hash2(pem);
    await env.ACCOUNTS_DB.prepare("INSERT INTO game_links(id,public_key,key_hash,secret_hash,code_hash,challenge,expires_at,created_at) VALUES(?,?,?,?,?,?,?,?)").bind(id2, pem, keyHash, await hash2(deviceSecret), await codeHash(code, env), challenge, now() + 600, now()).run();
    return json({ device_secret: deviceSecret, user_code: code, challenge, verification_uri: origin(env) + "/account/", expires_in: 600, interval: 3, key_fingerprint: keyHash.slice(0, 12) });
  }
  if (path === "/api/game/link/info" && method === "GET") {
    await limit(req, env, "link-info", 30);
    await webSession(req, env, true);
    const code = (new URL(req.url).searchParams.get("code") || "").replace(/[- ]/g, "").toUpperCase();
    const link = await env.ACCOUNTS_DB.prepare("SELECT key_hash FROM game_links WHERE code_hash=? AND expires_at>? AND consumed=0").bind(await codeHash(code, env), now()).first();
    if (!link) fail(404, "link_code_expired_or_unknown");
    return json({ code, fingerprint: link.key_hash.slice(0, 12) });
  }
  if (path === "/api/game/link/approve" && method === "POST") {
    await limit(req, env, "link-approve", 15);
    const session = await browserSession(req, env);
    const data = await body(req);
    const code = field(data.code, 16).replace(/[- ]/g, "").toUpperCase();
    const link = await env.ACCOUNTS_DB.prepare("SELECT * FROM game_links WHERE code_hash=? AND expires_at>? AND consumed=0").bind(await codeHash(code, env), now()).first();
    if (!link) fail(404, "link_code_expired_or_unknown");
    if (data.fingerprint !== link.key_hash.slice(0, 12)) fail(400, "confirm_game_fingerprint");
    const existing = await env.ACCOUNTS_DB.prepare("SELECT account_id FROM game_devices WHERE key_hash=?").bind(link.key_hash).first();
    if (existing && existing.account_id !== session.account_id) fail(409, "game_key_already_linked");
    if (link.approved_by && link.approved_by !== session.account_id) fail(409, "link_already_approved");
    const updated = await env.ACCOUNTS_DB.prepare("UPDATE game_links SET approved_by=? WHERE id=? AND consumed=0 AND (approved_by IS NULL OR approved_by=?) RETURNING id").bind(session.account_id, link.id, session.account_id).first();
    if (!updated) fail(409, "link_already_approved");
    return json({ approved: true });
  }
  if (path === "/api/game/link/poll" && method === "POST") {
    await limit(req, env, "link-poll", 120);
    const data = await body(req);
    const secret = field(data.device_secret, 128);
    const link = await env.ACCOUNTS_DB.prepare("SELECT * FROM game_links WHERE secret_hash=? AND expires_at>? AND consumed=0").bind(await hash2(secret), now()).first();
    if (!link) fail(410, "link_expired_or_consumed");
    await prove(link.public_key, field(data.signature, 2048), link.challenge);
    if (!link.approved_by) return json({ status: "pending" });
    const account = await env.ACCOUNTS_DB.prepare("SELECT * FROM accounts WHERE id=? AND disabled=0").bind(link.approved_by).first();
    if (!account) fail(401, "account_unavailable");
    const refresh = random(), deviceId = crypto.randomUUID();
    const refreshed = await hash2(refresh);
    const results = await env.ACCOUNTS_DB.batch([env.ACCOUNTS_DB.prepare("INSERT INTO game_devices(id,account_id,public_key,key_hash,refresh_hash,created_at,expires_at) SELECT ?,approved_by,public_key,key_hash,?,?,? FROM game_links WHERE id=? AND consumed=0 AND expires_at>? ON CONFLICT(key_hash) DO UPDATE SET id=excluded.id,refresh_hash=excluded.refresh_hash,created_at=excluded.created_at,expires_at=excluded.expires_at,revoked=0 WHERE game_devices.account_id=excluded.account_id").bind(deviceId, refreshed, now(), now() + 2592e3, link.id, now()), env.ACCOUNTS_DB.prepare("UPDATE game_links SET consumed=1 WHERE id=? AND consumed=0").bind(link.id)]);
    if (!results[0].meta.changes || !results[1].meta.changes) fail(409, "link_claim_failed");
    const device = await env.ACCOUNTS_DB.prepare("SELECT * FROM game_devices WHERE id=? AND refresh_hash=?").bind(deviceId, refreshed).first();
    if (!device) fail(409, "link_claim_failed");
    return json({ status: "linked", account_id: account.id, username: account.username, device_id: device.id, refresh_token: refresh, assertion: await assertion(device, account, env), expires_in: 900 });
  }
  if (path === "/api/game/session" && method === "POST") {
    await limit(req, env, "game-refresh", 60);
    const data = await body(req);
    const refresh = field(data.refresh_token, 128), nonce = field(data.nonce, 128);
    const issued = data.issued_at;
    if (typeof issued !== "number" || !Number.isInteger(issued) || Math.abs(now() - issued) > 120 || !/^[A-Za-z0-9_-]{32,128}$/.test(nonce)) fail(401, "stale_game_proof");
    const device = await env.ACCOUNTS_DB.prepare("SELECT * FROM game_devices WHERE refresh_hash=? AND expires_at>? AND revoked=0").bind(await hash2(refresh), now()).first();
    if (!device) fail(401, "game_link_expired_or_revoked");
    await prove(device.public_key, field(data.signature, 2048), `ancient-nest-session-v1
${refresh}
${issued}
${nonce}`);
    try {
      await env.ACCOUNTS_DB.prepare("INSERT INTO request_nonces(nonce_key,expires_at) VALUES(?,?)").bind(await hash2(device.id + "|" + nonce), now() + 300).run();
    } catch {
      fail(401, "game_proof_already_used");
    }
    const account = await env.ACCOUNTS_DB.prepare("SELECT * FROM accounts WHERE id=? AND disabled=0").bind(device.account_id).first();
    if (!account) fail(401, "account_unavailable");
    return json({ account_id: account.id, username: account.username, device_id: device.id, assertion: await assertion(device, account, env), expires_in: 900 });
  }
  if (path === "/api/game/service-card" && method === "POST") {
    await limit(req, env, "service-card", 60);
    const data = await body(req);
    const claims = await verifyAssertion(field(data.assertion, 8192), env);
    if (data.key_hash !== claims.key_hash) fail(401, "game_key_does_not_match_account");
    return json(await publicServiceCard(env, data.account_id || claims.sub));
  }
  if (path === "/api/game/profile" && method === "POST") {
    await limit(req, env, "game-profile", 60);
    const data = await body(req);
    const claims = await verifyAssertion(field(data.assertion, 8192), env);
    if (data.key_hash !== claims.key_hash) fail(401, "game_key_does_not_match_account");
    return json(await profile(env, String(claims.sub), data.playlist || "duel_1v1"));
  }
  if (path === "/api/game/verify" && method === "POST") {
    await limit(req, env, "game-verify", 300);
    const data = await body(req);
    const claims = await verifyAssertion(field(data.assertion, 8192), env);
    if (data.key_hash !== claims.key_hash) fail(401, "game_key_does_not_match_account");
    const license = await ownership(env, (await env.ACCOUNTS_DB.prepare("SELECT steam_id FROM accounts WHERE id=?").bind(claims.sub).first()).steam_id);
    if (env.REQUIRE_OWNERSHIP === "true" && !license.has_access) fail(403, "game_license_required");
    return json({ ownership_required: env.REQUIRE_OWNERSHIP === "true", ownership: license, valid: true, account_id: claims.sub, username: claims.username, device_id: claims.device_id, key_hash: claims.key_hash, expires_at: claims.exp });
  }
  if (path === "/api/account/public-key" && method === "GET") {
    const raw = new Uint8Array(await crypto.subtle.exportKey("spki", (await signingKeys(env)).publicKey));
    const encoded = b64(raw).replace(/-/g, "+").replace(/_/g, "/");
    const padded = encoded + "=".repeat((4 - encoded.length % 4) % 4);
    return json({ issuer: origin(env), public_key: "-----BEGIN PUBLIC KEY-----\n" + padded.match(/.{1,64}/g).join("\n") + "\n-----END PUBLIC KEY-----\n", algorithm: "RS256", audience: "ancient-nest-matchmaking" });
  }
  return json({ error: "not_found" }, 404);
}
var worker_default = {
  async fetch(req, env) {
    try {
      return await route(req, env);
    } catch (error) {
      if (error instanceof Failure || error instanceof ServiceError) return json({ error: error.code }, error.status);
      console.error("Account operation failed", error instanceof Error ? error.name : "Error");
      return json({ error: "account_operation_failed" }, 500);
    }
  },
  async scheduled(_event, env, ctx) {
    if (!env.ACCOUNTS_DB) return;
    ctx.waitUntil(env.ACCOUNTS_DB.batch(["UPDATE matches SET status='void' WHERE status='active' AND expires_at<?", "DELETE FROM active_participants WHERE match_id IN(SELECT id FROM matches WHERE status='void' AND expires_at<?)", "DELETE FROM auth_attempts WHERE expires_at<?", "DELETE FROM provider_nonces WHERE expires_at<?", "DELETE FROM web_sessions WHERE expires_at<?", "DELETE FROM game_links WHERE expires_at<?", "DELETE FROM request_nonces WHERE expires_at<?", "DELETE FROM rate_limits WHERE expires_at<?"].map((sql) => env.ACCOUNTS_DB.prepare(sql).bind(now()))));
  }
};
export {
  worker_default as default
};
