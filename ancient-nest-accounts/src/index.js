import { discordSignIn } from './discord-sign-in.js';
import { gameIdentity } from './game-identity.js';
import { liveTestRoute } from './live-test-page.js';
import { SignJWT, jwtVerify } from 'jose';
import { DUMMY_HASH, passwordRecord, verifyPassword } from './passwords.js';
import { discordRoutes } from './discord.js';
import { accountExtras, verificationStatus } from './account-extras.js';

const VERSION = '10.4-discord';
const ISSUER = 'ancient-nest-accounts';
const AUDIENCE = 'ancient-nest';
const WINDOW = 900;
const DEVICE_TTL = 90 * 86400;
const REFRESH_RETRY_GRACE = 60;
const encoder = new TextEncoder();

class HttpError extends Error {
  constructor(status, code, headers = {}) {
    super(code);
    this.status = status;
    this.headers = headers;
  }
}

function json(value, status = 200, headers = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...headers },
  });
}

function configured(value) {
  return typeof value === 'string' && encoder.encode(value).length >= 32 && !value.startsWith('replace-with');
}

function settings(env) {
  const ttl = Number(env.TOKEN_TTL_SECONDS ?? 3600);
  if (!configured(env.JWT_SECRET) || !configured(env.COORDINATOR_API_KEY) ||
      !Number.isSafeInteger(ttl) || ttl < 300 || ttl > 86400 || !env.DB) {
    throw new HttpError(503, 'service_not_configured');
  }
  return { key: encoder.encode(env.JWT_SECRET), ttl };
}

async function body(request) {
  if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get('Content-Type') ?? '')) {
    throw new HttpError(415, 'json_required');
  }
  if (Number(request.headers.get('Content-Length')) > 4096) throw new HttpError(413, 'body_too_large');
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError(400, 'invalid_json');
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 4096) {
        await reader.cancel();
        throw new HttpError(413, 'body_too_large');
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  try {
    const buffer = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) { buffer.set(chunk, offset); offset += chunk.length; }
    const value = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(buffer));
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error();
    return value;
  } catch {
    throw new HttpError(400, 'invalid_json');
  }
}

function credentials(value) {
  if (typeof value.username !== 'string' || !/^[a-zA-Z0-9_-]{3,24}$/.test(value.username)) {
    throw new HttpError(400, 'username_must_be_3_to_24_ascii_letters_digits_or_underscores');
  }
  if (typeof value.password !== 'string' || value.password.length < 8 ||
      value.password.length > 128 || encoder.encode(value.password).length > 512) {
    throw new HttpError(400, 'password_must_be_8_to_128_characters');
  }
  return { username: value.username, usernameKey: value.username.toLowerCase(), password: value.password };
}

async function macKey(key) {
  return crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

async function coordinator(request, env, key) {
  const provided = request.headers.get('X-Coordinator-Key') ?? '';
  const signingKey = await macKey(key);
  const expected = await crypto.subtle.sign('HMAC', signingKey, encoder.encode(env.COORDINATOR_API_KEY));
  if (!await crypto.subtle.verify('HMAC', signingKey, expected, encoder.encode(provided))) {
    throw new HttpError(401, 'invalid_coordinator_key');
  }
}

async function rateLimit(db, key, scope, identity, limit) {
  const now = Math.floor(Date.now() / 1000);
  const bucket = Math.floor(now / WINDOW);
  // Keep raw IP addresses and attempted usernames out of the rate-limit table.
  const digest = new Uint8Array(await crypto.subtle.sign('HMAC', await macKey(key),
    encoder.encode(`rate:${scope}:${identity}:${bucket}`)));
  const id = Array.from(digest, b => b.toString(16).padStart(2, '0')).join('');
  const expires = (bucket + 1) * WINDOW;
  const row = await db.prepare(`INSERT INTO rate_limits (key, attempts, expires_at) VALUES (?, 1, ?)
    ON CONFLICT(key) DO UPDATE SET attempts = MIN(attempts + 1, 1000000) RETURNING attempts`)
    .bind(id, expires).first();
  if (row.attempts > limit) throw new HttpError(429, 'rate_limited', { 'Retry-After': String(expires - now) });
}

function publicUser(user) {
  return { id: user.id, username: user.username, created_at: user.created_at };
}

async function accessToken(user, key, ttl, id, sessionExpires) {
  const now = Math.floor(Date.now() / 1000);
  const expires = Math.min(now + ttl, sessionExpires);
  const token = await new SignJWT({ username: user.username }).setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuer(ISSUER).setAudience(AUDIENCE).setSubject(user.id).setJti(id)
    .setIssuedAt(now).setExpirationTime(expires).sign(key);
  return { expires, token };
}

function hex(buffer) {
  return Array.from(new Uint8Array(buffer), b => b.toString(16).padStart(2, '0')).join('');
}

async function tokenHash(token) {
  return hex(await crypto.subtle.digest('SHA-256', encoder.encode(token)));
}

async function nextRefreshToken(token, key) {
  // Deterministic rotation lets a client retry a lost response during a short grace period.
  // Only hashes of these secrets are stored in D1.
  return hex(await crypto.subtle.sign('HMAC', await macKey(key), encoder.encode(`refresh:${token}`)));
}

function refreshToken(value) {
  if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) {
    throw new HttpError(401, 'invalid_refresh_token');
  }
  return value;
}

