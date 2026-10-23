const API = 'https://discord.com/api/v10';
function desktopRedirect(value) {
  if (typeof value !== 'string' || value.length > 128) return false;
  try {
    const url = new URL(value);
    return url.protocol === 'http:' && url.hostname === '127.0.0.1' && url.pathname === '/callback' &&
      !url.username && !url.password && !url.search && !url.hash;
  } catch { return false; }
}
const snowflake = value => typeof value === 'string' && /^[0-9]{17,20}$/.test(value);
const identifier = value => typeof value === 'string' && /^[a-zA-Z0-9_-]{1,64}$/.test(value);

// Common account authorization and request limits are supplied by the accounts Worker.
export function discordRoutes({ HttpError, json, body, authenticate, bearer, rateLimit, coordinator }) {
  function configured(env, bot = false) {
    if (!snowflake(env.DISCORD_CLIENT_ID) || typeof env.DISCORD_CLIENT_SECRET !== 'string' ||
        env.DISCORD_CLIENT_SECRET.length < 16 || (bot && (!env.DISCORD_BOT_TOKEN || env.DISCORD_BOT_TOKEN.length < 16))) {
      throw new HttpError(503, 'discord_not_configured');
    }
  }

  async function remote(env, path, options, { oauth = false, missingOk = false } = {}) {
    let response;
    try {
      // Optional service binding permits an isolated HTTP test double; the destination is fixed.
      const request = new Request(API + path, { ...options, redirect: 'manual', signal: AbortSignal.timeout(10000) });
      response = env.DISCORD_HTTP ? await env.DISCORD_HTTP.fetch(request) : await fetch(request);
    } catch {
      throw new HttpError(503, 'discord_unavailable');
    }
    if (missingOk && response.status === 404) return null;
    if (response.status === 429) {
      const seconds = Math.min(3600, Math.max(1, Number(response.headers.get('Retry-After')) || 5));
      throw new HttpError(503, 'discord_rate_limited', { 'Retry-After': String(Math.ceil(seconds)) });
    }
    if (!response.ok) {
      throw new HttpError(oauth && [400, 401].includes(response.status) ? 401 : 503,
        oauth && [400, 401].includes(response.status) ? 'discord_authorization_expired' : 'discord_unavailable');
    }
    if (response.status === 204) return null;
    try { return await response.json(); } catch { throw new HttpError(503, 'discord_invalid_response'); }
  }

  function botOptions(env, method, data) {
    return { method, headers: { Authorization: `Bot ${env.DISCORD_BOT_TOKEN}`, 'Content-Type': 'application/json' },
      ...(data ? { body: JSON.stringify(data) } : {}) };
  }

  async function oauth(env, grant) {
    const form = new URLSearchParams({ client_id: env.DISCORD_CLIENT_ID, client_secret: env.DISCORD_CLIENT_SECRET, ...grant });
    const tokens = await remote(env, '/oauth2/token', { method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: form.toString() }, { oauth: true });
    if (typeof tokens.access_token !== 'string' || typeof tokens.refresh_token !== 'string' ||
        tokens.token_type?.toLowerCase() !== 'bearer' || !Number.isFinite(tokens.expires_in) || tokens.expires_in <= 0) {
      throw new HttpError(503, 'discord_invalid_response');
    }
    if (!(tokens.scope ?? '').split(/\s+/).includes('sdk.social_layer')) throw new HttpError(403, 'discord_voice_scope_required');
    const user = await remote(env, '/users/@me', { headers: { Authorization: `Bearer ${tokens.access_token}` } }, { oauth: true });
    if (!snowflake(user.id)) throw new HttpError(503, 'discord_invalid_response');
    return { tokens, discordId: user.id, discordUser: user };
  }

  async function linkUser(db, userId, user) {
    if (!snowflake(user?.id)) throw new HttpError(503, 'discord_invalid_response');
    let updated;
    try {
      updated = await db.prepare(`UPDATE users SET discord_id = ?, discord_username = ? WHERE id = ?
        AND banned = 0 AND (discord_id IS NULL OR discord_id = ?) RETURNING discord_id`)
        .bind(user.id, String(user.username || user.global_name || user.id).slice(0, 80), userId, user.id).first();
    } catch (error) {
      if (/UNIQUE constraint failed/.test(String(error))) throw new HttpError(409, 'discord_account_already_linked');
      throw error;
    }
    if (!updated) throw new HttpError(409, 'different_discord_account_linked');
  }

  async function endMatch(env, db, matchId) {
    // Stop issuing assignments before touching Discord; failed removals remain for scheduled retry.
    await db.prepare("UPDATE voice_matches SET status = 'deleting' WHERE id = ?").bind(matchId).run();
    const { results } = await db.prepare('SELECT lobby_id FROM voice_rooms WHERE match_id = ? AND lobby_id IS NOT NULL')
      .bind(matchId).all();
    const removed = await Promise.allSettled(results.map(room =>
      remote(env, `/lobbies/${room.lobby_id}`, botOptions(env, 'DELETE'), { missingOk: true })));
    if (removed.some(result => result.status === 'rejected')) throw new HttpError(503, 'discord_cleanup_pending');
    await db.prepare('DELETE FROM voice_matches WHERE id = ?').bind(matchId).run();
  }

  async function matchResult(db, matchId) {
    const { results } = await db.prepare('SELECT team_id, lobby_id FROM voice_rooms WHERE match_id = ? ORDER BY team_id').bind(matchId).all();
    return { match_id: matchId, teams: results };
  }

  async function createMatch(env, db, value) {
    const now = Math.floor(Date.now() / 1000);
    if (!identifier(value.match_id) || !Number.isSafeInteger(value.expires_at) ||
        value.expires_at <= now || value.expires_at > now + 21600 || !Array.isArray(value.teams) ||
        value.teams.length < 1 || value.teams.length > 8) throw new HttpError(400, 'invalid_voice_match');
    const teams = value.teams.map(team => {
      if (!team || !identifier(team.team_id) || !Array.isArray(team.player_ids) || team.player_ids.length < 1 ||
          team.player_ids.length > 25 || team.player_ids.some(id => typeof id !== 'string' || id.length > 64 || !id.length)) {
        throw new HttpError(400, 'invalid_voice_team');
      }
      return { team_id: team.team_id, player_ids: [...team.player_ids].sort() };
    }).sort((a, b) => a.team_id.localeCompare(b.team_id));
    const players = teams.flatMap(team => team.player_ids);
    if (players.length > 100 || new Set(players).size !== players.length || new Set(teams.map(t => t.team_id)).size !== teams.length) {
      throw new HttpError(400, 'duplicate_or_excess_voice_players');
    }
    const previous = await db.prepare('SELECT * FROM voice_matches WHERE id = ?').bind(value.match_id).first();
    if (previous) {
      const rooms = await db.prepare('SELECT team_id, roster FROM voice_rooms WHERE match_id = ? ORDER BY team_id').bind(value.match_id).all();
      const sameRoster = JSON.stringify(rooms.results.map(r => ({ team_id: r.team_id, player_ids: JSON.parse(r.roster) }))) === JSON.stringify(teams);
      if (previous.status === 'active' && previous.expires_at > now && previous.expires_at === value.expires_at && sameRoster) {
        return json(await matchResult(db, value.match_id));
      }
      throw new HttpError(409, 'voice_match_conflict', { 'Retry-After': '3' });
    }
    const users = await db.prepare(`SELECT id, username, discord_id FROM users
      WHERE discord_id IS NOT NULL AND banned = 0 AND id IN (${players.map(() => '?').join(',')})`).bind(...players).all();
    if (users.results.length !== players.length) throw new HttpError(409, 'players_must_link_discord');
    const byId = new Map(users.results.map(user => [user.id, user]));
    const statements = [db.prepare("INSERT INTO voice_matches (id, status, expires_at, created_at) VALUES (?, 'creating', ?, ?)")
      .bind(value.match_id, value.expires_at, now)];
    const rooms = teams.map(team => ({ ...team, id: crypto.randomUUID() }));
    for (const room of rooms) {
      statements.push(db.prepare('INSERT INTO voice_rooms (id, match_id, team_id, roster) VALUES (?, ?, ?, ?)')
        .bind(room.id, value.match_id, room.team_id, JSON.stringify(room.player_ids)));
      for (const userId of room.player_ids) statements.push(db.prepare(`INSERT INTO voice_members (user_id, room_id)
        SELECT ?, ? WHERE EXISTS (SELECT 1 FROM users WHERE id = ? AND discord_id = ? AND banned = 0)`)
        .bind(userId, room.id, userId, byId.get(userId).discord_id));
    }
    try { await db.batch(statements); } catch (error) {
      if (/UNIQUE constraint failed/.test(String(error))) throw new HttpError(409, 'players_already_in_voice_match');
      if (/FOREIGN KEY constraint failed/.test(String(error))) throw new HttpError(409, 'players_must_link_discord');
      throw error;
    }
    const createdLobbies = [];
    try {
      const assigned = await db.prepare(`SELECT COUNT(*) AS n FROM voice_members v JOIN voice_rooms r ON r.id = v.room_id
        WHERE r.match_id = ?`).bind(value.match_id).first();
      if (assigned.n !== players.length) throw new HttpError(409, 'players_must_link_discord');
      for (const room of rooms) {
        const lobby = await remote(env, '/lobbies', botOptions(env, 'POST', {
          metadata: { match_id: value.match_id, team_id: room.team_id }, idle_timeout_seconds: Math.max(5, value.expires_at - now),
          members: room.player_ids.map(id => ({ id: byId.get(id).discord_id, additional_name: byId.get(id).username })),
        }));
        if (!snowflake(lobby.id)) throw new HttpError(503, 'discord_invalid_response');
        createdLobbies.push(lobby.id);
        const saved = await db.prepare('UPDATE voice_rooms SET lobby_id = ? WHERE id = ?').bind(lobby.id, room.id).run();
        if (saved.meta.changes !== 1) throw new HttpError(409, 'voice_match_cancelled');
      }
      const activated = await db.prepare("UPDATE voice_matches SET status = 'active' WHERE id = ? AND status = 'creating'").bind(value.match_id).run();
      if (activated.meta.changes !== 1) throw new HttpError(409, 'voice_match_cancelled');
    } catch (error) {
      await Promise.allSettled(createdLobbies.map(id => remote(env, `/lobbies/${id}`, botOptions(env, 'DELETE'), { missingOk: true })));
      try { await endMatch(env, db, value.match_id); } catch { /* retained for scheduled cleanup */ }
      throw error;
    }
    return json(await matchResult(db, value.match_id), 201);
  }

  return {
    link: linkUser,
    oauth,
    desktopRedirect,
    configured,
    async handle(request, env, db, key) {
      const path = new URL(request.url).pathname;
      const method = request.method;
      const routes = { '/discord/config': 'GET', '/discord/ready': 'GET', '/discord/status': 'GET', '/discord/exchange': 'POST',
        '/discord/refresh': 'POST', '/discord/unlink': 'POST', '/voice/session': 'GET', '/internal/voice/matches': 'POST' };
      const deletion = /^\/internal\/voice\/matches\/([a-zA-Z0-9_-]{1,64})$/.exec(path);
      const expectedMethod = deletion ? 'DELETE' : routes[path];
      if (!expectedMethod) throw new HttpError(404, 'not_found');
      if (method !== expectedMethod) throw new HttpError(405, 'method_not_allowed', { Allow: expectedMethod });
      if (path === '/discord/config' || path === '/discord/ready') {
        const checks = { application: snowflake(env.DISCORD_CLIENT_ID), client_secret: Boolean(env.DISCORD_CLIENT_SECRET?.length >= 16),
          bot_token: Boolean(env.DISCORD_BOT_TOKEN?.length >= 16), database: false };
        try {
          await db.batch([db.prepare('SELECT id, discord_id, discord_username FROM users LIMIT 0'),
            db.prepare('SELECT id, status, expires_at FROM voice_matches LIMIT 0'),
            db.prepare('SELECT id, match_id, team_id, lobby_id, roster FROM voice_rooms LIMIT 0'),
            db.prepare('SELECT user_id, room_id FROM voice_members LIMIT 0')]);
          checks.database = true;
        } catch { /* migration or configuration is incomplete */ }
        const ready = Object.values(checks).every(Boolean);
        if (path === '/discord/ready') return json({ ready, checks }, ready ? 200 : 503);
        return json({ enabled: ready, application_id: checks.application ? env.DISCORD_CLIENT_ID : null });
      }
      configured(env, path.startsWith('/internal/voice/'));
      if (path.startsWith('/internal/voice/')) {
        await coordinator(request, env, key);
        if (deletion) { await endMatch(env, db, deletion[1]); return json({ success: true }); }
        return createMatch(env, db, await body(request));
      }
      const auth = await authenticate(bearer(request), db, key);
      if (path === '/voice/session') {
        const row = await db.prepare(`SELECT r.lobby_id, r.team_id, m.id AS match_id, m.expires_at FROM voice_members v
          JOIN voice_rooms r ON r.id = v.room_id JOIN voice_matches m ON m.id = r.match_id
          JOIN users d ON d.id = v.user_id AND d.discord_id IS NOT NULL AND d.banned = 0
          WHERE v.user_id = ? AND m.status = 'active' AND m.expires_at > ?`)
          .bind(auth.user.id, Math.floor(Date.now() / 1000)).first();
        return json(row ? { assigned: true, ...row } : { assigned: false });
      }
      const link = await db.prepare('SELECT discord_id FROM users WHERE id = ? AND discord_id IS NOT NULL').bind(auth.user.id).first();
      if (path === '/discord/status') return json({ linked: Boolean(link), discord_id: link?.discord_id ?? null });
      await rateLimit(db, key, 'discord-account', auth.user.id, 20);
      if (path === '/discord/unlink') {
        if (env.AUTH_MODE !== 'legacy') throw new HttpError(409, 'discord_is_sign_in_identity');
        const removed = await db.prepare(`UPDATE users SET discord_id = NULL, discord_username = NULL WHERE id = ?
          AND NOT EXISTS (SELECT 1 FROM voice_members WHERE user_id = ?) RETURNING id`)
          .bind(auth.user.id, auth.user.id).first();
        if (link && !removed) throw new HttpError(409, 'leave_match_before_unlinking');
        return json({ success: true });
      }
      const value = await body(request);
      let grant;
      if (path === '/discord/exchange') {
        if (typeof value.code !== 'string' || !value.code.length || value.code.length > 2048 ||
            typeof value.code_verifier !== 'string' || !/^[A-Za-z0-9._~-]{43,128}$/.test(value.code_verifier) || !desktopRedirect(value.redirect_uri)) {
          throw new HttpError(400, 'invalid_discord_authorization');
        }
        grant = { grant_type: 'authorization_code', code: value.code, code_verifier: value.code_verifier, redirect_uri: value.redirect_uri };
      } else {
        if (!link) throw new HttpError(409, 'discord_link_required');
        if (typeof value.refresh_token !== 'string' || !value.refresh_token.length || value.refresh_token.length > 2048) {
          throw new HttpError(400, 'invalid_discord_refresh_token');
        }
        grant = { grant_type: 'refresh_token', refresh_token: value.refresh_token };
      }
      const { tokens, discordId, discordUser } = await oauth(env, grant);
      if (link && link.discord_id !== discordId) throw new HttpError(409, 'different_discord_account_linked');
      await linkUser(db, auth.user.id, discordUser);
      // Recheck a concurrent account switch before handing credentials to the client.
      const saved = await db.prepare('SELECT discord_id FROM users WHERE id = ?').bind(auth.user.id).first();
      if (saved?.discord_id !== discordId) throw new HttpError(409, 'different_discord_account_linked');
      return json({ discord_id: discordId, access_token: tokens.access_token, refresh_token: tokens.refresh_token,
        expires_in: tokens.expires_in, token_type: 'Bearer' });
    },

    async cleanup(env) {
      if (!env.DISCORD_BOT_TOKEN) return;
      const now = Math.floor(Date.now() / 1000);
      const db = env.DB.withSession('first-primary');
      const expired = await db.prepare(`SELECT id FROM voice_matches WHERE expires_at <= ? OR status = 'deleting'
        OR (status = 'creating' AND created_at < ?) ORDER BY created_at LIMIT 10`).bind(now, now - 180).all();
      const results = await Promise.allSettled(expired.results.map(row => endMatch(env, db, row.id)));
      if (results.some(result => result.status === 'rejected')) console.error('Discord voice cleanup pending; will retry');
    },
  };
}
