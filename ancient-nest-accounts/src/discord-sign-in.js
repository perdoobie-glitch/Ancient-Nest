// Discord proves identity; game usernames and revocable device sessions remain server-owned.
export function discordSignIn({ HttpError, json, body, authenticate, bearer, rateLimit, discord,
  newSession, sessionInsert, sessionResponse }) {
  return async (request, env, db, key, ttl) => {
    const path = new URL(request.url).pathname;
    if (path === '/auth/discord/config') {
      if (request.method !== 'GET') throw new HttpError(405, 'method_not_allowed');
      discord.configured(env);
      return json({ auth_provider: 'discord', application_id: env.DISCORD_CLIENT_ID });
    }
    if (request.method !== 'POST') throw new HttpError(405, 'method_not_allowed');
    if (path === '/profile/username') {
      const auth = await authenticate(bearer(request), db, key);
      await rateLimit(db, key, 'profile-name', auth.user.id, 5);
      const { username } = await body(request);
      if (typeof username !== 'string' || !/^[a-zA-Z0-9_-]{3,24}$/.test(username)) {
        throw new HttpError(400, 'invalid_game_username');
      }
      try {
        const saved = await db.prepare('UPDATE users SET username = ? WHERE id = ? AND banned = 0 RETURNING id, username, created_at')
          .bind(username, auth.user.id).first();
        if (!saved) throw new HttpError(401, 'invalid_token');
        return json({ user: saved });
      } catch (error) {
        if (/UNIQUE constraint failed/.test(String(error))) throw new HttpError(409, 'username_taken');
        throw error;
      }
    }
    discord.configured(env);
    await rateLimit(db, key, 'discord-sign-in-ip', request.headers.get('CF-Connecting-IP') ?? 'local', 30);
    const value = await body(request);
    if (typeof value.code !== 'string' || !value.code.length || value.code.length > 2048 ||
        typeof value.code_verifier !== 'string' || !/^[A-Za-z0-9._~-]{43,128}$/.test(value.code_verifier) ||
        !discord.desktopRedirect(value.redirect_uri)) throw new HttpError(400, 'invalid_discord_authorization');
    // Exchange only with this application's credentials; never trust a client-supplied Discord ID.
    const { tokens, discordId, discordUser } = await discord.oauth(env, {
      grant_type: 'authorization_code', code: value.code, code_verifier: value.code_verifier, redirect_uri: value.redirect_uri,
    });
    let user = await db.prepare('SELECT * FROM users WHERE discord_id = ?').bind(discordId).first();
    if (!user) {
      const id = crypto.randomUUID();
      // Start with a Discord-derived default; the player may change it after signing in.
      const stem = String(discordUser.username ?? 'Player').replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 3) || 'P';
      let username = stem + '_' + discordId;
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          await db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email, discord_id,
            discord_username, auth_provider, created_at) VALUES (?, ?, 'DISCORD_ONLY', '', ?, ?, ?, 'discord', ?)`)
            // Compatibility placeholder for the old NOT NULL schema; never used for contact or merging.
            .bind(id, username, id + '@discord.identity.invalid', discordId,
              String(discordUser.username ?? discordId).slice(0, 80), Math.floor(Date.now() / 1000)).run();
        } catch (error) {
          if (!/UNIQUE constraint failed/.test(String(error))) throw error;
        }
        user = await db.prepare('SELECT * FROM users WHERE discord_id = ?').bind(discordId).first();
        if (user) break;
        // Another player may already use the proposed name. Never merge that profile.
        username = 'Player_' + crypto.randomUUID().replaceAll('-', '').slice(0, 16);
      }
      if (!user) throw new HttpError(409, 'username_conflict');
    }
    if (user.banned) throw new HttpError(403, 'account_banned');
    // Reuse a previously linked profile by verified Discord ID, never by matching a name/email.
    const saved = await db.prepare(`UPDATE users SET auth_provider = 'discord', discord_username = ?, last_login = ?
      WHERE id = ? AND banned = 0 AND auth_version = ? RETURNING *`)
      .bind(String(discordUser.username ?? discordId).slice(0, 80), Math.floor(Date.now() / 1000), user.id, user.auth_version).first();
    if (!saved) throw new HttpError(401, 'invalid_token');
    const session = await newSession(saved, key, ttl);
    const issued = await sessionInsert(db, saved, session).run();
    if (issued.meta.changes !== 1) throw new HttpError(401, 'invalid_token');
    return json({ ...sessionResponse(saved, session), auth_provider: 'discord', discord: {
      discord_id: discordId, access_token: tokens.access_token, refresh_token: tokens.refresh_token,
      expires_in: tokens.expires_in, token_type: 'Bearer',
    } });
  };
}