async function newSession(user, key, ttl) {
  const now = Math.floor(Date.now() / 1000);
  const id = crypto.randomUUID();
  const sessionExpires = now + DEVICE_TTL;
  const refresh = hex(crypto.getRandomValues(new Uint8Array(32)));
  const refreshHash = await tokenHash(refresh);
  return { id, now, sessionExpires, refresh, refreshHash,
    ...await accessToken(user, key, ttl, id, sessionExpires) };
}

function sessionResponse(user, session) {
  return { success: true, user: publicUser(user), token: session.token, expires_at: session.expires,
    verification: verificationStatus(user),
    refresh_token: session.refresh, refresh_expires_at: session.sessionExpires };
}

function sessionInsert(db, user, session) {
  return db.prepare(`INSERT INTO sessions (token_id, user_id, expires_at, issued_at, refresh_hash, auth_version)
    SELECT ?, ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM users WHERE id = ? AND auth_version = ? AND banned = 0)`)
    .bind(session.id, user.id, session.sessionExpires, session.now, session.refreshHash,
      user.auth_version ?? 0, user.id, user.auth_version ?? 0);
}

async function findDevice(db, hash, now) {
  return db.prepare(`SELECT s.token_id AS session_id, s.expires_at AS session_expires,
    s.refresh_hash, s.previous_refresh_hash, s.previous_refresh_until, u.*
    FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.expires_at > ? AND s.revoked = 0
    AND u.banned = 0 AND s.auth_version = u.auth_version AND
    (s.refresh_hash = ? OR (s.previous_refresh_hash = ? AND s.previous_refresh_until >= ?))`)
    .bind(now, hash, hash, now).first();
}

async function refreshSession(db, key, ttl, refresh) {
  const now = Math.floor(Date.now() / 1000);
  const hash = await tokenHash(refresh);
  const device = await findDevice(db, hash, now);
  if (!device) throw new HttpError(401, 'invalid_refresh_token');
  const next = await nextRefreshToken(refresh, key);
  const nextHash = await tokenHash(next);
  if (device.refresh_hash === hash) {
    const sessionExpires = now + DEVICE_TTL;
    const access = await accessToken(device, key, ttl, device.session_id, sessionExpires);
    // Compare and swap: concurrent refreshes may rotate this device only once.
    const updated = await db.prepare(`UPDATE sessions SET refresh_hash = ?, previous_refresh_hash = ?,
      previous_refresh_until = ?, expires_at = ? WHERE token_id = ? AND refresh_hash = ? AND expires_at > ? AND revoked = 0
      RETURNING token_id`).bind(nextHash, hash, now + REFRESH_RETRY_GRACE, sessionExpires,
      device.session_id, hash, now).first();
    if (updated) return sessionResponse(device, { ...access, refresh: next, sessionExpires });
  }
  // A concurrent call or lost response can retry the immediately preceding token for 60 seconds.
  // Reissue the same successor, without extending its expiry or rotating it again.
  const current = await findDevice(db, hash, now);
  if (!current || current.previous_refresh_hash !== hash || current.refresh_hash !== nextHash) {
    throw new HttpError(401, 'invalid_refresh_token');
  }
  return sessionResponse(current, { ...await accessToken(current, key, ttl, current.session_id, current.session_expires),
    refresh: next, sessionExpires: current.session_expires });
}

function bearer(request) {
  const match = /^Bearer ([A-Za-z0-9_.-]+)$/i.exec(request.headers.get('Authorization') ?? '');
  if (!match || match[1].length > 2048) throw new HttpError(401, 'invalid_token');
  return match[1];
}

