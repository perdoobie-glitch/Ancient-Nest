// src/ranking.js
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

// src/stats.js
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
var PLAYLISTS = { duel_1v1: { name: "1 v 1 Loners", size: 2 }, doubles_2v2: { name: "2 v 2 Couples", size: 4 }, tactical_3v3: { name: "3 v 3 Trios", size: 6 }, arena_4v4: { name: "4 v 4 Quads", size: 8 }, bomb_defuse_5v5: { name: "5 v 5 Squads", size: 10 } };
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

// src/discord-sign-in.js
function discordSignIn({
  HttpError: HttpError2,
  json: json2,
  body: body2,
  authenticate: authenticate2,
  bearer: bearer2,
  rateLimit: rateLimit2,
  discord: discord2,
  newSession: newSession2,
  sessionInsert: sessionInsert2,
  sessionResponse: sessionResponse2
}) {
  return async (request2, env, db, key, ttl) => {
    const path = new URL(request2.url).pathname;
    if (path === "/auth/discord/config") {
      if (request2.method !== "GET") throw new HttpError2(405, "method_not_allowed");
      discord2.configured(env);
      return json2({ auth_provider: "discord", application_id: env.DISCORD_CLIENT_ID });
    }
    if (request2.method !== "POST") throw new HttpError2(405, "method_not_allowed");
    if (path === "/profile/username") {
      const auth = await authenticate2(bearer2(request2), db, key);
      await rateLimit2(db, key, "profile-name", auth.user.id, 5);
      const { username } = await body2(request2);
      if (typeof username !== "string" || !/^[a-zA-Z0-9_-]{3,24}$/.test(username)) {
        throw new HttpError2(400, "invalid_game_username");
      }
      try {
        const saved2 = await db.prepare("UPDATE users SET username = ? WHERE id = ? AND banned = 0 RETURNING id, username, created_at").bind(username, auth.user.id).first();
        if (!saved2) throw new HttpError2(401, "invalid_token");
        return json2({ user: saved2 });
      } catch (error) {
        if (/UNIQUE constraint failed/.test(String(error))) throw new HttpError2(409, "username_taken");
        throw error;
      }
    }
    discord2.configured(env);
    await rateLimit2(db, key, "discord-sign-in-ip", request2.headers.get("CF-Connecting-IP") ?? "local", 30);
    const value = await body2(request2);
    if (typeof value.code !== "string" || !value.code.length || value.code.length > 2048 || typeof value.code_verifier !== "string" || !/^[A-Za-z0-9._~-]{43,128}$/.test(value.code_verifier) || !discord2.desktopRedirect(value.redirect_uri)) throw new HttpError2(400, "invalid_discord_authorization");
    const { tokens, discordId, discordUser } = await discord2.oauth(env, {
      grant_type: "authorization_code",
      code: value.code,
      code_verifier: value.code_verifier,
      redirect_uri: value.redirect_uri
    });
    let user = await db.prepare("SELECT * FROM users WHERE discord_id = ?").bind(discordId).first();
    if (!user) {
      const id2 = crypto.randomUUID();
      const stem = String(discordUser.username ?? "Player").replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 3) || "P";
      let username = stem + "_" + discordId;
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          await db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email, discord_id,
            discord_username, auth_provider, created_at) VALUES (?, ?, 'DISCORD_ONLY', '', ?, ?, ?, 'discord', ?)`).bind(
            id2,
            username,
            id2 + "@discord.identity.invalid",
            discordId,
            String(discordUser.username ?? discordId).slice(0, 80),
            Math.floor(Date.now() / 1e3)
          ).run();
        } catch (error) {
          if (!/UNIQUE constraint failed/.test(String(error))) throw error;
        }
        user = await db.prepare("SELECT * FROM users WHERE discord_id = ?").bind(discordId).first();
        if (user) break;
        username = "Player_" + crypto.randomUUID().replaceAll("-", "").slice(0, 16);
      }
      if (!user) throw new HttpError2(409, "username_conflict");
    }
    if (user.banned) throw new HttpError2(403, "account_banned");
    const saved = await db.prepare(`UPDATE users SET auth_provider = 'discord', discord_username = ?, last_login = ?
      WHERE id = ? AND banned = 0 AND auth_version = ? RETURNING *`).bind(String(discordUser.username ?? discordId).slice(0, 80), Math.floor(Date.now() / 1e3), user.id, user.auth_version).first();
    if (!saved) throw new HttpError2(401, "invalid_token");
    const session = await newSession2(saved, key, ttl);
    const issued = await sessionInsert2(db, saved, session).run();
    if (issued.meta.changes !== 1) throw new HttpError2(401, "invalid_token");
    return json2({ ...sessionResponse2(saved, session), auth_provider: "discord", discord: {
      discord_id: discordId,
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_in: tokens.expires_in,
      token_type: "Bearer"
    } });
  };
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/buffer_utils.js
var encoder = new TextEncoder();
var decoder = new TextDecoder();
var MAX_INT32 = 2 ** 32;
function concat(...buffers) {
  const size = buffers.reduce((acc, { length }) => acc + length, 0);
  const buf = new Uint8Array(size);
  let i = 0;
  for (const buffer of buffers) {
    buf.set(buffer, i);
    i += buffer.length;
  }
  return buf;
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/base64.js
function encodeBase64(input) {
  if (Uint8Array.prototype.toBase64) {
    return input.toBase64();
  }
  const CHUNK_SIZE = 32768;
  const arr = [];
  for (let i = 0; i < input.length; i += CHUNK_SIZE) {
    arr.push(String.fromCharCode.apply(null, input.subarray(i, i + CHUNK_SIZE)));
  }
  return btoa(arr.join(""));
}
function decodeBase64(encoded) {
  if (Uint8Array.fromBase64) {
    return Uint8Array.fromBase64(encoded);
  }
  const binary = atob(encoded);
  const bytes2 = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes2[i] = binary.charCodeAt(i);
  }
  return bytes2;
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/util/base64url.js
function decode(input) {
  if (Uint8Array.fromBase64) {
    return Uint8Array.fromBase64(typeof input === "string" ? input : decoder.decode(input), {
      alphabet: "base64url"
    });
  }
  let encoded = input;
  if (encoded instanceof Uint8Array) {
    encoded = decoder.decode(encoded);
  }
  encoded = encoded.replace(/-/g, "+").replace(/_/g, "/").replace(/\s/g, "");
  try {
    return decodeBase64(encoded);
  } catch {
    throw new TypeError("The input to be decoded is not correctly encoded.");
  }
}
function encode(input) {
  let unencoded = input;
  if (typeof unencoded === "string") {
    unencoded = encoder.encode(unencoded);
  }
  if (Uint8Array.prototype.toBase64) {
    return unencoded.toBase64({ alphabet: "base64url", omitPadding: true });
  }
  return encodeBase64(unencoded).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/util/errors.js
var JOSEError = class extends Error {
  static code = "ERR_JOSE_GENERIC";
  code = "ERR_JOSE_GENERIC";
  constructor(message2, options) {
    super(message2, options);
    this.name = this.constructor.name;
    Error.captureStackTrace?.(this, this.constructor);
  }
};
var JWTClaimValidationFailed = class extends JOSEError {
  static code = "ERR_JWT_CLAIM_VALIDATION_FAILED";
  code = "ERR_JWT_CLAIM_VALIDATION_FAILED";
  claim;
  reason;
  payload;
  constructor(message2, payload, claim = "unspecified", reason = "unspecified") {
    super(message2, { cause: { claim, reason, payload } });
    this.claim = claim;
    this.reason = reason;
    this.payload = payload;
  }
};
var JWTExpired = class extends JOSEError {
  static code = "ERR_JWT_EXPIRED";
  code = "ERR_JWT_EXPIRED";
  claim;
  reason;
  payload;
  constructor(message2, payload, claim = "unspecified", reason = "unspecified") {
    super(message2, { cause: { claim, reason, payload } });
    this.claim = claim;
    this.reason = reason;
    this.payload = payload;
  }
};
var JOSEAlgNotAllowed = class extends JOSEError {
  static code = "ERR_JOSE_ALG_NOT_ALLOWED";
  code = "ERR_JOSE_ALG_NOT_ALLOWED";
};
var JOSENotSupported = class extends JOSEError {
  static code = "ERR_JOSE_NOT_SUPPORTED";
  code = "ERR_JOSE_NOT_SUPPORTED";
};
var JWSInvalid = class extends JOSEError {
  static code = "ERR_JWS_INVALID";
  code = "ERR_JWS_INVALID";
};
var JWTInvalid = class extends JOSEError {
  static code = "ERR_JWT_INVALID";
  code = "ERR_JWT_INVALID";
};
var JWSSignatureVerificationFailed = class extends JOSEError {
  static code = "ERR_JWS_SIGNATURE_VERIFICATION_FAILED";
  code = "ERR_JWS_SIGNATURE_VERIFICATION_FAILED";
  constructor(message2 = "signature verification failed", options) {
    super(message2, options);
  }
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/crypto_key.js
function unusable(name, prop = "algorithm.name") {
  return new TypeError(`CryptoKey does not support this operation, its ${prop} must be ${name}`);
}
function isAlgorithm(algorithm, name) {
  return algorithm.name === name;
}
function getHashLength(hash2) {
  return parseInt(hash2.name.slice(4), 10);
}
function getNamedCurve(alg) {
  switch (alg) {
    case "ES256":
      return "P-256";
    case "ES384":
      return "P-384";
    case "ES512":
      return "P-521";
    default:
      throw new Error("unreachable");
  }
}
function checkUsage(key, usage) {
  if (usage && !key.usages.includes(usage)) {
    throw new TypeError(`CryptoKey does not support this operation, its usages must include ${usage}.`);
  }
}
function checkSigCryptoKey(key, alg, usage) {
  switch (alg) {
    case "HS256":
    case "HS384":
    case "HS512": {
      if (!isAlgorithm(key.algorithm, "HMAC"))
        throw unusable("HMAC");
      const expected = parseInt(alg.slice(2), 10);
      const actual = getHashLength(key.algorithm.hash);
      if (actual !== expected)
        throw unusable(`SHA-${expected}`, "algorithm.hash");
      break;
    }
    case "RS256":
    case "RS384":
    case "RS512": {
      if (!isAlgorithm(key.algorithm, "RSASSA-PKCS1-v1_5"))
        throw unusable("RSASSA-PKCS1-v1_5");
      const expected = parseInt(alg.slice(2), 10);
      const actual = getHashLength(key.algorithm.hash);
      if (actual !== expected)
        throw unusable(`SHA-${expected}`, "algorithm.hash");
      break;
    }
    case "PS256":
    case "PS384":
    case "PS512": {
      if (!isAlgorithm(key.algorithm, "RSA-PSS"))
        throw unusable("RSA-PSS");
      const expected = parseInt(alg.slice(2), 10);
      const actual = getHashLength(key.algorithm.hash);
      if (actual !== expected)
        throw unusable(`SHA-${expected}`, "algorithm.hash");
      break;
    }
    case "Ed25519":
    case "EdDSA": {
      if (!isAlgorithm(key.algorithm, "Ed25519"))
        throw unusable("Ed25519");
      break;
    }
    case "ML-DSA-44":
    case "ML-DSA-65":
    case "ML-DSA-87": {
      if (!isAlgorithm(key.algorithm, alg))
        throw unusable(alg);
      break;
    }
    case "ES256":
    case "ES384":
    case "ES512": {
      if (!isAlgorithm(key.algorithm, "ECDSA"))
        throw unusable("ECDSA");
      const expected = getNamedCurve(alg);
      const actual = key.algorithm.namedCurve;
      if (actual !== expected)
        throw unusable(expected, "algorithm.namedCurve");
      break;
    }
    default:
      throw new TypeError("CryptoKey does not support this operation");
  }
  checkUsage(key, usage);
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/invalid_key_input.js
function message(msg, actual, ...types) {
  types = types.filter(Boolean);
  if (types.length > 2) {
    const last = types.pop();
    msg += `one of type ${types.join(", ")}, or ${last}.`;
  } else if (types.length === 2) {
    msg += `one of type ${types[0]} or ${types[1]}.`;
  } else {
    msg += `of type ${types[0]}.`;
  }
  if (actual == null) {
    msg += ` Received ${actual}`;
  } else if (typeof actual === "function" && actual.name) {
    msg += ` Received function ${actual.name}`;
  } else if (typeof actual === "object" && actual != null) {
    if (actual.constructor?.name) {
      msg += ` Received an instance of ${actual.constructor.name}`;
    }
  }
  return msg;
}
var invalid_key_input_default = (actual, ...types) => {
  return message("Key must be ", actual, ...types);
};
function withAlg(alg, actual, ...types) {
  return message(`Key for the ${alg} algorithm must be `, actual, ...types);
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/is_key_like.js
function isCryptoKey(key) {
  return key?.[Symbol.toStringTag] === "CryptoKey";
}
function isKeyObject(key) {
  return key?.[Symbol.toStringTag] === "KeyObject";
}
var is_key_like_default = (key) => {
  return isCryptoKey(key) || isKeyObject(key);
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/is_disjoint.js
var is_disjoint_default = (...headers) => {
  const sources = headers.filter(Boolean);
  if (sources.length === 0 || sources.length === 1) {
    return true;
  }
  let acc;
  for (const header of sources) {
    const parameters = Object.keys(header);
    if (!acc || acc.size === 0) {
      acc = new Set(parameters);
      continue;
    }
    for (const parameter of parameters) {
      if (acc.has(parameter)) {
        return false;
      }
      acc.add(parameter);
    }
  }
  return true;
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/is_object.js
function isObjectLike(value) {
  return typeof value === "object" && value !== null;
}
var is_object_default = (input) => {
  if (!isObjectLike(input) || Object.prototype.toString.call(input) !== "[object Object]") {
    return false;
  }
  if (Object.getPrototypeOf(input) === null) {
    return true;
  }
  let proto = input;
  while (Object.getPrototypeOf(proto) !== null) {
    proto = Object.getPrototypeOf(proto);
  }
  return Object.getPrototypeOf(input) === proto;
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/check_key_length.js
var check_key_length_default = (alg, key) => {
  if (alg.startsWith("RS") || alg.startsWith("PS")) {
    const { modulusLength } = key.algorithm;
    if (typeof modulusLength !== "number" || modulusLength < 2048) {
      throw new TypeError(`${alg} requires key modulusLength to be 2048 bits or larger`);
    }
  }
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/jwk_to_key.js
function subtleMapping(jwk) {
  let algorithm;
  let keyUsages;
  switch (jwk.kty) {
    case "AKP": {
      switch (jwk.alg) {
        case "ML-DSA-44":
        case "ML-DSA-65":
        case "ML-DSA-87":
          algorithm = { name: jwk.alg };
          keyUsages = jwk.priv ? ["sign"] : ["verify"];
          break;
        default:
          throw new JOSENotSupported('Invalid or unsupported JWK "alg" (Algorithm) Parameter value');
      }
      break;
    }
    case "RSA": {
      switch (jwk.alg) {
        case "PS256":
        case "PS384":
        case "PS512":
          algorithm = { name: "RSA-PSS", hash: `SHA-${jwk.alg.slice(-3)}` };
          keyUsages = jwk.d ? ["sign"] : ["verify"];
          break;
        case "RS256":
        case "RS384":
        case "RS512":
          algorithm = { name: "RSASSA-PKCS1-v1_5", hash: `SHA-${jwk.alg.slice(-3)}` };
          keyUsages = jwk.d ? ["sign"] : ["verify"];
          break;
        case "RSA-OAEP":
        case "RSA-OAEP-256":
        case "RSA-OAEP-384":
        case "RSA-OAEP-512":
          algorithm = {
            name: "RSA-OAEP",
            hash: `SHA-${parseInt(jwk.alg.slice(-3), 10) || 1}`
          };
          keyUsages = jwk.d ? ["decrypt", "unwrapKey"] : ["encrypt", "wrapKey"];
          break;
        default:
          throw new JOSENotSupported('Invalid or unsupported JWK "alg" (Algorithm) Parameter value');
      }
      break;
    }
    case "EC": {
      switch (jwk.alg) {
        case "ES256":
          algorithm = { name: "ECDSA", namedCurve: "P-256" };
          keyUsages = jwk.d ? ["sign"] : ["verify"];
          break;
        case "ES384":
          algorithm = { name: "ECDSA", namedCurve: "P-384" };
          keyUsages = jwk.d ? ["sign"] : ["verify"];
          break;
        case "ES512":
          algorithm = { name: "ECDSA", namedCurve: "P-521" };
          keyUsages = jwk.d ? ["sign"] : ["verify"];
          break;
        case "ECDH-ES":
        case "ECDH-ES+A128KW":
        case "ECDH-ES+A192KW":
        case "ECDH-ES+A256KW":
          algorithm = { name: "ECDH", namedCurve: jwk.crv };
          keyUsages = jwk.d ? ["deriveBits"] : [];
          break;
        default:
          throw new JOSENotSupported('Invalid or unsupported JWK "alg" (Algorithm) Parameter value');
      }
      break;
    }
    case "OKP": {
      switch (jwk.alg) {
        case "Ed25519":
        case "EdDSA":
          algorithm = { name: "Ed25519" };
          keyUsages = jwk.d ? ["sign"] : ["verify"];
          break;
        case "ECDH-ES":
        case "ECDH-ES+A128KW":
        case "ECDH-ES+A192KW":
        case "ECDH-ES+A256KW":
          algorithm = { name: jwk.crv };
          keyUsages = jwk.d ? ["deriveBits"] : [];
          break;
        default:
          throw new JOSENotSupported('Invalid or unsupported JWK "alg" (Algorithm) Parameter value');
      }
      break;
    }
    default:
      throw new JOSENotSupported('Invalid or unsupported JWK "kty" (Key Type) Parameter value');
  }
  return { algorithm, keyUsages };
}
var jwk_to_key_default = async (jwk) => {
  if (!jwk.alg) {
    throw new TypeError('"alg" argument is required when "jwk.alg" is not present');
  }
  const { algorithm, keyUsages } = subtleMapping(jwk);
  const keyData = { ...jwk };
  if (keyData.kty !== "AKP") {
    delete keyData.alg;
  }
  delete keyData.use;
  return crypto.subtle.importKey("jwk", keyData, algorithm, jwk.ext ?? (jwk.d || jwk.priv ? false : true), jwk.key_ops ?? keyUsages);
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/validate_crit.js
var validate_crit_default = (Err, recognizedDefault, recognizedOption, protectedHeader, joseHeader) => {
  if (joseHeader.crit !== void 0 && protectedHeader?.crit === void 0) {
    throw new Err('"crit" (Critical) Header Parameter MUST be integrity protected');
  }
  if (!protectedHeader || protectedHeader.crit === void 0) {
    return /* @__PURE__ */ new Set();
  }
  if (!Array.isArray(protectedHeader.crit) || protectedHeader.crit.length === 0 || protectedHeader.crit.some((input) => typeof input !== "string" || input.length === 0)) {
    throw new Err('"crit" (Critical) Header Parameter MUST be an array of non-empty strings when present');
  }
  let recognized;
  if (recognizedOption !== void 0) {
    recognized = new Map([...Object.entries(recognizedOption), ...recognizedDefault.entries()]);
  } else {
    recognized = recognizedDefault;
  }
  for (const parameter of protectedHeader.crit) {
    if (!recognized.has(parameter)) {
      throw new JOSENotSupported(`Extension Header Parameter "${parameter}" is not recognized`);
    }
    if (joseHeader[parameter] === void 0) {
      throw new Err(`Extension Header Parameter "${parameter}" is missing`);
    }
    if (recognized.get(parameter) && protectedHeader[parameter] === void 0) {
      throw new Err(`Extension Header Parameter "${parameter}" MUST be integrity protected`);
    }
  }
  return new Set(protectedHeader.crit);
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/validate_algorithms.js
var validate_algorithms_default = (option, algorithms) => {
  if (algorithms !== void 0 && (!Array.isArray(algorithms) || algorithms.some((s) => typeof s !== "string"))) {
    throw new TypeError(`"${option}" option must be an array of strings`);
  }
  if (!algorithms) {
    return void 0;
  }
  return new Set(algorithms);
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/is_jwk.js
function isJWK(key) {
  return is_object_default(key) && typeof key.kty === "string";
}
function isPrivateJWK(key) {
  return key.kty !== "oct" && (key.kty === "AKP" && typeof key.priv === "string" || typeof key.d === "string");
}
function isPublicJWK(key) {
  return key.kty !== "oct" && typeof key.d === "undefined" && typeof key.priv === "undefined";
}
function isSecretJWK(key) {
  return key.kty === "oct" && typeof key.k === "string";
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/normalize_key.js
var cache;
var handleJWK = async (key, jwk, alg, freeze = false) => {
  cache ||= /* @__PURE__ */ new WeakMap();
  let cached = cache.get(key);
  if (cached?.[alg]) {
    return cached[alg];
  }
  const cryptoKey = await jwk_to_key_default({ ...jwk, alg });
  if (freeze)
    Object.freeze(key);
  if (!cached) {
    cache.set(key, { [alg]: cryptoKey });
  } else {
    cached[alg] = cryptoKey;
  }
  return cryptoKey;
};
var handleKeyObject = (keyObject, alg) => {
  cache ||= /* @__PURE__ */ new WeakMap();
  let cached = cache.get(keyObject);
  if (cached?.[alg]) {
    return cached[alg];
  }
  const isPublic = keyObject.type === "public";
  const extractable = isPublic ? true : false;
  let cryptoKey;
  if (keyObject.asymmetricKeyType === "x25519") {
    switch (alg) {
      case "ECDH-ES":
      case "ECDH-ES+A128KW":
      case "ECDH-ES+A192KW":
      case "ECDH-ES+A256KW":
        break;
      default:
        throw new TypeError("given KeyObject instance cannot be used for this algorithm");
    }
    cryptoKey = keyObject.toCryptoKey(keyObject.asymmetricKeyType, extractable, isPublic ? [] : ["deriveBits"]);
  }
  if (keyObject.asymmetricKeyType === "ed25519") {
    if (alg !== "EdDSA" && alg !== "Ed25519") {
      throw new TypeError("given KeyObject instance cannot be used for this algorithm");
    }
    cryptoKey = keyObject.toCryptoKey(keyObject.asymmetricKeyType, extractable, [
      isPublic ? "verify" : "sign"
    ]);
  }
  switch (keyObject.asymmetricKeyType) {
    case "ml-dsa-44":
    case "ml-dsa-65":
    case "ml-dsa-87": {
      if (alg !== keyObject.asymmetricKeyType.toUpperCase()) {
        throw new TypeError("given KeyObject instance cannot be used for this algorithm");
      }
      cryptoKey = keyObject.toCryptoKey(keyObject.asymmetricKeyType, extractable, [
        isPublic ? "verify" : "sign"
      ]);
    }
  }
  if (keyObject.asymmetricKeyType === "rsa") {
    let hash2;
    switch (alg) {
      case "RSA-OAEP":
        hash2 = "SHA-1";
        break;
      case "RS256":
      case "PS256":
      case "RSA-OAEP-256":
        hash2 = "SHA-256";
        break;
      case "RS384":
      case "PS384":
      case "RSA-OAEP-384":
        hash2 = "SHA-384";
        break;
      case "RS512":
      case "PS512":
      case "RSA-OAEP-512":
        hash2 = "SHA-512";
        break;
      default:
        throw new TypeError("given KeyObject instance cannot be used for this algorithm");
    }
    if (alg.startsWith("RSA-OAEP")) {
      return keyObject.toCryptoKey({
        name: "RSA-OAEP",
        hash: hash2
      }, extractable, isPublic ? ["encrypt"] : ["decrypt"]);
    }
    cryptoKey = keyObject.toCryptoKey({
      name: alg.startsWith("PS") ? "RSA-PSS" : "RSASSA-PKCS1-v1_5",
      hash: hash2
    }, extractable, [isPublic ? "verify" : "sign"]);
  }
  if (keyObject.asymmetricKeyType === "ec") {
    const nist = /* @__PURE__ */ new Map([
      ["prime256v1", "P-256"],
      ["secp384r1", "P-384"],
      ["secp521r1", "P-521"]
    ]);
    const namedCurve = nist.get(keyObject.asymmetricKeyDetails?.namedCurve);
    if (!namedCurve) {
      throw new TypeError("given KeyObject instance cannot be used for this algorithm");
    }
    if (alg === "ES256" && namedCurve === "P-256") {
      cryptoKey = keyObject.toCryptoKey({
        name: "ECDSA",
        namedCurve
      }, extractable, [isPublic ? "verify" : "sign"]);
    }
    if (alg === "ES384" && namedCurve === "P-384") {
      cryptoKey = keyObject.toCryptoKey({
        name: "ECDSA",
        namedCurve
      }, extractable, [isPublic ? "verify" : "sign"]);
    }
    if (alg === "ES512" && namedCurve === "P-521") {
      cryptoKey = keyObject.toCryptoKey({
        name: "ECDSA",
        namedCurve
      }, extractable, [isPublic ? "verify" : "sign"]);
    }
    if (alg.startsWith("ECDH-ES")) {
      cryptoKey = keyObject.toCryptoKey({
        name: "ECDH",
        namedCurve
      }, extractable, isPublic ? [] : ["deriveBits"]);
    }
  }
  if (!cryptoKey) {
    throw new TypeError("given KeyObject instance cannot be used for this algorithm");
  }
  if (!cached) {
    cache.set(keyObject, { [alg]: cryptoKey });
  } else {
    cached[alg] = cryptoKey;
  }
  return cryptoKey;
};
var normalize_key_default = async (key, alg) => {
  if (key instanceof Uint8Array) {
    return key;
  }
  if (isCryptoKey(key)) {
    return key;
  }
  if (isKeyObject(key)) {
    if (key.type === "secret") {
      return key.export();
    }
    if ("toCryptoKey" in key && typeof key.toCryptoKey === "function") {
      try {
        return handleKeyObject(key, alg);
      } catch (err) {
        if (err instanceof TypeError) {
          throw err;
        }
      }
    }
    let jwk = key.export({ format: "jwk" });
    return handleJWK(key, jwk, alg);
  }
  if (isJWK(key)) {
    if (key.k) {
      return decode(key.k);
    }
    return handleJWK(key, key, alg, true);
  }
  throw new Error("unreachable");
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/check_key_type.js
var tag2 = (key) => key?.[Symbol.toStringTag];
var jwkMatchesOp = (alg, key, usage) => {
  if (key.use !== void 0) {
    let expected;
    switch (usage) {
      case "sign":
      case "verify":
        expected = "sig";
        break;
      case "encrypt":
      case "decrypt":
        expected = "enc";
        break;
    }
    if (key.use !== expected) {
      throw new TypeError(`Invalid key for this operation, its "use" must be "${expected}" when present`);
    }
  }
  if (key.alg !== void 0 && key.alg !== alg) {
    throw new TypeError(`Invalid key for this operation, its "alg" must be "${alg}" when present`);
  }
  if (Array.isArray(key.key_ops)) {
    let expectedKeyOp;
    switch (true) {
      case (usage === "sign" || usage === "verify"):
      case alg === "dir":
      case alg.includes("CBC-HS"):
        expectedKeyOp = usage;
        break;
      case alg.startsWith("PBES2"):
        expectedKeyOp = "deriveBits";
        break;
      case /^A\d{3}(?:GCM)?(?:KW)?$/.test(alg):
        if (!alg.includes("GCM") && alg.endsWith("KW")) {
          expectedKeyOp = usage === "encrypt" ? "wrapKey" : "unwrapKey";
        } else {
          expectedKeyOp = usage;
        }
        break;
      case (usage === "encrypt" && alg.startsWith("RSA")):
        expectedKeyOp = "wrapKey";
        break;
      case usage === "decrypt":
        expectedKeyOp = alg.startsWith("RSA") ? "unwrapKey" : "deriveBits";
        break;
    }
    if (expectedKeyOp && key.key_ops?.includes?.(expectedKeyOp) === false) {
      throw new TypeError(`Invalid key for this operation, its "key_ops" must include "${expectedKeyOp}" when present`);
    }
  }
  return true;
};
var symmetricTypeCheck = (alg, key, usage) => {
  if (key instanceof Uint8Array)
    return;
  if (isJWK(key)) {
    if (isSecretJWK(key) && jwkMatchesOp(alg, key, usage))
      return;
    throw new TypeError(`JSON Web Key for symmetric algorithms must have JWK "kty" (Key Type) equal to "oct" and the JWK "k" (Key Value) present`);
  }
  if (!is_key_like_default(key)) {
    throw new TypeError(withAlg(alg, key, "CryptoKey", "KeyObject", "JSON Web Key", "Uint8Array"));
  }
  if (key.type !== "secret") {
    throw new TypeError(`${tag2(key)} instances for symmetric algorithms must be of type "secret"`);
  }
};
var asymmetricTypeCheck = (alg, key, usage) => {
  if (isJWK(key)) {
    switch (usage) {
      case "decrypt":
      case "sign":
        if (isPrivateJWK(key) && jwkMatchesOp(alg, key, usage))
          return;
        throw new TypeError(`JSON Web Key for this operation be a private JWK`);
      case "encrypt":
      case "verify":
        if (isPublicJWK(key) && jwkMatchesOp(alg, key, usage))
          return;
        throw new TypeError(`JSON Web Key for this operation be a public JWK`);
    }
  }
  if (!is_key_like_default(key)) {
    throw new TypeError(withAlg(alg, key, "CryptoKey", "KeyObject", "JSON Web Key"));
  }
  if (key.type === "secret") {
    throw new TypeError(`${tag2(key)} instances for asymmetric algorithms must not be of type "secret"`);
  }
  if (key.type === "public") {
    switch (usage) {
      case "sign":
        throw new TypeError(`${tag2(key)} instances for asymmetric algorithm signing must be of type "private"`);
      case "decrypt":
        throw new TypeError(`${tag2(key)} instances for asymmetric algorithm decryption must be of type "private"`);
      default:
        break;
    }
  }
  if (key.type === "private") {
    switch (usage) {
      case "verify":
        throw new TypeError(`${tag2(key)} instances for asymmetric algorithm verifying must be of type "public"`);
      case "encrypt":
        throw new TypeError(`${tag2(key)} instances for asymmetric algorithm encryption must be of type "public"`);
      default:
        break;
    }
  }
};
var check_key_type_default = (alg, key, usage) => {
  const symmetric = alg.startsWith("HS") || alg === "dir" || alg.startsWith("PBES2") || /^A(?:128|192|256)(?:GCM)?(?:KW)?$/.test(alg) || /^A(?:128|192|256)CBC-HS(?:256|384|512)$/.test(alg);
  if (symmetric) {
    symmetricTypeCheck(alg, key, usage);
  } else {
    asymmetricTypeCheck(alg, key, usage);
  }
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/subtle_dsa.js
var subtle_dsa_default = (alg, algorithm) => {
  const hash2 = `SHA-${alg.slice(-3)}`;
  switch (alg) {
    case "HS256":
    case "HS384":
    case "HS512":
      return { hash: hash2, name: "HMAC" };
    case "PS256":
    case "PS384":
    case "PS512":
      return { hash: hash2, name: "RSA-PSS", saltLength: parseInt(alg.slice(-3), 10) >> 3 };
    case "RS256":
    case "RS384":
    case "RS512":
      return { hash: hash2, name: "RSASSA-PKCS1-v1_5" };
    case "ES256":
    case "ES384":
    case "ES512":
      return { hash: hash2, name: "ECDSA", namedCurve: algorithm.namedCurve };
    case "Ed25519":
    case "EdDSA":
      return { name: "Ed25519" };
    case "ML-DSA-44":
    case "ML-DSA-65":
    case "ML-DSA-87":
      return { name: alg };
    default:
      throw new JOSENotSupported(`alg ${alg} is not supported either by JOSE or your javascript runtime`);
  }
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/get_sign_verify_key.js
var get_sign_verify_key_default = async (alg, key, usage) => {
  if (key instanceof Uint8Array) {
    if (!alg.startsWith("HS")) {
      throw new TypeError(invalid_key_input_default(key, "CryptoKey", "KeyObject", "JSON Web Key"));
    }
    return crypto.subtle.importKey("raw", key, { hash: `SHA-${alg.slice(-3)}`, name: "HMAC" }, false, [usage]);
  }
  checkSigCryptoKey(key, alg, usage);
  return key;
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/verify.js
var verify_default = async (alg, key, signature, data) => {
  const cryptoKey = await get_sign_verify_key_default(alg, key, "verify");
  check_key_length_default(alg, cryptoKey);
  const algorithm = subtle_dsa_default(alg, cryptoKey.algorithm);
  try {
    return await crypto.subtle.verify(algorithm, cryptoKey, signature, data);
  } catch {
    return false;
  }
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/jws/flattened/verify.js
async function flattenedVerify(jws, key, options) {
  if (!is_object_default(jws)) {
    throw new JWSInvalid("Flattened JWS must be an object");
  }
  if (jws.protected === void 0 && jws.header === void 0) {
    throw new JWSInvalid('Flattened JWS must have either of the "protected" or "header" members');
  }
  if (jws.protected !== void 0 && typeof jws.protected !== "string") {
    throw new JWSInvalid("JWS Protected Header incorrect type");
  }
  if (jws.payload === void 0) {
    throw new JWSInvalid("JWS Payload missing");
  }
  if (typeof jws.signature !== "string") {
    throw new JWSInvalid("JWS Signature missing or incorrect type");
  }
  if (jws.header !== void 0 && !is_object_default(jws.header)) {
    throw new JWSInvalid("JWS Unprotected Header incorrect type");
  }
  let parsedProt = {};
  if (jws.protected) {
    try {
      const protectedHeader = decode(jws.protected);
      parsedProt = JSON.parse(decoder.decode(protectedHeader));
    } catch {
      throw new JWSInvalid("JWS Protected Header is invalid");
    }
  }
  if (!is_disjoint_default(parsedProt, jws.header)) {
    throw new JWSInvalid("JWS Protected and JWS Unprotected Header Parameter names must be disjoint");
  }
  const joseHeader = {
    ...parsedProt,
    ...jws.header
  };
  const extensions = validate_crit_default(JWSInvalid, /* @__PURE__ */ new Map([["b64", true]]), options?.crit, parsedProt, joseHeader);
  let b64 = true;
  if (extensions.has("b64")) {
    b64 = parsedProt.b64;
    if (typeof b64 !== "boolean") {
      throw new JWSInvalid('The "b64" (base64url-encode payload) Header Parameter must be a boolean');
    }
  }
  const { alg } = joseHeader;
  if (typeof alg !== "string" || !alg) {
    throw new JWSInvalid('JWS "alg" (Algorithm) Header Parameter missing or invalid');
  }
  const algorithms = options && validate_algorithms_default("algorithms", options.algorithms);
  if (algorithms && !algorithms.has(alg)) {
    throw new JOSEAlgNotAllowed('"alg" (Algorithm) Header Parameter value not allowed');
  }
  if (b64) {
    if (typeof jws.payload !== "string") {
      throw new JWSInvalid("JWS Payload must be a string");
    }
  } else if (typeof jws.payload !== "string" && !(jws.payload instanceof Uint8Array)) {
    throw new JWSInvalid("JWS Payload must be a string or an Uint8Array instance");
  }
  let resolvedKey = false;
  if (typeof key === "function") {
    key = await key(parsedProt, jws);
    resolvedKey = true;
  }
  check_key_type_default(alg, key, "verify");
  const data = concat(encoder.encode(jws.protected ?? ""), encoder.encode("."), typeof jws.payload === "string" ? encoder.encode(jws.payload) : jws.payload);
  let signature;
  try {
    signature = decode(jws.signature);
  } catch {
    throw new JWSInvalid("Failed to base64url decode the signature");
  }
  const k = await normalize_key_default(key, alg);
  const verified = await verify_default(alg, k, signature, data);
  if (!verified) {
    throw new JWSSignatureVerificationFailed();
  }
  let payload;
  if (b64) {
    try {
      payload = decode(jws.payload);
    } catch {
      throw new JWSInvalid("Failed to base64url decode the payload");
    }
  } else if (typeof jws.payload === "string") {
    payload = encoder.encode(jws.payload);
  } else {
    payload = jws.payload;
  }
  const result = { payload };
  if (jws.protected !== void 0) {
    result.protectedHeader = parsedProt;
  }
  if (jws.header !== void 0) {
    result.unprotectedHeader = jws.header;
  }
  if (resolvedKey) {
    return { ...result, key: k };
  }
  return result;
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/jws/compact/verify.js
async function compactVerify(jws, key, options) {
  if (jws instanceof Uint8Array) {
    jws = decoder.decode(jws);
  }
  if (typeof jws !== "string") {
    throw new JWSInvalid("Compact JWS must be a string or Uint8Array");
  }
  const { 0: protectedHeader, 1: payload, 2: signature, length } = jws.split(".");
  if (length !== 3) {
    throw new JWSInvalid("Invalid Compact JWS");
  }
  const verified = await flattenedVerify({ payload, protected: protectedHeader, signature }, key, options);
  const result = { payload: verified.payload, protectedHeader: verified.protectedHeader };
  if (typeof key === "function") {
    return { ...result, key: verified.key };
  }
  return result;
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/epoch.js
var epoch_default = (date) => Math.floor(date.getTime() / 1e3);

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/secs.js
var minute = 60;
var hour = minute * 60;
var day = hour * 24;
var week = day * 7;
var year = day * 365.25;
var REGEX = /^(\+|\-)? ?(\d+|\d+\.\d+) ?(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|w|years?|yrs?|y)(?: (ago|from now))?$/i;
var secs_default = (str) => {
  const matched = REGEX.exec(str);
  if (!matched || matched[4] && matched[1]) {
    throw new TypeError("Invalid time period format");
  }
  const value = parseFloat(matched[2]);
  const unit = matched[3].toLowerCase();
  let numericDate;
  switch (unit) {
    case "sec":
    case "secs":
    case "second":
    case "seconds":
    case "s":
      numericDate = Math.round(value);
      break;
    case "minute":
    case "minutes":
    case "min":
    case "mins":
    case "m":
      numericDate = Math.round(value * minute);
      break;
    case "hour":
    case "hours":
    case "hr":
    case "hrs":
    case "h":
      numericDate = Math.round(value * hour);
      break;
    case "day":
    case "days":
    case "d":
      numericDate = Math.round(value * day);
      break;
    case "week":
    case "weeks":
    case "w":
      numericDate = Math.round(value * week);
      break;
    default:
      numericDate = Math.round(value * year);
      break;
  }
  if (matched[1] === "-" || matched[4] === "ago") {
    return -numericDate;
  }
  return numericDate;
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/jwt_claims_set.js
function validateInput(label, input) {
  if (!Number.isFinite(input)) {
    throw new TypeError(`Invalid ${label} input`);
  }
  return input;
}
var normalizeTyp = (value) => {
  if (value.includes("/")) {
    return value.toLowerCase();
  }
  return `application/${value.toLowerCase()}`;
};
var checkAudiencePresence = (audPayload, audOption) => {
  if (typeof audPayload === "string") {
    return audOption.includes(audPayload);
  }
  if (Array.isArray(audPayload)) {
    return audOption.some(Set.prototype.has.bind(new Set(audPayload)));
  }
  return false;
};
function validateClaimsSet(protectedHeader, encodedPayload, options = {}) {
  let payload;
  try {
    payload = JSON.parse(decoder.decode(encodedPayload));
  } catch {
  }
  if (!is_object_default(payload)) {
    throw new JWTInvalid("JWT Claims Set must be a top-level JSON object");
  }
  const { typ } = options;
  if (typ && (typeof protectedHeader.typ !== "string" || normalizeTyp(protectedHeader.typ) !== normalizeTyp(typ))) {
    throw new JWTClaimValidationFailed('unexpected "typ" JWT header value', payload, "typ", "check_failed");
  }
  const { requiredClaims = [], issuer, subject, audience: audience2, maxTokenAge } = options;
  const presenceCheck = [...requiredClaims];
  if (maxTokenAge !== void 0)
    presenceCheck.push("iat");
  if (audience2 !== void 0)
    presenceCheck.push("aud");
  if (subject !== void 0)
    presenceCheck.push("sub");
  if (issuer !== void 0)
    presenceCheck.push("iss");
  for (const claim of new Set(presenceCheck.reverse())) {
    if (!(claim in payload)) {
      throw new JWTClaimValidationFailed(`missing required "${claim}" claim`, payload, claim, "missing");
    }
  }
  if (issuer && !(Array.isArray(issuer) ? issuer : [issuer]).includes(payload.iss)) {
    throw new JWTClaimValidationFailed('unexpected "iss" claim value', payload, "iss", "check_failed");
  }
  if (subject && payload.sub !== subject) {
    throw new JWTClaimValidationFailed('unexpected "sub" claim value', payload, "sub", "check_failed");
  }
  if (audience2 && !checkAudiencePresence(payload.aud, typeof audience2 === "string" ? [audience2] : audience2)) {
    throw new JWTClaimValidationFailed('unexpected "aud" claim value', payload, "aud", "check_failed");
  }
  let tolerance;
  switch (typeof options.clockTolerance) {
    case "string":
      tolerance = secs_default(options.clockTolerance);
      break;
    case "number":
      tolerance = options.clockTolerance;
      break;
    case "undefined":
      tolerance = 0;
      break;
    default:
      throw new TypeError("Invalid clockTolerance option type");
  }
  const { currentDate } = options;
  const now2 = epoch_default(currentDate || /* @__PURE__ */ new Date());
  if ((payload.iat !== void 0 || maxTokenAge) && typeof payload.iat !== "number") {
    throw new JWTClaimValidationFailed('"iat" claim must be a number', payload, "iat", "invalid");
  }
  if (payload.nbf !== void 0) {
    if (typeof payload.nbf !== "number") {
      throw new JWTClaimValidationFailed('"nbf" claim must be a number', payload, "nbf", "invalid");
    }
    if (payload.nbf > now2 + tolerance) {
      throw new JWTClaimValidationFailed('"nbf" claim timestamp check failed', payload, "nbf", "check_failed");
    }
  }
  if (payload.exp !== void 0) {
    if (typeof payload.exp !== "number") {
      throw new JWTClaimValidationFailed('"exp" claim must be a number', payload, "exp", "invalid");
    }
    if (payload.exp <= now2 - tolerance) {
      throw new JWTExpired('"exp" claim timestamp check failed', payload, "exp", "check_failed");
    }
  }
  if (maxTokenAge) {
    const age = now2 - payload.iat;
    const max = typeof maxTokenAge === "number" ? maxTokenAge : secs_default(maxTokenAge);
    if (age - tolerance > max) {
      throw new JWTExpired('"iat" claim timestamp check failed (too far in the past)', payload, "iat", "check_failed");
    }
    if (age < 0 - tolerance) {
      throw new JWTClaimValidationFailed('"iat" claim timestamp check failed (it should be in the past)', payload, "iat", "check_failed");
    }
  }
  return payload;
}
var JWTClaimsBuilder = class {
  #payload;
  constructor(payload) {
    if (!is_object_default(payload)) {
      throw new TypeError("JWT Claims Set MUST be an object");
    }
    this.#payload = structuredClone(payload);
  }
  data() {
    return encoder.encode(JSON.stringify(this.#payload));
  }
  get iss() {
    return this.#payload.iss;
  }
  set iss(value) {
    this.#payload.iss = value;
  }
  get sub() {
    return this.#payload.sub;
  }
  set sub(value) {
    this.#payload.sub = value;
  }
  get aud() {
    return this.#payload.aud;
  }
  set aud(value) {
    this.#payload.aud = value;
  }
  set jti(value) {
    this.#payload.jti = value;
  }
  set nbf(value) {
    if (typeof value === "number") {
      this.#payload.nbf = validateInput("setNotBefore", value);
    } else if (value instanceof Date) {
      this.#payload.nbf = validateInput("setNotBefore", epoch_default(value));
    } else {
      this.#payload.nbf = epoch_default(/* @__PURE__ */ new Date()) + secs_default(value);
    }
  }
  set exp(value) {
    if (typeof value === "number") {
      this.#payload.exp = validateInput("setExpirationTime", value);
    } else if (value instanceof Date) {
      this.#payload.exp = validateInput("setExpirationTime", epoch_default(value));
    } else {
      this.#payload.exp = epoch_default(/* @__PURE__ */ new Date()) + secs_default(value);
    }
  }
  set iat(value) {
    if (typeof value === "undefined") {
      this.#payload.iat = epoch_default(/* @__PURE__ */ new Date());
    } else if (value instanceof Date) {
      this.#payload.iat = validateInput("setIssuedAt", epoch_default(value));
    } else if (typeof value === "string") {
      this.#payload.iat = validateInput("setIssuedAt", epoch_default(/* @__PURE__ */ new Date()) + secs_default(value));
    } else {
      this.#payload.iat = validateInput("setIssuedAt", value);
    }
  }
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/jwt/verify.js
async function jwtVerify(jwt, key, options) {
  const verified = await compactVerify(jwt, key, options);
  if (verified.protectedHeader.crit?.includes("b64") && verified.protectedHeader.b64 === false) {
    throw new JWTInvalid("JWTs MUST NOT use unencoded payload");
  }
  const payload = validateClaimsSet(verified.protectedHeader, verified.payload, options);
  const result = { payload, protectedHeader: verified.protectedHeader };
  if (typeof key === "function") {
    return { ...result, key: verified.key };
  }
  return result;
}

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/lib/sign.js
var sign_default = async (alg, key, data) => {
  const cryptoKey = await get_sign_verify_key_default(alg, key, "sign");
  check_key_length_default(alg, cryptoKey);
  const signature = await crypto.subtle.sign(subtle_dsa_default(alg, cryptoKey.algorithm), cryptoKey, data);
  return new Uint8Array(signature);
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/jws/flattened/sign.js
var FlattenedSign = class {
  #payload;
  #protectedHeader;
  #unprotectedHeader;
  constructor(payload) {
    if (!(payload instanceof Uint8Array)) {
      throw new TypeError("payload must be an instance of Uint8Array");
    }
    this.#payload = payload;
  }
  setProtectedHeader(protectedHeader) {
    if (this.#protectedHeader) {
      throw new TypeError("setProtectedHeader can only be called once");
    }
    this.#protectedHeader = protectedHeader;
    return this;
  }
  setUnprotectedHeader(unprotectedHeader) {
    if (this.#unprotectedHeader) {
      throw new TypeError("setUnprotectedHeader can only be called once");
    }
    this.#unprotectedHeader = unprotectedHeader;
    return this;
  }
  async sign(key, options) {
    if (!this.#protectedHeader && !this.#unprotectedHeader) {
      throw new JWSInvalid("either setProtectedHeader or setUnprotectedHeader must be called before #sign()");
    }
    if (!is_disjoint_default(this.#protectedHeader, this.#unprotectedHeader)) {
      throw new JWSInvalid("JWS Protected and JWS Unprotected Header Parameter names must be disjoint");
    }
    const joseHeader = {
      ...this.#protectedHeader,
      ...this.#unprotectedHeader
    };
    const extensions = validate_crit_default(JWSInvalid, /* @__PURE__ */ new Map([["b64", true]]), options?.crit, this.#protectedHeader, joseHeader);
    let b64 = true;
    if (extensions.has("b64")) {
      b64 = this.#protectedHeader.b64;
      if (typeof b64 !== "boolean") {
        throw new JWSInvalid('The "b64" (base64url-encode payload) Header Parameter must be a boolean');
      }
    }
    const { alg } = joseHeader;
    if (typeof alg !== "string" || !alg) {
      throw new JWSInvalid('JWS "alg" (Algorithm) Header Parameter missing or invalid');
    }
    check_key_type_default(alg, key, "sign");
    let payload = this.#payload;
    if (b64) {
      payload = encoder.encode(encode(payload));
    }
    let protectedHeader;
    if (this.#protectedHeader) {
      protectedHeader = encoder.encode(encode(JSON.stringify(this.#protectedHeader)));
    } else {
      protectedHeader = encoder.encode("");
    }
    const data = concat(protectedHeader, encoder.encode("."), payload);
    const k = await normalize_key_default(key, alg);
    const signature = await sign_default(alg, k, data);
    const jws = {
      signature: encode(signature),
      payload: ""
    };
    if (b64) {
      jws.payload = decoder.decode(payload);
    }
    if (this.#unprotectedHeader) {
      jws.header = this.#unprotectedHeader;
    }
    if (this.#protectedHeader) {
      jws.protected = decoder.decode(protectedHeader);
    }
    return jws;
  }
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/jws/compact/sign.js
var CompactSign = class {
  #flattened;
  constructor(payload) {
    this.#flattened = new FlattenedSign(payload);
  }
  setProtectedHeader(protectedHeader) {
    this.#flattened.setProtectedHeader(protectedHeader);
    return this;
  }
  async sign(key, options) {
    const jws = await this.#flattened.sign(key, options);
    if (jws.payload === void 0) {
      throw new TypeError("use the flattened module for creating JWS with b64: false");
    }
    return `${jws.protected}.${jws.payload}.${jws.signature}`;
  }
};

// ../../../../tmp/ancient-audit-deps/node_modules/jose/dist/webapi/jwt/sign.js
var SignJWT = class {
  #protectedHeader;
  #jwt;
  constructor(payload = {}) {
    this.#jwt = new JWTClaimsBuilder(payload);
  }
  setIssuer(issuer) {
    this.#jwt.iss = issuer;
    return this;
  }
  setSubject(subject) {
    this.#jwt.sub = subject;
    return this;
  }
  setAudience(audience2) {
    this.#jwt.aud = audience2;
    return this;
  }
  setJti(jwtId) {
    this.#jwt.jti = jwtId;
    return this;
  }
  setNotBefore(input) {
    this.#jwt.nbf = input;
    return this;
  }
  setExpirationTime(input) {
    this.#jwt.exp = input;
    return this;
  }
  setIssuedAt(input) {
    this.#jwt.iat = input;
    return this;
  }
  setProtectedHeader(protectedHeader) {
    this.#protectedHeader = protectedHeader;
    return this;
  }
  async sign(key, options) {
    const sig = new CompactSign(this.#jwt.data());
    sig.setProtectedHeader(this.#protectedHeader);
    if (Array.isArray(this.#protectedHeader?.crit) && this.#protectedHeader.crit.includes("b64") && this.#protectedHeader.b64 === false) {
      throw new JWTInvalid("JWTs MUST NOT use unencoded payload");
    }
    return sig.sign(key, options);
  }
};

// src/game-identity.js
var audience = "ancient-nest-matchmaking";
var encoder2 = new TextEncoder();
var hex = (data) => Array.from(new Uint8Array(data), (b) => b.toString(16).padStart(2, "0")).join("");
function gameIdentity({ HttpError: HttpError2, json: json2, body: body2, bearer: bearer2, authenticate: authenticate2, rateLimit: rateLimit2 }) {
  return async function handle(request2, env, db, key) {
    const path = new URL(request2.url).pathname;
    if (!["/api/game/assertion", "/api/game/verify"].includes(path)) throw new HttpError2(404, "not_found");
    if (request2.method !== "POST") throw new HttpError2(405, "method_not_allowed", { Allow: "POST" });
    const value = await body2(request2);
    if (path === "/api/game/assertion") {
      const auth = await authenticate2(bearer2(request2), db, key);
      await rateLimit2(db, key, "game-assertion", auth.user.id, 30);
      const pem = value.public_key;
      if (typeof pem !== "string" || pem.length > 3e3 || !pem.startsWith("-----BEGIN PUBLIC KEY-----") || !pem.includes("-----END PUBLIC KEY-----")) {
        throw new HttpError2(400, "valid_game_public_key_required");
      }
      try {
        const bytes2 = Uint8Array.from(atob(pem.replace(/-----BEGIN PUBLIC KEY-----|-----END PUBLIC KEY-----|\s/g, "")), (c) => c.charCodeAt(0));
        const imported = await crypto.subtle.importKey("spki", bytes2, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
        if (imported.algorithm.modulusLength < 2048) throw new Error();
      } catch {
        throw new HttpError2(400, "valid_game_public_key_required");
      }
      const keyHash = hex(await crypto.subtle.digest("SHA-256", encoder2.encode(pem)));
      const now2 = Math.floor(Date.now() / 1e3);
      const expires = Math.min(now2 + 600, auth.expires);
      const assertion = await new SignJWT({ kind: "game-assertion", key_hash: keyHash }).setProtectedHeader({ alg: "HS256", typ: "JWT" }).setIssuer("ancient-nest-accounts").setAudience(audience).setSubject(auth.user.id).setJti(auth.sessionId).setIssuedAt(now2).setExpirationTime(expires).sign(key);
      return json2({
        assertion,
        account_id: auth.user.id,
        username: auth.user.username,
        key_hash: keyHash,
        expires_in: expires - now2
      });
    }
    if (typeof value.key_hash !== "string" || !/^[a-f0-9]{64}$/.test(value.key_hash)) throw new HttpError2(400, "valid_key_hash_required");
    await rateLimit2(db, key, "game-verify-ip", request2.headers.get("CF-Connecting-IP") ?? "local", 1200);
    try {
      const auth = await authenticate2(value.assertion, db, key, audience);
      if (auth.claims.kind !== "game-assertion" || auth.claims.key_hash !== value.key_hash) return json2({ valid: false }, 401);
      return json2({ valid: true, account_id: auth.user.id, username: auth.user.username, key_hash: value.key_hash });
    } catch (error) {
      if (error instanceof HttpError2 && error.status === 401) return json2({ valid: false }, 401);
      throw error;
    }
  };
}

// src/live-test-page.js
var testPage = `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Ancient Nest service test</title>
<link rel="stylesheet" href="/setup-test.css">
<main><h1>Ancient Nest service test</h1>
<p>Use your own email and phone to test real delivery. Creating an account sends verification messages and may incur provider charges. Tokens stay in this page's memory. Sign out when finished.</p>
<button id="health">Check configuration</button><pre id="health-status" aria-live="polite"></pre>
<h2>Account</h2><form id="account-form">
<label>Username<input id="username" autocomplete="username" minlength="3" maxlength="24" required></label>
<label>Password<input id="password" type="password" autocomplete="current-password" minlength="8" maxlength="128" required></label>
<label>Email (required for new accounts)<input id="email" type="email" autocomplete="email" maxlength="254"></label>
<label>Phone with country code (required for new accounts)<input id="phone" type="tel" autocomplete="tel" placeholder="+12345678900" maxlength="32"></label>
<div><button type="submit" id="register">Create account / send codes</button><button type="submit" id="login">Sign in</button></div></form>
<p id="status" role="status"></p><pre id="account-status"></pre>
<h2>Verify real delivery</h2><p>Enter the codes you actually received. A successful send request alone does not prove delivery.</p>
<label>Email code<input id="email-code" inputmode="numeric" maxlength="6" autocomplete="one-time-code"></label>
<button data-verify="email">Verify email</button> <button data-resend="email">Resend email</button>
<label>SMS code<input id="phone-code" inputmode="numeric" maxlength="6" autocomplete="one-time-code"></label>
<button data-verify="phone">Verify phone</button> <button data-resend="phone">Resend SMS</button>
<h2>Session and Discord identity</h2><button id="refresh">Test saved-session refresh</button>
<button id="profile">Refresh account status</button><button id="discord">Get Discord linking URL</button>
<a id="discord-link" hidden target="_blank" rel="noopener noreferrer">Authorize Discord</a>
<button id="logout">Sign out this test session</button>
<p>This page tests accounts, delivery and Discord linking. Windows credential storage and two-player audio require the Windows client. Team assignment must come from the trusted coordinator.</p>
</main><script src="/setup-test.js" defer><\/script></html>`;
var testCss = `:root{color-scheme:dark;font:16px system-ui}body{margin:0;background:#111c29;color:#edf3f8}main{max-width:760px;margin:auto;padding:24px}label{display:block;margin:12px 0}input{display:block;box-sizing:border-box;width:100%;padding:10px;margin-top:5px}button,a{display:inline-block;margin:5px 8px 5px 0;padding:10px;cursor:pointer}button:disabled{opacity:.5}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#1b2b3d;padding:12px;border-radius:6px}p{line-height:1.5}#status{min-height:24px}`;
var testScript = `"use strict";
let session = null;
let busy = false;
const el = id => document.getElementById(id);
async function api(path, method = 'GET', data, authorized = true) {
  const headers = {};
  if (data !== undefined) headers['Content-Type'] = 'application/json';
  if (authorized && session) headers.Authorization = 'Bearer ' + session.token;
  const response = await fetch(path, { method, headers, cache: 'no-store', redirect: 'error',
    body: data === undefined ? undefined : JSON.stringify(data), signal: AbortSignal.timeout(15000) });
  const value = await response.json();
  if (!response.ok) throw new Error(value.error || ('HTTP ' + response.status));
  return value;
}
async function action(callback) {
  if (busy) return;
  busy = true;
  document.querySelectorAll('button').forEach(button => { button.disabled = true; });
  el('status').textContent = 'Working\u2026';
  try { await callback(); }
  catch (error) { el('status').textContent = 'Test stopped: ' + error.message; }
  finally {
    busy = false;
    document.querySelectorAll('button').forEach(button => { button.disabled = false; });
  }
}
function requireSession() { if (!session) throw new Error('Sign in or create an account first.'); }
async function profile() {
  requireSession();
  const value = await api('/account');
  el('account-status').textContent = JSON.stringify(value, null, 2);
}
el('account-form').addEventListener('submit', event => {
  event.preventDefault();
  const register = event.submitter?.id !== 'login';
  action(async () => {
    if (session) throw new Error('Sign out the current test session before signing into another account.');
    const data = { username: el('username').value.trim(), password: el('password').value };
    if (register) { data.email = el('email').value.trim(); data.phone = el('phone').value.trim(); }
    try { session = await api(register ? '/register' : '/login', 'POST', data, false); }
    finally { el('password').value = ''; }
    await profile();
    el('status').textContent = session.send_errors?.length
      ? 'Account created, but sending failed: ' + JSON.stringify(session.send_errors)
      : (register ? 'Account created. Check your email and phone, then verify the received codes.' : 'Signed in.');
  });
});
document.querySelectorAll('[data-verify]').forEach(button => button.addEventListener('click', () => action(async () => {
  requireSession();
  const type = button.dataset.verify;
  const code = el(type + '-code').value.trim();
  if (!/^\\d{6}$/.test(code)) throw new Error('Enter the six-digit code you received.');
  await api('/verify/' + type, 'POST', { code });
  el(type + '-code').value = '';
  await profile();
  el('status').textContent = type + ' delivery and verification passed.';
})));
document.querySelectorAll('[data-resend]').forEach(button => button.addEventListener('click', () => action(async () => {
  requireSession();
  await api('/verify/' + button.dataset.resend + '/resend', 'POST', {});
  el('status').textContent = 'Provider accepted the send request. Verify the new code when it arrives.';
})));
el('health').addEventListener('click', () => action(async () => {
  const checks = {};
  for (const path of ['/ready', '/discord/ready']) {
    const response = await fetch(path, { cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000) });
    checks[path] = { http_status: response.status, ...await response.json() };
  }
  el('health-status').textContent = JSON.stringify(checks, null, 2);
  el('status').textContent = 'Configuration checked. Delivery and audio must be tested separately.';
}));
el('profile').addEventListener('click', () => action(async () => { await profile(); el('status').textContent = 'Account status updated.'; }));
el('refresh').addEventListener('click', () => action(async () => {
  requireSession();
  session = await api('/refresh', 'POST', { refresh_token: session.refresh_token }, false);
  await profile();
  el('status').textContent = 'Session refresh passed. Windows saved sign-in is tested in the client.';
}));
el('discord').addEventListener('click', () => action(async () => {
  requireSession();
  const value = await api('/auth/discord');
  const url = new URL(value.url);
  if (url.origin !== 'https://discord.com' || url.pathname !== '/oauth2/authorize') throw new Error('Unexpected authorization URL.');
  el('discord-link').href = url.href;
  el('discord-link').hidden = false;
  el('status').textContent = 'Use Authorize Discord, then refresh account status after returning.';
}));
el('logout').addEventListener('click', () => action(async () => {
  requireSession();
  await api('/logout', 'POST', { refresh_token: session.refresh_token }, false);
  session = null;
  el('account-status').textContent = '';
  el('discord-link').hidden = true;
  el('discord-link').removeAttribute('href');
  el('status').textContent = 'Test session revoked and removed from this page.';
}));`;
function liveTestRoute(path) {
  const files = {
    "/setup-test": [testPage, "text/html; charset=utf-8"],
    "/setup-test.js": [testScript, "text/javascript; charset=utf-8"],
    "/setup-test.css": [testCss, "text/css; charset=utf-8"]
  };
  if (!files[path]) return null;
  const [content, type] = files[path];
  return new Response(content, { headers: {
    "Content-Type": type,
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
    "Referrer-Policy": "no-referrer"
  } });
}

// src/passwords.js
var encoder3 = new TextEncoder();
var ITERATIONS = 6e5;
var hex2 = (bytes2) => Array.from(new Uint8Array(bytes2), (b) => b.toString(16).padStart(2, "0")).join("");
var bytes = (value) => Uint8Array.from(value.match(/../g), (x) => parseInt(x, 16));
async function derive(password, salt, iterations) {
  const key = await crypto.subtle.importKey("raw", encoder3.encode(password), "PBKDF2", false, ["deriveBits"]);
  return crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations, hash: "SHA-256" }, key, 256);
}
async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash2 = await derive(password, salt, ITERATIONS);
  return `pbkdf2-sha256$${ITERATIONS}$${hex2(salt)}$${hex2(hash2)}`;
}
var DUMMY_HASH = `pbkdf2-sha256$${ITERATIONS}$${"00".repeat(16)}$${"00".repeat(32)}`;
async function passwordRecord(password) {
  const hash2 = await hashPassword(password);
  const salt = bytes(hash2.split("$")[2]);
  return { hash: hash2, salt: btoa(String.fromCharCode(...salt)) };
}
async function verifyPassword(password, encoded, storedSalt) {
  if (!encoded.startsWith("pbkdf2-sha256$") && storedSalt) {
    const salt = Uint8Array.from(atob(storedSalt), (c) => c.charCodeAt(0));
    const expected2 = Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0));
    const actual2 = new Uint8Array(await derive(password, salt, 1e5));
    let difference2 = expected2.length ^ actual2.length;
    for (let i = 0; i < actual2.length; i++) difference2 |= actual2[i] ^ (expected2[i] ?? 0);
    return difference2 === 0;
  }
  const parts = /^pbkdf2-sha256\$(\d+)\$([a-f0-9]{32})\$([a-f0-9]{64})$/.exec(encoded);
  if (!parts || Number(parts[1]) !== ITERATIONS) throw new Error("Unsupported password hash");
  const actual = new Uint8Array(await derive(password, bytes(parts[2]), Number(parts[1])));
  const expected = bytes(parts[3]);
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= actual[i] ^ expected[i];
  return difference === 0;
}

