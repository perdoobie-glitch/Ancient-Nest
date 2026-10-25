import { elo, performance, rank, ratingGrade, serviceCard } from "./ranking.js";
class ServiceError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
  status;
  code;
}
const bad = (code, status = 400) => {
  throw new ServiceError(status, code);
};
const stamp = () => Math.floor(Date.now() / 1e3);
const hash = async (s) => [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)))].map((v) => v.toString(16).padStart(2, "0")).join("");
const id = (v) => {
  if (typeof v !== "string" || !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(v)) return bad("invalid_uuid");
  return v;
};
const tag = (v) => {
  if (typeof v !== "string" || !/^[A-Za-z0-9_.:-]{1,100}$/.test(v)) return bad("invalid_identifier");
  return v;
};
const count = (v) => {
  if (typeof v !== "number" || !Number.isInteger(v) || v < 0 || v > 1e4) return bad("invalid_counter");
  return v;
};
const avg = (a) => a.reduce((s, n) => s + n, 0) / a.length;
const PLAYLISTS = { duel_1v1: { name: "1 v 1 Loners", size: 2 }, doubles_2v2: { name: "2 v 2 Couples", size: 4 }, tactical_3v3: { name: "3 v 3 Trios", size: 6 }, arena_4v4: { name: "4 v 4 Quads", size: 8 }, bomb_defuse_5v5: { name: "5 v 5 Squads", size: 10 } };
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
    const account = await env.ACCOUNTS_DB.prepare("SELECT id FROM users WHERE id=? AND banned=0").bind(accountId).first();
    if (!account) bad("unknown_account", 404);
    const rows = (await env.ACCOUNTS_DB.prepare("SELECT playlist_id,rp FROM player_playlist_stats WHERE account_id=?").bind(accountId).all()).results;
    ratings[accountId] = Object.fromEntries(Object.keys(PLAYLISTS).map((key) => [key, rows.find((r) => r.playlist_id === key)?.rp ?? 1]));
  }
  return { ratings };
}
async function authorized(req, env) {
  if (!env.COORDINATOR_API_KEY || env.COORDINATOR_API_KEY.length < 32) bad("coordinator_not_configured", 503);
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
      const account = await env.ACCOUNTS_DB.prepare("SELECT id FROM users WHERE id=? AND banned=0").bind(player.account_id).first();
      if (!account) bad("unknown_account", 404);
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
  const account = await env.ACCOUNTS_DB.prepare("SELECT username FROM users WHERE id=? AND banned=0").bind(target).first();
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
export {
  PLAYLISTS,
  ServiceError,
  coordinator,
  internalRatings,
  playlist,
  profile,
  publicServiceCard,
  reviewSummary
};