async function authenticate(token, db, key, expectedAudience = AUDIENCE) {
  let payload;
  try {
    if (typeof token !== 'string' || token.length > 2048) throw new Error();
    ({ payload } = await jwtVerify(token, key, {
      algorithms: ['HS256'], typ: 'JWT',
      requiredClaims: ['sub', 'jti', 'iat', 'exp'], maxTokenAge: '24h',
    }));
    if (typeof payload.sub !== 'string' || typeof payload.jti !== 'string' ||
        !Number.isSafeInteger(payload.iat) || !Number.isSafeInteger(payload.exp) ||
        payload.exp <= payload.iat || payload.exp - payload.iat > 86400) throw new Error();
    if (expectedAudience !== AUDIENCE && (payload.iss !== ISSUER || payload.aud !== expectedAudience)) throw new Error();
    // Exported 10.2 JWTs lacked issuer/audience; accept those only with a matching live session.
    if ((payload.iss !== undefined || payload.aud !== undefined) &&
        (payload.iss !== ISSUER || payload.aud !== expectedAudience)) throw new Error();
  } catch {
    throw new HttpError(401, 'invalid_token');
  }
  const user = await db.prepare(`SELECT u.* FROM sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.token_id = ? AND s.user_id = ? AND s.expires_at > ? AND s.expires_at >= ?
    AND s.revoked = 0 AND u.banned = 0 AND s.auth_version = u.auth_version`)
    .bind(payload.jti, payload.sub, Math.floor(Date.now() / 1000), payload.exp).first();
  if (!user) throw new HttpError(401, 'invalid_token');
  return { claims: payload, user: publicUser(user), record: user, sessionId: payload.jti, expires: payload.exp };
}