// src/discord.js
var API = "https://discord.com/api/v10";
function desktopRedirect(value) {
  if (typeof value !== "string" || value.length > 128) return false;
  try {
    const url = new URL(value);
    return url.protocol === "http:" && url.hostname === "127.0.0.1" && url.pathname === "/callback" && !url.username && !url.password && !url.search && !url.hash;
  } catch {
    return false;
  }
}
var snowflake = (value) => typeof value === "string" && /^[0-9]{17,20}$/.test(value);
var identifier = (value) => typeof value === "string" && /^[a-zA-Z0-9_-]{1,64}$/.test(value);
function discordRoutes({ HttpError: HttpError2, json: json2, body: body2, authenticate: authenticate2, bearer: bearer2, rateLimit: rateLimit2, coordinator: coordinator3 }) {
  function configured2(env, bot = false) {
    if (!snowflake(env.DISCORD_CLIENT_ID) || typeof env.DISCORD_CLIENT_SECRET !== "string" || env.DISCORD_CLIENT_SECRET.length < 16 || bot && (!env.DISCORD_BOT_TOKEN || env.DISCORD_BOT_TOKEN.length < 16)) {
      throw new HttpError2(503, "discord_not_configured");
    }
  }
  async function remote(env, path, options, { oauth: oauth2 = false, missingOk = false } = {}) {
    let response;
    try {
      const request2 = new Request(API + path, { ...options, redirect: "manual", signal: AbortSignal.timeout(1e4) });
      response = env.DISCORD_HTTP ? await env.DISCORD_HTTP.fetch(request2) : await fetch(request2);
    } catch {
      throw new HttpError2(503, "discord_unavailable");
    }
    if (missingOk && response.status === 404) return null;
    if (response.status === 429) {
      const seconds = Math.min(3600, Math.max(1, Number(response.headers.get("Retry-After")) || 5));
      throw new HttpError2(503, "discord_rate_limited", { "Retry-After": String(Math.ceil(seconds)) });
    }
    if (!response.ok) {
      throw new HttpError2(
        oauth2 && [400, 401].includes(response.status) ? 401 : 503,
        oauth2 && [400, 401].includes(response.status) ? "discord_authorization_expired" : "discord_unavailable"
      );
    }
    if (response.status === 204) return null;
    try {
      return await response.json();
    } catch {
      throw new HttpError2(503, "discord_invalid_response");
    }
  }
  function botOptions(env, method, data) {
    return {
      method,
      headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, "Content-Type": "application/json" },
      ...data ? { body: JSON.stringify(data) } : {}
    };
  }
  async function oauth(env, grant) {
    const form = new URLSearchParams({ client_id: env.DISCORD_CLIENT_ID, client_secret: env.DISCORD_CLIENT_SECRET, ...grant });
    const tokens = await remote(env, "/oauth2/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form.toString()
    }, { oauth: true });
    if (typeof tokens.access_token !== "string" || typeof tokens.refresh_token !== "string" || tokens.token_type?.toLowerCase() !== "bearer" || !Number.isFinite(tokens.expires_in) || tokens.expires_in <= 0) {
      throw new HttpError2(503, "discord_invalid_response");
    }
    if (!(tokens.scope ?? "").split(/\s+/).includes("sdk.social_layer")) throw new HttpError2(403, "discord_voice_scope_required");
    const user = await remote(env, "/users/@me", { headers: { Authorization: `Bearer ${tokens.access_token}` } }, { oauth: true });
    if (!snowflake(user.id)) throw new HttpError2(503, "discord_invalid_response");
    return { tokens, discordId: user.id, discordUser: user };
  }
  async function linkUser(db, userId, user) {
    if (!snowflake(user?.id)) throw new HttpError2(503, "discord_invalid_response");
    let updated;
    try {
      updated = await db.prepare(`UPDATE users SET discord_id = ?, discord_username = ? WHERE id = ?
        AND banned = 0 AND (discord_id IS NULL OR discord_id = ?) RETURNING discord_id`).bind(user.id, String(user.username || user.global_name || user.id).slice(0, 80), userId, user.id).first();
    } catch (error) {
      if (/UNIQUE constraint failed/.test(String(error))) throw new HttpError2(409, "discord_account_already_linked");
      throw error;
    }
    if (!updated) throw new HttpError2(409, "different_discord_account_linked");
  }
  async function endMatch(env, db, matchId) {
    await db.prepare("UPDATE voice_matches SET status = 'deleting' WHERE id = ?").bind(matchId).run();
    const { results } = await db.prepare("SELECT lobby_id FROM voice_rooms WHERE match_id = ? AND lobby_id IS NOT NULL").bind(matchId).all();
    const removed = await Promise.allSettled(results.map((room) => remote(env, `/lobbies/${room.lobby_id}`, botOptions(env, "DELETE"), { missingOk: true })));
    if (removed.some((result) => result.status === "rejected")) throw new HttpError2(503, "discord_cleanup_pending");
    await db.prepare("DELETE FROM voice_matches WHERE id = ?").bind(matchId).run();
  }
  async function matchResult(db, matchId) {
    const { results } = await db.prepare("SELECT team_id, lobby_id FROM voice_rooms WHERE match_id = ? ORDER BY team_id").bind(matchId).all();
    return { match_id: matchId, teams: results };
  }
  async function createMatch(env, db, value) {
    const now2 = Math.floor(Date.now() / 1e3);
    if (!identifier(value.match_id) || !Number.isSafeInteger(value.expires_at) || value.expires_at <= now2 || value.expires_at > now2 + 21600 || !Array.isArray(value.teams) || value.teams.length < 1 || value.teams.length > 8) throw new HttpError2(400, "invalid_voice_match");
    const teams = value.teams.map((team) => {
      if (!team || !identifier(team.team_id) || !Array.isArray(team.player_ids) || team.player_ids.length < 1 || team.player_ids.length > 25 || team.player_ids.some((id2) => typeof id2 !== "string" || id2.length > 64 || !id2.length)) {
        throw new HttpError2(400, "invalid_voice_team");
      }
      return { team_id: team.team_id, player_ids: [...team.player_ids].sort() };
    }).sort((a, b) => a.team_id.localeCompare(b.team_id));
    const players = teams.flatMap((team) => team.player_ids);
    if (players.length > 100 || new Set(players).size !== players.length || new Set(teams.map((t) => t.team_id)).size !== teams.length) {
      throw new HttpError2(400, "duplicate_or_excess_voice_players");
    }
    const previous = await db.prepare("SELECT * FROM voice_matches WHERE id = ?").bind(value.match_id).first();
    if (previous) {
      const rooms2 = await db.prepare("SELECT team_id, roster FROM voice_rooms WHERE match_id = ? ORDER BY team_id").bind(value.match_id).all();
      const sameRoster = JSON.stringify(rooms2.results.map((r) => ({ team_id: r.team_id, player_ids: JSON.parse(r.roster) }))) === JSON.stringify(teams);
      if (previous.status === "active" && previous.expires_at > now2 && previous.expires_at === value.expires_at && sameRoster) {
        return json2(await matchResult(db, value.match_id));
      }
      throw new HttpError2(409, "voice_match_conflict", { "Retry-After": "3" });
    }
    const users = await db.prepare(`SELECT id, username, discord_id FROM users
      WHERE discord_id IS NOT NULL AND banned = 0 AND id IN (${players.map(() => "?").join(",")})`).bind(...players).all();
    if (users.results.length !== players.length) throw new HttpError2(409, "players_must_link_discord");
    const byId = new Map(users.results.map((user) => [user.id, user]));
    const statements = [db.prepare("INSERT INTO voice_matches (id, status, expires_at, created_at) VALUES (?, 'creating', ?, ?)").bind(value.match_id, value.expires_at, now2)];
    const rooms = teams.map((team) => ({ ...team, id: crypto.randomUUID() }));
    for (const room of rooms) {
      statements.push(db.prepare("INSERT INTO voice_rooms (id, match_id, team_id, roster) VALUES (?, ?, ?, ?)").bind(room.id, value.match_id, room.team_id, JSON.stringify(room.player_ids)));
      for (const userId of room.player_ids) statements.push(db.prepare(`INSERT INTO voice_members (user_id, room_id)
        SELECT ?, ? WHERE EXISTS (SELECT 1 FROM users WHERE id = ? AND discord_id = ? AND banned = 0)`).bind(userId, room.id, userId, byId.get(userId).discord_id));
    }
    try {
      await db.batch(statements);
    } catch (error) {
      if (/UNIQUE constraint failed/.test(String(error))) throw new HttpError2(409, "players_already_in_voice_match");
      if (/FOREIGN KEY constraint failed/.test(String(error))) throw new HttpError2(409, "players_must_link_discord");
      throw error;
    }
    const createdLobbies = [];
    try {
      const assigned = await db.prepare(`SELECT COUNT(*) AS n FROM voice_members v JOIN voice_rooms r ON r.id = v.room_id
        WHERE r.match_id = ?`).bind(value.match_id).first();
      if (assigned.n !== players.length) throw new HttpError2(409, "players_must_link_discord");
      for (const room of rooms) {
        const lobby = await remote(env, "/lobbies", botOptions(env, "POST", {
          metadata: { match_id: value.match_id, team_id: room.team_id },
          idle_timeout_seconds: Math.max(5, value.expires_at - now2),
          members: room.player_ids.map((id2) => ({ id: byId.get(id2).discord_id, additional_name: byId.get(id2).username }))
        }));
        if (!snowflake(lobby.id)) throw new HttpError2(503, "discord_invalid_response");
        createdLobbies.push(lobby.id);
        const saved = await db.prepare("UPDATE voice_rooms SET lobby_id = ? WHERE id = ?").bind(lobby.id, room.id).run();
        if (saved.meta.changes !== 1) throw new HttpError2(409, "voice_match_cancelled");
      }
      const activated = await db.prepare("UPDATE voice_matches SET status = 'active' WHERE id = ? AND status = 'creating'").bind(value.match_id).run();
      if (activated.meta.changes !== 1) throw new HttpError2(409, "voice_match_cancelled");
    } catch (error) {
      await Promise.allSettled(createdLobbies.map((id2) => remote(env, `/lobbies/${id2}`, botOptions(env, "DELETE"), { missingOk: true })));
      try {
        await endMatch(env, db, value.match_id);
      } catch {
      }
      throw error;
    }
    return json2(await matchResult(db, value.match_id), 201);
  }
  return {
    link: linkUser,
    oauth,
    desktopRedirect,
    configured: configured2,
    async handle(request2, env, db, key) {
      const path = new URL(request2.url).pathname;
      const method = request2.method;
      const routes = {
        "/discord/config": "GET",
        "/discord/ready": "GET",
        "/discord/status": "GET",
        "/discord/exchange": "POST",
        "/discord/refresh": "POST",
        "/discord/unlink": "POST",
        "/voice/session": "GET",
        "/internal/voice/matches": "POST"
      };
      const deletion = /^\/internal\/voice\/matches\/([a-zA-Z0-9_-]{1,64})$/.exec(path);
      const expectedMethod = deletion ? "DELETE" : routes[path];
      if (!expectedMethod) throw new HttpError2(404, "not_found");
      if (method !== expectedMethod) throw new HttpError2(405, "method_not_allowed", { Allow: expectedMethod });
      if (path === "/discord/config" || path === "/discord/ready") {
        const checks = {
          application: snowflake(env.DISCORD_CLIENT_ID),
          client_secret: Boolean(env.DISCORD_CLIENT_SECRET?.length >= 16),
          bot_token: Boolean(env.DISCORD_BOT_TOKEN?.length >= 16),
          database: false
        };
        try {
          await db.batch([
            db.prepare("SELECT id, discord_id, discord_username FROM users LIMIT 0"),
            db.prepare("SELECT id, status, expires_at FROM voice_matches LIMIT 0"),
            db.prepare("SELECT id, match_id, team_id, lobby_id, roster FROM voice_rooms LIMIT 0"),
            db.prepare("SELECT user_id, room_id FROM voice_members LIMIT 0")
          ]);
          checks.database = true;
        } catch {
        }
        const ready = Object.values(checks).every(Boolean);
        if (path === "/discord/ready") return json2({ ready, checks }, ready ? 200 : 503);
        return json2({ enabled: ready, application_id: checks.application ? env.DISCORD_CLIENT_ID : null });
      }
      configured2(env, path.startsWith("/internal/voice/"));
      if (path.startsWith("/internal/voice/")) {
        await coordinator3(request2, env, key);
        if (deletion) {
          await endMatch(env, db, deletion[1]);
          return json2({ success: true });
        }
        return createMatch(env, db, await body2(request2));
      }
      const auth = await authenticate2(bearer2(request2), db, key);
      if (path === "/voice/session") {
        const row = await db.prepare(`SELECT r.lobby_id, r.team_id, m.id AS match_id, m.expires_at FROM voice_members v
          JOIN voice_rooms r ON r.id = v.room_id JOIN voice_matches m ON m.id = r.match_id
          JOIN users d ON d.id = v.user_id AND d.discord_id IS NOT NULL AND d.banned = 0
          WHERE v.user_id = ? AND m.status = 'active' AND m.expires_at > ?`).bind(auth.user.id, Math.floor(Date.now() / 1e3)).first();
        return json2(row ? { assigned: true, ...row } : { assigned: false });
      }
      const link = await db.prepare("SELECT discord_id FROM users WHERE id = ? AND discord_id IS NOT NULL").bind(auth.user.id).first();
      if (path === "/discord/status") return json2({ linked: Boolean(link), discord_id: link?.discord_id ?? null });
      await rateLimit2(db, key, "discord-account", auth.user.id, 20);
      if (path === "/discord/unlink") {
        if (env.AUTH_MODE !== "legacy") throw new HttpError2(409, "discord_is_sign_in_identity");
        const removed = await db.prepare(`UPDATE users SET discord_id = NULL, discord_username = NULL WHERE id = ?
          AND NOT EXISTS (SELECT 1 FROM voice_members WHERE user_id = ?) RETURNING id`).bind(auth.user.id, auth.user.id).first();
        if (link && !removed) throw new HttpError2(409, "leave_match_before_unlinking");
        return json2({ success: true });
      }
      const value = await body2(request2);
      let grant;
      if (path === "/discord/exchange") {
        if (typeof value.code !== "string" || !value.code.length || value.code.length > 2048 || typeof value.code_verifier !== "string" || !/^[A-Za-z0-9._~-]{43,128}$/.test(value.code_verifier) || !desktopRedirect(value.redirect_uri)) {
          throw new HttpError2(400, "invalid_discord_authorization");
        }
        grant = { grant_type: "authorization_code", code: value.code, code_verifier: value.code_verifier, redirect_uri: value.redirect_uri };
      } else {
        if (!link) throw new HttpError2(409, "discord_link_required");
        if (typeof value.refresh_token !== "string" || !value.refresh_token.length || value.refresh_token.length > 2048) {
          throw new HttpError2(400, "invalid_discord_refresh_token");
        }
        grant = { grant_type: "refresh_token", refresh_token: value.refresh_token };
      }
      const { tokens, discordId, discordUser } = await oauth(env, grant);
      if (link && link.discord_id !== discordId) throw new HttpError2(409, "different_discord_account_linked");
      await linkUser(db, auth.user.id, discordUser);
      const saved = await db.prepare("SELECT discord_id FROM users WHERE id = ?").bind(auth.user.id).first();
      if (saved?.discord_id !== discordId) throw new HttpError2(409, "different_discord_account_linked");
      return json2({
        discord_id: discordId,
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        expires_in: tokens.expires_in,
        token_type: "Bearer"
      });
    },
    async cleanup(env) {
      if (!env.DISCORD_BOT_TOKEN) return;
      const now2 = Math.floor(Date.now() / 1e3);
      const db = env.DB.withSession("first-primary");
      const expired = await db.prepare(`SELECT id FROM voice_matches WHERE expires_at <= ? OR status = 'deleting'
        OR (status = 'creating' AND created_at < ?) ORDER BY created_at LIMIT 10`).bind(now2, now2 - 180).all();
      const results = await Promise.allSettled(expired.results.map((row) => endMatch(env, db, row.id)));
      if (results.some((result) => result.status === "rejected")) console.error("Discord voice cleanup pending; will retry");
    }
  };
}

