import { buildDiscordAuthorizeUrl, exchangeDiscordCode, getDiscordUser,
  sendVerificationEmail, sendVerificationSMS } from './providers.js';

const enc = new TextEncoder();
const now = () => Math.floor(Date.now() / 1000);
const hex = bytes => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
const random = () => crypto.getRandomValues(new Uint8Array(32));
const base64url = bytes => btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

export function verificationStatus(user) {
  const email = Boolean(user.email_verified);
  const phone = Boolean(user.phone_verified);
  const discord = Boolean(user.discord_id);
  return { email, phone, discord, fully_verified: user.auth_provider === 'discord' ? discord : email && phone && discord };
}

export function accountExtras({ HttpError, json, body, authenticate, bearer, rateLimit,
  passwordRecord, verifyPassword, tokenHash, discord }) {
  async function digest(key, text) {
    const imported = await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    return hex(await crypto.subtle.sign('HMAC', imported, enc.encode(text)));
  }

  function registration(value) {
    const email = typeof value.email === 'string' ? value.email.trim().toLowerCase() : '';
    if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError(400, 'valid_email_required');
    let phone = typeof value.phone === 'string' ? value.phone.replace(/[\s()-]/g, '') : '';
    if (!phone.startsWith('+')) phone = '+' + phone;
    if (!/^\+[1-9]\d{6,14}$/.test(phone)) throw new HttpError(400, 'valid_phone_required');
    return { email, phone };
  }

  async function sendCode(env, db, key, user, type, ip) {
    await rateLimit(db, key, 'verification-send-ip', ip, 10);
    await rateLimit(db, key, `verification-send-${type}`, user.id, 3);
    const destination = type === 'email' ? user.email : user.phone;
    if (!destination) throw new HttpError(400, 'verification_destination_missing');
    // Rejection sampling avoids modulo bias for a six-digit code.
    let code = '';
    while (code.length < 6) for (const value of crypto.getRandomValues(new Uint8Array(12))) {
      if (value < 250 && code.length < 6) code += String(value % 10);
    }
    const id = crypto.randomUUID();
    const codeHash = 'hmac:' + await digest(key, `code:${user.id}:${type}:${id}:${code}`);
    await db.batch([
      db.prepare('UPDATE verification_codes SET used = 1 WHERE user_id = ? AND type = ? AND used = 0').bind(user.id, type),
      db.prepare(`INSERT INTO verification_codes (id, user_id, type, code, destination, expires_at)
        VALUES (?, ?, ?, ?, ?, ?)`).bind(id, user.id, type, codeHash, destination, now() + 600),
    ]);
    try {
      if (type === 'email') await sendVerificationEmail(env, destination, code);
      else await sendVerificationSMS(env, destination, code);
    } catch (error) { throw new HttpError(503, error.message); }
    return { success: true, type, destination: type === 'phone' ? destination.slice(0, -4) + '****' : destination };
  }

  async function account(db, id) {
    const user = await db.prepare('SELECT * FROM users WHERE id = ?').bind(id).first();
    if (!user) throw new HttpError(404, 'account_not_found');
    return { id: user.id, username: user.username, email: user.auth_provider === 'discord' ? null : user.email, auth_provider: user.auth_provider, email_verified: Boolean(user.email_verified),
      phone: user.phone ? user.phone.slice(0, -4) + '****' : null, phone_verified: Boolean(user.phone_verified),
      discord_id: user.discord_id, discord_username: user.discord_username, discord_linked: Boolean(user.discord_id),
      created_at: user.created_at, last_login: user.last_login, verification: verificationStatus(user) };
  }

  function callbackUri(env) {
    try {
      const url = new URL(env.PUBLIC_URL);
      if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error();
      return new URL('/auth/discord/callback', url).href;
    } catch { throw new HttpError(503, 'public_url_not_configured'); }
  }

  return {
    registration, account,
    async afterRegister(env, db, key, user, ip) {
      const errors = [];
      for (const type of ['email', 'phone']) {
        try { await sendCode(env, db, key, user, type, ip); }
        catch (error) { errors.push({ [type]: error instanceof HttpError ? error.message : 'provider_unavailable' }); }
      }
      return errors;
    },

    async audit(db, key, username, ip, success) {
      await db.prepare('INSERT INTO login_attempts (username, ip, success) VALUES (?, ?, ?)')
        .bind(username, await digest(key, `audit-ip:${ip}`), success ? 1 : 0).run();
    },

    async handle(request, env, db, key) {
      const url = new URL(request.url);
      const path = url.pathname;
      const methods = { '/verify/email': 'POST', '/verify/phone': 'POST', '/verify/email/resend': 'POST',
        '/verify/phone/resend': 'POST', '/account/password': 'POST', '/auth/discord': 'GET', '/auth/discord/callback': 'GET' };
      if (!methods[path]) throw new HttpError(404, 'not_found');
      if (request.method !== methods[path]) throw new HttpError(405, 'method_not_allowed', { Allow: methods[path] });
      if (path === '/auth/discord/callback') {
        const state = url.searchParams.get('state') ?? '';
        const code = url.searchParams.get('code') ?? '';
        if (!/^[a-f0-9]{64}$/.test(state) || !code || code.length > 2048) throw new HttpError(400, 'invalid_discord_callback');
        // A separate, single-use state is bound to a live, unrevoked account session.
        const saved = await db.prepare(`DELETE FROM oauth_states WHERE state_hash = ? AND expires_at > ?
          AND EXISTS (SELECT 1 FROM sessions s JOIN users u ON u.id = s.user_id
            WHERE s.token_id = oauth_states.token_id AND s.user_id = oauth_states.user_id
            AND s.revoked = 0 AND s.expires_at > ? AND u.banned = 0 AND s.auth_version = u.auth_version)
          RETURNING user_id, code_verifier`).bind(await tokenHash(state), now(), now()).first();
        if (!saved) throw new HttpError(400, 'invalid_or_expired_oauth_state');
        let user;
        try {
          const tokens = await exchangeDiscordCode(env, code, callbackUri(env), saved.code_verifier);
          if (!(tokens.scope ?? '').split(/\s+/).includes('sdk.social_layer')) throw new HttpError(403, 'discord_voice_scope_required');
          user = await getDiscordUser(tokens.access_token, env);
        } catch (error) {
          if (error instanceof HttpError) throw error;
          throw new HttpError(503, 'discord_linking_failed');
        }
        await discord.link(db, saved.user_id, user);
        // No tokens in the browser URL or arbitrary deep-link redirects.
        return new Response('<!doctype html><meta charset="utf-8"><title>Ancient Nest</title><p>Discord linked successfully. You can close this window and return to the game.</p>',
          { headers: { 'Content-Type': 'text/html; charset=utf-8', 'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'" } });
      }

      const auth = await authenticate(bearer(request), db, key);
      if (path === '/auth/discord') {
        if (!env.DISCORD_CLIENT_ID || !env.DISCORD_CLIENT_SECRET) throw new HttpError(503, 'discord_not_configured');
        await rateLimit(db, key, 'discord-account', auth.user.id, 20);
        const redirect = callbackUri(env);
        const state = hex(random());
        const verifier = base64url(random());
        const challenge = base64url(new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(verifier))));
        await db.prepare(`INSERT INTO oauth_states (state_hash, user_id, token_id, code_verifier, expires_at)
          VALUES (?, ?, ?, ?, ?)`).bind(await tokenHash(state), auth.user.id, auth.sessionId, verifier, now() + 600).run();
        return json({ url: buildDiscordAuthorizeUrl(env, redirect, state, challenge), redirect_uri: redirect });
      }

      if (path === '/account/password') {
        await rateLimit(db, key, 'password-change', auth.user.id, 5);
        const value = await body(request);
        if (typeof value.current_password !== 'string' || value.current_password.length > 128 ||
            typeof value.new_password !== 'string' || value.new_password.length < 8 || value.new_password.length > 128) {
          throw new HttpError(400, 'password_must_be_8_to_128_characters');
        }
        const user = await db.prepare('SELECT * FROM users WHERE id = ?').bind(auth.user.id).first();
        if (!await verifyPassword(value.current_password, user.password_hash, user.password_salt)) throw new HttpError(401, 'invalid_credentials');
        const updated = await passwordRecord(value.new_password);
        const results = await db.batch([
          db.prepare(`UPDATE users SET password_hash = ?, password_salt = ?, auth_version = auth_version + 1
            WHERE id = ? AND auth_version = ?`).bind(updated.hash, updated.salt, user.id, user.auth_version),
          db.prepare('UPDATE sessions SET revoked = 1 WHERE user_id = ? AND auth_version <= ?').bind(user.id, user.auth_version),
        ]);
        if (results[0].meta.changes !== 1) throw new HttpError(409, 'account_changed_retry');
        return json({ success: true });
      }

      const type = path.includes('/email') ? 'email' : 'phone';
      const user = await db.prepare('SELECT * FROM users WHERE id = ?').bind(auth.user.id).first();
      if (user[`${type}_verified`]) throw new HttpError(400, `${type}_already_verified`);
      if (path.endsWith('/resend')) {
        return json(await sendCode(env, db, key, user, type, request.headers.get('CF-Connecting-IP') ?? 'local'));
      }
      await rateLimit(db, key, `verify-${type}`, user.id, 20);
      const value = await body(request);
      if (typeof value.code !== 'string' || !/^\d{6}$/.test(value.code)) throw new HttpError(400, 'six_digit_code_required');
      const record = await db.prepare(`SELECT id FROM verification_codes WHERE user_id = ? AND type = ?
        AND used = 0 AND expires_at > ? ORDER BY created_at DESC, rowid DESC LIMIT 1`).bind(user.id, type, now()).first();
      if (!record) throw new HttpError(400, 'invalid_or_expired_code');
      const attempted = await db.prepare(`UPDATE verification_codes SET attempts = attempts + 1
        WHERE id = ? AND used = 0 AND expires_at > ? AND attempts < 5 RETURNING code, destination`)
        .bind(record.id, now()).first();
      if (!attempted) throw new HttpError(429, 'verification_attempts_exhausted');
      const expected = attempted.code.startsWith('hmac:')
        ? 'hmac:' + await digest(key, `code:${user.id}:${type}:${record.id}:${value.code}`) : value.code;
      if (expected !== attempted.code) throw new HttpError(400, 'invalid_or_expired_code');
      const results = await db.batch([
        // type is a fixed email/phone enum, never user-supplied SQL.
        db.prepare(`UPDATE users SET ${type}_verified = 1 WHERE id = ? AND ${type} = ?
          AND EXISTS (SELECT 1 FROM verification_codes WHERE id = ? AND used = 0 AND expires_at > ?)`)
          .bind(user.id, attempted.destination, record.id, now()),
        db.prepare('UPDATE verification_codes SET used = 1 WHERE id = ? AND used = 0').bind(record.id),
      ]);
      if (results[0].meta.changes !== 1 || results[1].meta.changes !== 1) throw new HttpError(400, 'invalid_or_expired_code');
      const verified = await db.prepare('SELECT * FROM users WHERE id = ?').bind(user.id).first();
      return json({ success: true, verification: verificationStatus(verified) });
    },
  };
}