async function route(request, env) {
  const path = new URL(request.url).pathname;
  const method = request.method;
  const discordOnly = env.AUTH_MODE !== 'legacy';
  if (discordOnly && (['/register', '/login', '/account/password', '/setup-test', '/setup-test.js', '/setup-test.css'].includes(path) ||
      path.startsWith('/verify/') || path.startsWith('/auth/discord') && !['/auth/discord/config', '/auth/discord/exchange'].includes(path))) {
    throw new HttpError(410, 'use_discord_sign_in');
  }
  if (path === '/auth/discord/config' || path === '/auth/discord/exchange' || path === '/profile/username') {
    const { key, ttl } = settings(env);
    return discordLogin(request, env, env.DB.withSession('first-primary'), key, ttl);
  }
  const liveTest = liveTestRoute(path);
  if (liveTest) {
    if (method !== 'GET') throw new HttpError(405, 'method_not_allowed', { Allow: 'GET' });
    return liveTest;
  }
  if (path === '/signup/config' && method === 'GET') return json({ auth_provider: discordOnly ? 'discord' : 'legacy', email_required: !discordOnly, phone_required: !discordOnly });
  if (path === '/api/game/assertion' || path === '/api/game/verify') {
    const { key } = settings(env);
    return identity(request, env, env.DB.withSession('first-primary'), key);
  }
  if (path.startsWith('/discord/') || path === '/voice/session' || path.startsWith('/internal/voice/')) {
    const { key } = settings(env);
    return discord.handle(request, env, env.DB.withSession('first-primary'), key);
  }
  if (path === '/health' && method === 'GET') return json({ status: 'ok', version: VERSION });
  if (path.startsWith('/verify/') || path === '/account/password' || path.startsWith('/auth/discord')) {
    const { key } = settings(env);
    return extras.handle(request, env, env.DB.withSession('first-primary'), key);
  }
  if (path === '/ready' && method === 'GET') {
    const checks = { secrets: false, database: false };
    try { settings(env); checks.secrets = true; } catch { /* report without secret values */ }
    try {
      const db = env.DB.withSession('first-primary');
      await db.batch([
        db.prepare('SELECT id, username, password_hash, password_salt, email, phone, auth_version, auth_provider FROM users LIMIT 0'),
        db.prepare(`SELECT token_id, user_id, expires_at, issued_at, refresh_hash, revoked, auth_version,
          previous_refresh_hash, previous_refresh_until FROM sessions LIMIT 0`),
        db.prepare('SELECT id, attempts, code FROM verification_codes LIMIT 0'),
        db.prepare('SELECT state_hash, user_id, token_id, code_verifier, expires_at FROM oauth_states LIMIT 0'),
        db.prepare('SELECT key, attempts, expires_at FROM rate_limits LIMIT 0'),
      ]);
      checks.database = true;
    } catch { /* schema may not be migrated yet */ }
    const ready = Object.values(checks).every(Boolean);
    return json({ ready, version: VERSION, checks: { ...checks, jwt_secret: configured(env.JWT_SECRET),
      resend: Boolean(env.RESEND_API_KEY), twilio: Boolean(env.TWILIO_ACCOUNT_SID && env.TWILIO_AUTH_TOKEN && env.TWILIO_FROM),
      discord: Boolean(env.DISCORD_CLIENT_ID && env.DISCORD_CLIENT_SECRET && env.DISCORD_BOT_TOKEN) } }, ready ? 200 : 503);
  }
  const routes = { '/register': 'POST', '/login': 'POST', '/verify': 'GET', '/account': 'GET',
    '/logout': 'POST', '/refresh': 'POST', '/internal/verify': 'POST' };
  if (!routes[path]) throw new HttpError(404, 'not_found');
  if (routes[path] !== method) throw new HttpError(405, 'method_not_allowed', { Allow: routes[path] });
  const { key, ttl } = settings(env);
  // First read must use the primary so a revoked session cannot survive on a stale replica.
  const db = env.DB.withSession('first-primary');

  if (path === '/register' || path === '/login') {
    await rateLimit(db, key, 'auth-ip', request.headers.get('CF-Connecting-IP') ?? 'local', 30);
    const data = await body(request);
    const { username, usernameKey, password } = credentials(data);
    await rateLimit(db, key, 'auth-username', usernameKey, 10);
    if (path === '/register') {
      const registration = extras.registration(data);
      const user = { id: crypto.randomUUID(), username, created_at: Math.floor(Date.now() / 1000), ...registration };
      const { hash: passwordHash, salt } = await passwordRecord(password);
      const existing = await db.prepare(`SELECT id FROM users WHERE username = ? OR email = ? COLLATE NOCASE
        OR phone IN (?, ?)`).bind(username, user.email, user.phone, user.phone.slice(1)).first();
      if (existing) throw new HttpError(409, 'account_already_registered');
      const session = await newSession(user, key, ttl);
      try {
        await db.batch([
          db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email, phone, created_at, last_login)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)`).bind(user.id, username, passwordHash, salt, user.email, user.phone, user.created_at, user.created_at),
          sessionInsert(db, user, session),
        ]);
      } catch (error) {
        if (/UNIQUE constraint failed: users\./.test(String(error))) {
          throw new HttpError(409, 'account_already_registered');
        }
        throw error;
      }
      const sendErrors = await extras.afterRegister(env, db, key, user, request.headers.get('CF-Connecting-IP') ?? 'local');
      return json({ ...sessionResponse(user, session), needs: ['email', 'phone', 'discord'],
        ...(sendErrors.length ? { send_errors: sendErrors } : {}) }, 201);
    }
    const user = await db.prepare('SELECT * FROM users WHERE username = ?').bind(username).first();
    const valid = await verifyPassword(password, user?.password_hash ?? DUMMY_HASH, user?.password_salt);
    await extras.audit(db, key, username, request.headers.get('CF-Connecting-IP') ?? 'local', Boolean(user && valid && !user.banned));
    if (!user || !valid || user.banned) throw new HttpError(401, 'invalid_credentials');
    if (!user.password_hash.startsWith('pbkdf2-sha256$')) {
      const upgraded = await passwordRecord(password);
      await db.prepare(`UPDATE users SET password_hash = ?, password_salt = ? WHERE id = ?
        AND password_hash = ? AND auth_version = ?`).bind(upgraded.hash, upgraded.salt, user.id, user.password_hash, user.auth_version).run();
    }
    const session = await newSession(user, key, ttl);
    const issued = await db.batch([sessionInsert(db, user, session),
      db.prepare('UPDATE users SET last_login = ? WHERE id = ? AND auth_version = ?').bind(session.now, user.id, user.auth_version)]);
    if (issued[0].meta.changes !== 1) throw new HttpError(401, 'invalid_credentials');
    return json(sessionResponse(user, session));
  }

  if (path === '/refresh' || (path === '/logout' && !request.headers.has('Authorization'))) {
    await rateLimit(db, key, 'device-ip', request.headers.get('CF-Connecting-IP') ?? 'local', 120);
    const refresh = refreshToken((await body(request)).refresh_token);
    if (path === '/refresh') return json(await refreshSession(db, key, ttl, refresh));
    const device = await findDevice(db, await tokenHash(refresh), Math.floor(Date.now() / 1000));
    if (!device) throw new HttpError(401, 'invalid_refresh_token');
    await db.prepare('UPDATE sessions SET revoked = 1 WHERE token_id = ?').bind(device.session_id).run();
    return json({ success: true });
  }

  if (path === '/internal/verify') {
    await coordinator(request, env, key);
    const { token } = await body(request);
    const auth = await authenticate(token, db, key);
    const status = verificationStatus(auth.record);
    return json({ valid: true, user: { ...auth.user, email_verified: status.email, phone_verified: status.phone,
      discord_linked: status.discord, fully_verified: status.fully_verified }, expires_at: auth.expires });
  }

  const auth = await authenticate(bearer(request), db, key);
  if (path === '/logout') {
    await db.prepare('UPDATE sessions SET revoked = 1 WHERE token_id = ?').bind(auth.sessionId).run();
    return json({ success: true });
  }
  if (path === '/account') return json(await extras.account(db, auth.user.id));
  const verification = verificationStatus(auth.record);
  return json({ valid: true, user: { ...auth.user, email_verified: verification.email, phone_verified: verification.phone,
    discord_linked: verification.discord, fully_verified: verification.fully_verified }, expires_at: auth.expires });
}

const discord = discordRoutes({ HttpError, json, body, authenticate, bearer, rateLimit, coordinator });
const discordLogin = discordSignIn({ HttpError, json, body, authenticate, bearer, rateLimit, discord, newSession, sessionInsert, sessionResponse });
const identity = gameIdentity({ HttpError, json, body, bearer, authenticate, rateLimit });
const extras = accountExtras({ HttpError, json, body, authenticate, bearer, rateLimit, passwordRecord, verifyPassword, tokenHash, discord });

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin');
    const sameOrigin = origin === new URL(request.url).origin;
    const allowed = (env.CORS_ORIGIN ?? env.ALLOWED_ORIGINS ?? '').split(',').map(value => value.trim()).filter(Boolean);
    const headers = {
      'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', Vary: 'Origin',
      ...(origin && (sameOrigin || allowed.includes(origin)) ? { 'Access-Control-Allow-Origin': origin } : {}),
    };
    let response;
    try {
      if (origin && !sameOrigin && !allowed.includes(origin)) throw new HttpError(403, 'origin_not_allowed');
      if (request.method === 'OPTIONS') {
        const methods = ['GET', 'POST'];
        const requestedHeaders = (request.headers.get('Access-Control-Request-Headers') ?? '')
          .toLowerCase().split(',').map(value => value.trim()).filter(Boolean);
        if (!origin || !methods.includes(request.headers.get('Access-Control-Request-Method')) ||
            requestedHeaders.some(value => !['content-type', 'authorization', 'x-coordinator-key'].includes(value))) {
          throw new HttpError(403, 'preflight_not_allowed');
        }
        response = new Response(null, { status: 204, headers: {
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Coordinator-Key',
          'Access-Control-Max-Age': '600',
        } });
      } else {
        response = await route(request, env);
      }
    } catch (error) {
      if (error instanceof HttpError) {
        response = json({ error: error.message }, error.status, {
          ...(error.status === 401 ? { 'WWW-Authenticate': 'Bearer' } : {}), ...error.headers,
        });
      } else {
        // Never log requests, credentials, tokens, or database errors containing user data.
        console.error('Accounts request failed');
        response = json({ error: 'internal_error' }, 500);
      }
    }
    for (const [name, value] of Object.entries(headers)) response.headers.set(name, value);
    return response;
  },

  async scheduled(_event, env, ctx) {
    const now = Math.floor(Date.now() / 1000);
    ctx.waitUntil(env.DB.batch([
      env.DB.prepare('DELETE FROM sessions WHERE expires_at <= ?').bind(now),
      env.DB.prepare('DELETE FROM rate_limits WHERE expires_at <= ?').bind(now),
      env.DB.prepare('DELETE FROM verification_codes WHERE expires_at <= ?').bind(now),
      env.DB.prepare('DELETE FROM oauth_states WHERE expires_at <= ?').bind(now),
      env.DB.prepare('DELETE FROM login_attempts WHERE attempted_at <= ?').bind(now - 7 * 86400),
    ]));
    ctx.waitUntil(discord.cleanup(env));
  },
};