// src/providers.js
var API2 = "https://discord.com/api/v10";
async function request(env, url, options) {
  let response;
  try {
    const req = new Request(url, { ...options, redirect: "manual", signal: AbortSignal.timeout(1e4) });
    response = env.PROVIDER_HTTP ? await env.PROVIDER_HTTP.fetch(req) : await fetch(req);
  } catch {
    throw new Error("provider_unavailable");
  }
  if (!response.ok) throw new Error(response.status === 429 ? "provider_rate_limited" : "provider_request_failed");
  return response;
}
function buildDiscordAuthorizeUrl(env, redirectUri, state, challenge) {
  const params = new URLSearchParams({
    client_id: env.DISCORD_CLIENT_ID,
    redirect_uri: redirectUri,
    response_type: "code",
    scope: "identify sdk.social_layer",
    state,
    code_challenge: challenge,
    code_challenge_method: "S256"
  });
  return `https://discord.com/oauth2/authorize?${params}`;
}
async function exchangeDiscordCode(env, code, redirectUri, verifier) {
  const response = await request(env, `${API2}/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: env.DISCORD_CLIENT_ID,
      client_secret: env.DISCORD_CLIENT_SECRET,
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUri,
      code_verifier: verifier
    }).toString()
  });
  return response.json();
}
async function getDiscordUser(accessToken2, env) {
  return (await request(env, `${API2}/users/@me`, { headers: { Authorization: `Bearer ${accessToken2}` } })).json();
}
async function sendVerificationEmail(env, to, code) {
  if (!env.RESEND_API_KEY) throw new Error("email_not_configured");
  await request(env, "https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: env.EMAIL_FROM || "noreply@ancientnest.net",
      to,
      subject: "Ancient Nest \u2014 Verify your email",
      html: `<p>Your Ancient Nest verification code is <strong>${code}</strong>.</p><p>It expires in 10 minutes.</p>`
    })
  });
  return true;
}
async function sendVerificationSMS(env, to, code) {
  if (!env.TWILIO_ACCOUNT_SID || !env.TWILIO_AUTH_TOKEN || !env.TWILIO_FROM) throw new Error("sms_not_configured");
  if (!/^AC[0-9a-f]{32}$/i.test(env.TWILIO_ACCOUNT_SID)) throw new Error("sms_not_configured");
  const auth = btoa(`${env.TWILIO_ACCOUNT_SID}:${env.TWILIO_AUTH_TOKEN}`);
  await request(env, `https://api.twilio.com/2010-04-01/Accounts/${env.TWILIO_ACCOUNT_SID}/Messages.json`, {
    method: "POST",
    headers: { Authorization: `Basic ${auth}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      From: env.TWILIO_FROM,
      To: to,
      Body: `Ancient Nest: your verification code is ${code}. It expires in 10 minutes.`
    }).toString()
  });
  return true;
}

// src/account-extras.js
var enc = new TextEncoder();
var now = () => Math.floor(Date.now() / 1e3);
var hex3 = (bytes2) => Array.from(new Uint8Array(bytes2), (b) => b.toString(16).padStart(2, "0")).join("");
var random = () => crypto.getRandomValues(new Uint8Array(32));
var base64url = (bytes2) => btoa(String.fromCharCode(...bytes2)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
function verificationStatus(user) {
  const email = Boolean(user.email_verified);
  const phone = Boolean(user.phone_verified);
  const discord2 = Boolean(user.discord_id);
  return { email, phone, discord: discord2, fully_verified: user.auth_provider === "discord" ? discord2 : email && phone && discord2 };
}
function accountExtras({
  HttpError: HttpError2,
  json: json2,
  body: body2,
  authenticate: authenticate2,
  bearer: bearer2,
  rateLimit: rateLimit2,
  passwordRecord: passwordRecord2,
  verifyPassword: verifyPassword2,
  tokenHash: tokenHash2,
  discord: discord2
}) {
  async function digest(key, text) {
    const imported = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    return hex3(await crypto.subtle.sign("HMAC", imported, enc.encode(text)));
  }
  function registration(value) {
    const email = typeof value.email === "string" ? value.email.trim().toLowerCase() : "";
    if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError2(400, "valid_email_required");
    let phone = typeof value.phone === "string" ? value.phone.replace(/[\s()-]/g, "") : "";
    if (!phone.startsWith("+")) phone = "+" + phone;
    if (!/^\+[1-9]\d{6,14}$/.test(phone)) throw new HttpError2(400, "valid_phone_required");
    return { email, phone };
  }
  async function sendCode(env, db, key, user, type, ip) {
    await rateLimit2(db, key, "verification-send-ip", ip, 10);
    await rateLimit2(db, key, `verification-send-${type}`, user.id, 3);
    const destination = type === "email" ? user.email : user.phone;
    if (!destination) throw new HttpError2(400, "verification_destination_missing");
    let code = "";
    while (code.length < 6) for (const value of crypto.getRandomValues(new Uint8Array(12))) {
      if (value < 250 && code.length < 6) code += String(value % 10);
    }
    const id2 = crypto.randomUUID();
    const codeHash = "hmac:" + await digest(key, `code:${user.id}:${type}:${id2}:${code}`);
    await db.batch([
      db.prepare("UPDATE verification_codes SET used = 1 WHERE user_id = ? AND type = ? AND used = 0").bind(user.id, type),
      db.prepare(`INSERT INTO verification_codes (id, user_id, type, code, destination, expires_at)
        VALUES (?, ?, ?, ?, ?, ?)`).bind(id2, user.id, type, codeHash, destination, now() + 600)
    ]);
    try {
      if (type === "email") await sendVerificationEmail(env, destination, code);
      else await sendVerificationSMS(env, destination, code);
    } catch (error) {
      throw new HttpError2(503, error.message);
    }
    return { success: true, type, destination: type === "phone" ? destination.slice(0, -4) + "****" : destination };
  }
  async function account(db, id2) {
    const user = await db.prepare("SELECT * FROM users WHERE id = ?").bind(id2).first();
    if (!user) throw new HttpError2(404, "account_not_found");
    return {
      id: user.id,
      username: user.username,
      email: user.auth_provider === "discord" ? null : user.email,
      auth_provider: user.auth_provider,
      email_verified: Boolean(user.email_verified),
      phone: user.phone ? user.phone.slice(0, -4) + "****" : null,
      phone_verified: Boolean(user.phone_verified),
      discord_id: user.discord_id,
      discord_username: user.discord_username,
      discord_linked: Boolean(user.discord_id),
      created_at: user.created_at,
      last_login: user.last_login,
      verification: verificationStatus(user)
    };
  }
  function callbackUri(env) {
    try {
      const url = new URL(env.PUBLIC_URL);
      if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash || url.pathname !== "/") throw new Error();
      return new URL("/auth/discord/callback", url).href;
    } catch {
      throw new HttpError2(503, "public_url_not_configured");
    }
  }
  return {
    registration,
    account,
    async afterRegister(env, db, key, user, ip) {
      const errors = [];
      for (const type of ["email", "phone"]) {
        try {
          await sendCode(env, db, key, user, type, ip);
        } catch (error) {
          errors.push({ [type]: error instanceof HttpError2 ? error.message : "provider_unavailable" });
        }
      }
      return errors;
    },
    async audit(db, key, username, ip, success) {
      await db.prepare("INSERT INTO login_attempts (username, ip, success) VALUES (?, ?, ?)").bind(username, await digest(key, `audit-ip:${ip}`), success ? 1 : 0).run();
    },
    async handle(request2, env, db, key) {
      const url = new URL(request2.url);
      const path = url.pathname;
      const methods = {
        "/verify/email": "POST",
        "/verify/phone": "POST",
        "/verify/email/resend": "POST",
        "/verify/phone/resend": "POST",
        "/account/password": "POST",
        "/auth/discord": "GET",
        "/auth/discord/callback": "GET"
      };
      if (!methods[path]) throw new HttpError2(404, "not_found");
      if (request2.method !== methods[path]) throw new HttpError2(405, "method_not_allowed", { Allow: methods[path] });
      if (path === "/auth/discord/callback") {
        const state = url.searchParams.get("state") ?? "";
        const code = url.searchParams.get("code") ?? "";
        if (!/^[a-f0-9]{64}$/.test(state) || !code || code.length > 2048) throw new HttpError2(400, "invalid_discord_callback");
        const saved = await db.prepare(`DELETE FROM oauth_states WHERE state_hash = ? AND expires_at > ?
          AND EXISTS (SELECT 1 FROM sessions s JOIN users u ON u.id = s.user_id
            WHERE s.token_id = oauth_states.token_id AND s.user_id = oauth_states.user_id
            AND s.revoked = 0 AND s.expires_at > ? AND u.banned = 0 AND s.auth_version = u.auth_version)
          RETURNING user_id, code_verifier`).bind(await tokenHash2(state), now(), now()).first();
        if (!saved) throw new HttpError2(400, "invalid_or_expired_oauth_state");
        let user2;
        try {
          const tokens = await exchangeDiscordCode(env, code, callbackUri(env), saved.code_verifier);
          if (!(tokens.scope ?? "").split(/\s+/).includes("sdk.social_layer")) throw new HttpError2(403, "discord_voice_scope_required");
          user2 = await getDiscordUser(tokens.access_token, env);
        } catch (error) {
          if (error instanceof HttpError2) throw error;
          throw new HttpError2(503, "discord_linking_failed");
        }
        await discord2.link(db, saved.user_id, user2);
        return new Response(
          '<!doctype html><meta charset="utf-8"><title>Ancient Nest</title><p>Discord linked successfully. You can close this window and return to the game.</p>',
          { headers: { "Content-Type": "text/html; charset=utf-8", "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'" } }
        );
      }
      const auth = await authenticate2(bearer2(request2), db, key);
      if (path === "/auth/discord") {
        if (!env.DISCORD_CLIENT_ID || !env.DISCORD_CLIENT_SECRET) throw new HttpError2(503, "discord_not_configured");
        await rateLimit2(db, key, "discord-account", auth.user.id, 20);
        const redirect = callbackUri(env);
        const state = hex3(random());
        const verifier = base64url(random());
        const challenge = base64url(new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(verifier))));
        await db.prepare(`INSERT INTO oauth_states (state_hash, user_id, token_id, code_verifier, expires_at)
          VALUES (?, ?, ?, ?, ?)`).bind(await tokenHash2(state), auth.user.id, auth.sessionId, verifier, now() + 600).run();
        return json2({ url: buildDiscordAuthorizeUrl(env, redirect, state, challenge), redirect_uri: redirect });
      }
      if (path === "/account/password") {
        await rateLimit2(db, key, "password-change", auth.user.id, 5);
        const value2 = await body2(request2);
        if (typeof value2.current_password !== "string" || value2.current_password.length > 128 || typeof value2.new_password !== "string" || value2.new_password.length < 8 || value2.new_password.length > 128) {
          throw new HttpError2(400, "password_must_be_8_to_128_characters");
        }
        const user2 = await db.prepare("SELECT * FROM users WHERE id = ?").bind(auth.user.id).first();
        if (!await verifyPassword2(value2.current_password, user2.password_hash, user2.password_salt)) throw new HttpError2(401, "invalid_credentials");
        const updated = await passwordRecord2(value2.new_password);
        const results2 = await db.batch([
          db.prepare(`UPDATE users SET password_hash = ?, password_salt = ?, auth_version = auth_version + 1
            WHERE id = ? AND auth_version = ?`).bind(updated.hash, updated.salt, user2.id, user2.auth_version),
          db.prepare("UPDATE sessions SET revoked = 1 WHERE user_id = ? AND auth_version <= ?").bind(user2.id, user2.auth_version)
        ]);
        if (results2[0].meta.changes !== 1) throw new HttpError2(409, "account_changed_retry");
        return json2({ success: true });
      }
      const type = path.includes("/email") ? "email" : "phone";
      const user = await db.prepare("SELECT * FROM users WHERE id = ?").bind(auth.user.id).first();
      if (user[`${type}_verified`]) throw new HttpError2(400, `${type}_already_verified`);
      if (path.endsWith("/resend")) {
        return json2(await sendCode(env, db, key, user, type, request2.headers.get("CF-Connecting-IP") ?? "local"));
      }
      await rateLimit2(db, key, `verify-${type}`, user.id, 20);
      const value = await body2(request2);
      if (typeof value.code !== "string" || !/^\d{6}$/.test(value.code)) throw new HttpError2(400, "six_digit_code_required");
      const record = await db.prepare(`SELECT id FROM verification_codes WHERE user_id = ? AND type = ?
        AND used = 0 AND expires_at > ? ORDER BY created_at DESC, rowid DESC LIMIT 1`).bind(user.id, type, now()).first();
      if (!record) throw new HttpError2(400, "invalid_or_expired_code");
      const attempted = await db.prepare(`UPDATE verification_codes SET attempts = attempts + 1
        WHERE id = ? AND used = 0 AND expires_at > ? AND attempts < 5 RETURNING code, destination`).bind(record.id, now()).first();
      if (!attempted) throw new HttpError2(429, "verification_attempts_exhausted");
      const expected = attempted.code.startsWith("hmac:") ? "hmac:" + await digest(key, `code:${user.id}:${type}:${record.id}:${value.code}`) : value.code;
      if (expected !== attempted.code) throw new HttpError2(400, "invalid_or_expired_code");
      const results = await db.batch([
        // type is a fixed email/phone enum, never user-supplied SQL.
        db.prepare(`UPDATE users SET ${type}_verified = 1 WHERE id = ? AND ${type} = ?
          AND EXISTS (SELECT 1 FROM verification_codes WHERE id = ? AND used = 0 AND expires_at > ?)`).bind(user.id, attempted.destination, record.id, now()),
        db.prepare("UPDATE verification_codes SET used = 1 WHERE id = ? AND used = 0").bind(record.id)
      ]);
      if (results[0].meta.changes !== 1 || results[1].meta.changes !== 1) throw new HttpError2(400, "invalid_or_expired_code");
      const verified = await db.prepare("SELECT * FROM users WHERE id = ?").bind(user.id).first();
      return json2({ success: true, verification: verificationStatus(verified) });
    }
  };
}

// src/index.js
var VERSION = "10.5-discord";
var ISSUER = "ancient-nest-accounts";
var AUDIENCE = "ancient-nest";
var WINDOW = 900;
var DEVICE_TTL = 90 * 86400;
var REFRESH_RETRY_GRACE = 60;
var encoder4 = new TextEncoder();
var HttpError = class extends Error {
  constructor(status, code, headers = {}) {
    super(code);
    this.status = status;
    this.headers = headers;
  }
};
function json(value, status = 200, headers = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...headers }
  });
}
function configured(value) {
  return typeof value === "string" && encoder4.encode(value).length >= 32 && !value.startsWith("replace-with");
}
function settings(env) {
  const ttl = Number(env.TOKEN_TTL_SECONDS ?? 3600);
  if (!configured(env.JWT_SECRET) || !configured(env.COORDINATOR_API_KEY) || !Number.isSafeInteger(ttl) || ttl < 300 || ttl > 86400 || !env.DB) {
    throw new HttpError(503, "service_not_configured");
  }
  return { key: encoder4.encode(env.JWT_SECRET), ttl };
}
async function body(request2) {
  if (!/^application\/json(?:\s*;|$)/i.test(request2.headers.get("Content-Type") ?? "")) {
    throw new HttpError(415, "json_required");
  }
  if (Number(request2.headers.get("Content-Length")) > 4096) throw new HttpError(413, "body_too_large");
  const reader = request2.body?.getReader();
  if (!reader) throw new HttpError(400, "invalid_json");
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 4096) {
        await reader.cancel();
        throw new HttpError(413, "body_too_large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  try {
    const buffer = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
      buffer.set(chunk, offset);
      offset += chunk.length;
    }
    const value = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(buffer));
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error();
    return value;
  } catch {
    throw new HttpError(400, "invalid_json");
  }
}
function credentials(value) {
  if (typeof value.username !== "string" || !/^[a-zA-Z0-9_-]{3,24}$/.test(value.username)) {
    throw new HttpError(400, "username_must_be_3_to_24_ascii_letters_digits_or_underscores");
  }
  if (typeof value.password !== "string" || value.password.length < 8 || value.password.length > 128 || encoder4.encode(value.password).length > 512) {
    throw new HttpError(400, "password_must_be_8_to_128_characters");
  }
  return { username: value.username, usernameKey: value.username.toLowerCase(), password: value.password };
}
async function macKey(key) {
  return crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}
async function coordinator2(request2, env, key) {
  const provided = request2.headers.get("X-Coordinator-Key") ?? "";
  const signingKey = await macKey(key);
  const expected = await crypto.subtle.sign("HMAC", signingKey, encoder4.encode(env.COORDINATOR_API_KEY));
  if (!await crypto.subtle.verify("HMAC", signingKey, expected, encoder4.encode(provided))) {
    throw new HttpError(401, "invalid_coordinator_key");
  }
}
async function rateLimit(db, key, scope, identity2, limit) {
  const now2 = Math.floor(Date.now() / 1e3);
  const bucket = Math.floor(now2 / WINDOW);
  const digest = new Uint8Array(await crypto.subtle.sign(
    "HMAC",
    await macKey(key),
    encoder4.encode(`rate:${scope}:${identity2}:${bucket}`)
  ));
  const id2 = Array.from(digest, (b) => b.toString(16).padStart(2, "0")).join("");
  const expires = (bucket + 1) * WINDOW;
  const row = await db.prepare(`INSERT INTO rate_limits (key, attempts, expires_at) VALUES (?, 1, ?)
    ON CONFLICT(key) DO UPDATE SET attempts = MIN(attempts + 1, 1000000) RETURNING attempts`).bind(id2, expires).first();
  if (row.attempts > limit) throw new HttpError(429, "rate_limited", { "Retry-After": String(expires - now2) });
}
function publicUser(user) {
  return { id: user.id, username: user.username, created_at: user.created_at };
}
async function accessToken(user, key, ttl, id2, sessionExpires) {
  const now2 = Math.floor(Date.now() / 1e3);
  const expires = Math.min(now2 + ttl, sessionExpires);
  const token = await new SignJWT({ username: user.username }).setProtectedHeader({ alg: "HS256", typ: "JWT" }).setIssuer(ISSUER).setAudience(AUDIENCE).setSubject(user.id).setJti(id2).setIssuedAt(now2).setExpirationTime(expires).sign(key);
  return { expires, token };
}
function hex4(buffer) {
  return Array.from(new Uint8Array(buffer), (b) => b.toString(16).padStart(2, "0")).join("");
}
async function tokenHash(token) {
  return hex4(await crypto.subtle.digest("SHA-256", encoder4.encode(token)));
}
async function nextRefreshToken(token, key) {
  return hex4(await crypto.subtle.sign("HMAC", await macKey(key), encoder4.encode(`refresh:${token}`)));
}
function refreshToken(value) {
  if (typeof value !== "string" || !/^[a-f0-9]{64}$/.test(value)) {
    throw new HttpError(401, "invalid_refresh_token");
  }
  return value;
}
async function newSession(user, key, ttl) {
  const now2 = Math.floor(Date.now() / 1e3);
  const id2 = crypto.randomUUID();
  const sessionExpires = now2 + DEVICE_TTL;
  const refresh = hex4(crypto.getRandomValues(new Uint8Array(32)));
  const refreshHash = await tokenHash(refresh);
  return {
    id: id2,
    now: now2,
    sessionExpires,
    refresh,
    refreshHash,
    ...await accessToken(user, key, ttl, id2, sessionExpires)
  };
}
function sessionResponse(user, session) {
  return {
    success: true,
    user: publicUser(user),
    token: session.token,
    expires_at: session.expires,
    verification: verificationStatus(user),
    refresh_token: session.refresh,
    refresh_expires_at: session.sessionExpires
  };
}
function sessionInsert(db, user, session) {
  return db.prepare(`INSERT INTO sessions (token_id, user_id, expires_at, issued_at, refresh_hash, auth_version)
    SELECT ?, ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM users WHERE id = ? AND auth_version = ? AND banned = 0)`).bind(
    session.id,
    user.id,
    session.sessionExpires,
    session.now,
    session.refreshHash,
    user.auth_version ?? 0,
    user.id,
    user.auth_version ?? 0
  );
}
async function findDevice(db, hash2, now2) {
  return db.prepare(`SELECT s.token_id AS session_id, s.expires_at AS session_expires,
    s.refresh_hash, s.previous_refresh_hash, s.previous_refresh_until, u.*
    FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.expires_at > ? AND s.revoked = 0
    AND u.banned = 0 AND s.auth_version = u.auth_version AND
    (s.refresh_hash = ? OR (s.previous_refresh_hash = ? AND s.previous_refresh_until >= ?))`).bind(now2, hash2, hash2, now2).first();
}
async function refreshSession(db, key, ttl, refresh) {
  const now2 = Math.floor(Date.now() / 1e3);
  const hash2 = await tokenHash(refresh);
  const device = await findDevice(db, hash2, now2);
  if (!device) throw new HttpError(401, "invalid_refresh_token");
  const next = await nextRefreshToken(refresh, key);
  const nextHash = await tokenHash(next);
  if (device.refresh_hash === hash2) {
    const sessionExpires = now2 + DEVICE_TTL;
    const access = await accessToken(device, key, ttl, device.session_id, sessionExpires);
    const updated = await db.prepare(`UPDATE sessions SET refresh_hash = ?, previous_refresh_hash = ?,
      previous_refresh_until = ?, expires_at = ? WHERE token_id = ? AND refresh_hash = ? AND expires_at > ? AND revoked = 0
      RETURNING token_id`).bind(
      nextHash,
      hash2,
      now2 + REFRESH_RETRY_GRACE,
      sessionExpires,
      device.session_id,
      hash2,
      now2
    ).first();
    if (updated) return sessionResponse(device, { ...access, refresh: next, sessionExpires });
  }
  const current = await findDevice(db, hash2, now2);
  if (!current || current.previous_refresh_hash !== hash2 || current.refresh_hash !== nextHash) {
    throw new HttpError(401, "invalid_refresh_token");
  }
  return sessionResponse(current, {
    ...await accessToken(current, key, ttl, current.session_id, current.session_expires),
    refresh: next,
    sessionExpires: current.session_expires
  });
}
function bearer(request2) {
  const match = /^Bearer ([A-Za-z0-9_.-]+)$/i.exec(request2.headers.get("Authorization") ?? "");
  if (!match || match[1].length > 2048) throw new HttpError(401, "invalid_token");
  return match[1];
}
async function authenticate(token, db, key, expectedAudience = AUDIENCE) {
  let payload;
  try {
    if (typeof token !== "string" || token.length > 2048) throw new Error();
    ({ payload } = await jwtVerify(token, key, {
      algorithms: ["HS256"],
      typ: "JWT",
      requiredClaims: ["sub", "jti", "iat", "exp"],
      maxTokenAge: "24h"
    }));
    if (typeof payload.sub !== "string" || typeof payload.jti !== "string" || !Number.isSafeInteger(payload.iat) || !Number.isSafeInteger(payload.exp) || payload.exp <= payload.iat || payload.exp - payload.iat > 86400) throw new Error();
    if (expectedAudience !== AUDIENCE && (payload.iss !== ISSUER || payload.aud !== expectedAudience)) throw new Error();
    if ((payload.iss !== void 0 || payload.aud !== void 0) && (payload.iss !== ISSUER || payload.aud !== expectedAudience)) throw new Error();
  } catch {
    throw new HttpError(401, "invalid_token");
  }
  const user = await db.prepare(`SELECT u.* FROM sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.token_id = ? AND s.user_id = ? AND s.expires_at > ? AND s.expires_at >= ?
    AND s.revoked = 0 AND u.banned = 0 AND s.auth_version = u.auth_version`).bind(payload.jti, payload.sub, Math.floor(Date.now() / 1e3), payload.exp).first();
  if (!user) throw new HttpError(401, "invalid_token");
  return { claims: payload, user: publicUser(user), record: user, sessionId: payload.jti, expires: payload.exp };
}
async function route(request2, env) {
  const path = new URL(request2.url).pathname;
  const method = request2.method;
  const discordOnly = env.AUTH_MODE !== "legacy";
  if (discordOnly && (["/register", "/login", "/account/password", "/setup-test", "/setup-test.js", "/setup-test.css"].includes(path) || path.startsWith("/verify/") || path.startsWith("/auth/discord") && !["/auth/discord/config", "/auth/discord/exchange"].includes(path))) {
    throw new HttpError(410, "use_discord_sign_in");
  }
  if (path === "/auth/discord/config" || path === "/auth/discord/exchange" || path === "/profile/username") {
    const { key: key2, ttl: ttl2 } = settings(env);
    return discordLogin(request2, env, env.DB.withSession("first-primary"), key2, ttl2);
  }
  const liveTest = liveTestRoute(path);
  if (liveTest) {
    if (method !== "GET") throw new HttpError(405, "method_not_allowed", { Allow: "GET" });
    return liveTest;
  }
  if (path === "/signup/config" && method === "GET") return json({ auth_provider: discordOnly ? "discord" : "legacy", email_required: !discordOnly, phone_required: !discordOnly });
  if (["/api/game/profile", "/api/game/service-card"].includes(path) || path.startsWith("/api/internal/")) {
    if (method !== "POST") throw new HttpError(405, "method_not_allowed");
    const { key: key2 } = settings(env);
    const db2 = env.DB.withSession("first-primary");
    const data = await body(request2);
    const statsEnv = { ACCOUNTS_DB: db2, COORDINATOR_API_KEY: env.COORDINATOR_API_KEY };
    try {
      if (path === "/api/game/profile" || path === "/api/game/service-card") {
        const auth2 = await authenticate(data.assertion, db2, key2, "ancient-nest-matchmaking");
        if (auth2.claims.kind !== "game-assertion" || auth2.claims.key_hash !== data.key_hash) throw new HttpError(401, "invalid_game_assertion");
        await rateLimit(db2, key2, "rank-profile", auth2.user.id, 120);
        return json(path === "/api/game/profile" ? await profile(statsEnv, auth2.user.id, data.playlist) : await publicServiceCard(statsEnv, data.account_id ?? auth2.user.id));
      }
      if (path === "/api/internal/players/ratings") return json(await internalRatings(request2, statsEnv, data));
      if (path === "/api/internal/reviews") return json(await reviewSummary(request2, statsEnv));
      if (path.startsWith("/api/internal/matches/")) return json(await coordinator(request2, statsEnv, data));
      throw new HttpError(404, "not_found");
    } catch (error) {
      if (error instanceof ServiceError) throw new HttpError(error.status, error.code);
      throw error;
    }
  }
  if (path === "/api/game/assertion" || path === "/api/game/verify") {
    const { key: key2 } = settings(env);
    return identity(request2, env, env.DB.withSession("first-primary"), key2);
  }
  if (path.startsWith("/discord/") || path === "/voice/session" || path.startsWith("/internal/voice/")) {
    const { key: key2 } = settings(env);
    return discord.handle(request2, env, env.DB.withSession("first-primary"), key2);
  }
  if (path === "/health" && method === "GET") return json({ status: "ok", version: VERSION });
  if (path.startsWith("/verify/") || path === "/account/password" || path.startsWith("/auth/discord")) {
    const { key: key2 } = settings(env);
    return extras.handle(request2, env, env.DB.withSession("first-primary"), key2);
  }
  if (path === "/ready" && method === "GET") {
    const checks = { secrets: false, database: false };
    try {
      settings(env);
      checks.secrets = true;
    } catch {
    }
    try {
      const db2 = env.DB.withSession("first-primary");
      await db2.batch([
        db2.prepare("SELECT id, username, password_hash, password_salt, email, phone, auth_version, auth_provider FROM users LIMIT 0"),
        db2.prepare(`SELECT token_id, user_id, expires_at, issued_at, refresh_hash, revoked, auth_version,
          previous_refresh_hash, previous_refresh_until FROM sessions LIMIT 0`),
        db2.prepare("SELECT id, attempts, code FROM verification_codes LIMIT 0"),
        db2.prepare("SELECT state_hash, user_id, token_id, code_verifier, expires_at FROM oauth_states LIMIT 0"),
        db2.prepare("SELECT key, attempts, expires_at FROM rate_limits LIMIT 0"),
        db2.prepare("SELECT account_id, playlist_id, rp FROM player_playlist_stats LIMIT 0")
      ]);
      checks.database = true;
    } catch {
    }
    const ready = Object.values(checks).every(Boolean);
    return json({ ready, version: VERSION, checks: {
      ...checks,
      jwt_secret: configured(env.JWT_SECRET),
      resend: Boolean(env.RESEND_API_KEY),
      twilio: Boolean(env.TWILIO_ACCOUNT_SID && env.TWILIO_AUTH_TOKEN && env.TWILIO_FROM),
      discord: Boolean(env.DISCORD_CLIENT_ID && env.DISCORD_CLIENT_SECRET && env.DISCORD_BOT_TOKEN)
    } }, ready ? 200 : 503);
  }
  const routes = {
    "/register": "POST",
    "/login": "POST",
    "/verify": "GET",
    "/account": "GET",
    "/logout": "POST",
    "/refresh": "POST",
    "/internal/verify": "POST"
  };
  if (!routes[path]) throw new HttpError(404, "not_found");
  if (routes[path] !== method) throw new HttpError(405, "method_not_allowed", { Allow: routes[path] });
  const { key, ttl } = settings(env);
  const db = env.DB.withSession("first-primary");
  if (path === "/register" || path === "/login") {
    await rateLimit(db, key, "auth-ip", request2.headers.get("CF-Connecting-IP") ?? "local", 30);
    const data = await body(request2);
    const { username, usernameKey, password } = credentials(data);
    await rateLimit(db, key, "auth-username", usernameKey, 10);
    if (path === "/register") {
      const registration = extras.registration(data);
      const user2 = { id: crypto.randomUUID(), username, created_at: Math.floor(Date.now() / 1e3), ...registration };
      const { hash: passwordHash, salt } = await passwordRecord(password);
      const existing = await db.prepare(`SELECT id FROM users WHERE username = ? OR email = ? COLLATE NOCASE
        OR phone IN (?, ?)`).bind(username, user2.email, user2.phone, user2.phone.slice(1)).first();
      if (existing) throw new HttpError(409, "account_already_registered");
      const session2 = await newSession(user2, key, ttl);
      try {
        await db.batch([
          db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email, phone, created_at, last_login)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)`).bind(user2.id, username, passwordHash, salt, user2.email, user2.phone, user2.created_at, user2.created_at),
          sessionInsert(db, user2, session2)
        ]);
      } catch (error) {
        if (/UNIQUE constraint failed: users\./.test(String(error))) {
          throw new HttpError(409, "account_already_registered");
        }
        throw error;
      }
      const sendErrors = await extras.afterRegister(env, db, key, user2, request2.headers.get("CF-Connecting-IP") ?? "local");
      return json({
        ...sessionResponse(user2, session2),
        needs: ["email", "phone", "discord"],
        ...sendErrors.length ? { send_errors: sendErrors } : {}
      }, 201);
    }
    const user = await db.prepare("SELECT * FROM users WHERE username = ?").bind(username).first();
    const valid = await verifyPassword(password, user?.password_hash ?? DUMMY_HASH, user?.password_salt);
    await extras.audit(db, key, username, request2.headers.get("CF-Connecting-IP") ?? "local", Boolean(user && valid && !user.banned));
    if (!user || !valid || user.banned) throw new HttpError(401, "invalid_credentials");
    if (!user.password_hash.startsWith("pbkdf2-sha256$")) {
      const upgraded = await passwordRecord(password);
      await db.prepare(`UPDATE users SET password_hash = ?, password_salt = ? WHERE id = ?
        AND password_hash = ? AND auth_version = ?`).bind(upgraded.hash, upgraded.salt, user.id, user.password_hash, user.auth_version).run();
    }
    const session = await newSession(user, key, ttl);
    const issued = await db.batch([
      sessionInsert(db, user, session),
      db.prepare("UPDATE users SET last_login = ? WHERE id = ? AND auth_version = ?").bind(session.now, user.id, user.auth_version)
    ]);
    if (issued[0].meta.changes !== 1) throw new HttpError(401, "invalid_credentials");
    return json(sessionResponse(user, session));
  }
  if (path === "/refresh" || path === "/logout" && !request2.headers.has("Authorization")) {
    await rateLimit(db, key, "device-ip", request2.headers.get("CF-Connecting-IP") ?? "local", 120);
    const refresh = refreshToken((await body(request2)).refresh_token);
    if (path === "/refresh") return json(await refreshSession(db, key, ttl, refresh));
    const device = await findDevice(db, await tokenHash(refresh), Math.floor(Date.now() / 1e3));
    if (!device) throw new HttpError(401, "invalid_refresh_token");
    await db.prepare("UPDATE sessions SET revoked = 1 WHERE token_id = ?").bind(device.session_id).run();
    return json({ success: true });
  }
  if (path === "/internal/verify") {
    await coordinator2(request2, env, key);
    const { token } = await body(request2);
    const auth2 = await authenticate(token, db, key);
    const status = verificationStatus(auth2.record);
    return json({ valid: true, user: {
      ...auth2.user,
      email_verified: status.email,
      phone_verified: status.phone,
      discord_linked: status.discord,
      fully_verified: status.fully_verified
    }, expires_at: auth2.expires });
  }
  const auth = await authenticate(bearer(request2), db, key);
  if (path === "/logout") {
    await db.prepare("UPDATE sessions SET revoked = 1 WHERE token_id = ?").bind(auth.sessionId).run();
    return json({ success: true });
  }
  if (path === "/account") return json(await extras.account(db, auth.user.id));
  const verification = verificationStatus(auth.record);
  return json({ valid: true, user: {
    ...auth.user,
    email_verified: verification.email,
    phone_verified: verification.phone,
    discord_linked: verification.discord,
    fully_verified: verification.fully_verified
  }, expires_at: auth.expires });
}
var discord = discordRoutes({ HttpError, json, body, authenticate, bearer, rateLimit, coordinator: coordinator2 });
var discordLogin = discordSignIn({ HttpError, json, body, authenticate, bearer, rateLimit, discord, newSession, sessionInsert, sessionResponse });
var identity = gameIdentity({ HttpError, json, body, bearer, authenticate, rateLimit });
var extras = accountExtras({ HttpError, json, body, authenticate, bearer, rateLimit, passwordRecord, verifyPassword, tokenHash, discord });
var index_default = {
  async fetch(request2, env) {
    const origin = request2.headers.get("Origin");
    const sameOrigin = origin === new URL(request2.url).origin;
    const allowed = (env.CORS_ORIGIN ?? env.ALLOWED_ORIGINS ?? "").split(",").map((value) => value.trim()).filter(Boolean);
    const headers = {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      Vary: "Origin",
      ...origin && (sameOrigin || allowed.includes(origin)) ? { "Access-Control-Allow-Origin": origin } : {}
    };
    let response;
    try {
      if (origin && !sameOrigin && !allowed.includes(origin)) throw new HttpError(403, "origin_not_allowed");
      if (request2.method === "OPTIONS") {
        const methods = ["GET", "POST"];
        const requestedHeaders = (request2.headers.get("Access-Control-Request-Headers") ?? "").toLowerCase().split(",").map((value) => value.trim()).filter(Boolean);
        if (!origin || !methods.includes(request2.headers.get("Access-Control-Request-Method")) || requestedHeaders.some((value) => !["content-type", "authorization", "x-coordinator-key"].includes(value))) {
          throw new HttpError(403, "preflight_not_allowed");
        }
        response = new Response(null, { status: 204, headers: {
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Coordinator-Key",
          "Access-Control-Max-Age": "600"
        } });
      } else {
        response = await route(request2, env);
      }
    } catch (error) {
      if (error instanceof HttpError) {
        response = json({ error: error.message }, error.status, {
          ...error.status === 401 ? { "WWW-Authenticate": "Bearer" } : {},
          ...error.headers
        });
      } else {
        console.error("Accounts request failed");
        response = json({ error: "internal_error" }, 500);
      }
    }
    for (const [name, value] of Object.entries(headers)) response.headers.set(name, value);
    return response;
  },
  async scheduled(_event, env, ctx) {
    const now2 = Math.floor(Date.now() / 1e3);
    ctx.waitUntil(env.DB.batch([
      env.DB.prepare("DELETE FROM sessions WHERE expires_at <= ?").bind(now2),
      env.DB.prepare("DELETE FROM rate_limits WHERE expires_at <= ?").bind(now2),
      env.DB.prepare("DELETE FROM verification_codes WHERE expires_at <= ?").bind(now2),
      env.DB.prepare("DELETE FROM oauth_states WHERE expires_at <= ?").bind(now2),
      env.DB.prepare("DELETE FROM login_attempts WHERE attempted_at <= ?").bind(now2 - 7 * 86400)
    ]));
    ctx.waitUntil(discord.cleanup(env));
  }
};
export {
  index_default as default
};
