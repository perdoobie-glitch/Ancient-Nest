import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { build } from 'esbuild';
import { Miniflare } from 'miniflare';
import { SignJWT } from 'jose';
import { pbkdf2Sync, generateKeyPairSync, createHash } from 'node:crypto';

const secret = 'a-local-test-secret-with-at-least-32-bytes';
const coordinator = 'a-local-coordinator-key-with-at-least-32-bytes';
const password = 'a very strong test password';
let mf;
let db;
const discordAppId = '123456789012345678';
let discordState;
let signupCounter = 0;

async function providerHttp(request) {
  const url = new URL(request.url);
  if (url.hostname === 'api.resend.com') {
    if (discordState.failEmail) return Response.json({}, { status: 500 });
    const value = await request.json();
    discordState.deliveries.push({ type: 'email', destination: value.to, code: /<strong>(\d{6})<\/strong>/.exec(value.html)?.[1] });
    return Response.json({ id: 'test-email' });
  }
  if (url.hostname === 'api.twilio.com') {
    const form = new URLSearchParams(await request.text());
    discordState.deliveries.push({ type: 'phone', destination: form.get('To'), code: /code is (\d{6})/.exec(form.get('Body'))?.[1] });
    return Response.json({ sid: 'test-message' }, { status: 201 });
  }
  return discordHttp(request);
}

async function discordHttp(request) {
  const path = new URL(request.url).pathname.replace('/api/v10', '');
  discordState.paths.push(path);
  if (path === '/oauth2/token') {
    const form = new URLSearchParams(await request.text());
    assert.equal(form.get('client_id'), discordAppId);
    assert.equal(form.get('client_secret'), 'test-discord-client-secret');
    const source = form.get('code') ?? form.get('refresh_token');
    const id = /^discord-(?:code|refresh)-([0-9]{18})$/.exec(source ?? '')?.[1];
    if (!id) return Response.json({ error: 'invalid_grant' }, { status: 400 });
    return Response.json({ access_token: `discord-access-${id}`, refresh_token: `discord-refresh-${id}`,
      token_type: 'Bearer', expires_in: 604800, scope: discordState.scope });
  }
  if (path === '/users/@me') {
    const id = /^Bearer discord-access-([0-9]{18})$/.exec(request.headers.get('Authorization'))?.[1];
    return id ? Response.json({ id }) : Response.json({}, { status: 401 });
  }
  assert.equal(request.headers.get('Authorization'), 'Bot test-discord-bot-token');
  if (path === '/lobbies' && request.method === 'POST') {
    discordState.creates++;
    if (discordState.failCreate === discordState.creates) return Response.json({}, { status: 503 });
    const id = String(900000000000000000n + BigInt(discordState.creates));
    discordState.lobbies.set(id, await request.json());
    return Response.json({ id });
  }
  if (path.startsWith('/lobbies/') && request.method === 'DELETE') {
    if (discordState.failDelete) return Response.json({}, { status: 503 });
    const id = path.split('/').at(-1);
    const exists = discordState.lobbies.delete(id);
    return new Response(null, { status: exists ? 204 : 404 });
  }
  throw new Error('Unexpected Discord test request');
}

before(async () => {
  const bundled = await build({ entryPoints: ['src/index.js'], bundle: true, write: false, format: 'esm', platform: 'browser' });
  mf = new Miniflare({
    modules: true, script: bundled.outputFiles[0].text, compatibilityDate: '2026-08-01',
    d1Databases: ['DB'], bindings: {
      AUTH_MODE: 'legacy', JWT_SECRET: secret, COORDINATOR_API_KEY: coordinator, TOKEN_TTL_SECONDS: '3600',
      ALLOWED_ORIGINS: 'https://ancientnest.net,http://localhost:3000',
      DISCORD_CLIENT_ID: discordAppId, DISCORD_CLIENT_SECRET: 'test-discord-client-secret',
      DISCORD_BOT_TOKEN: 'test-discord-bot-token',
      PUBLIC_URL: 'https://accounts.test', RESEND_API_KEY: 'test-resend',
      TWILIO_ACCOUNT_SID: 'AC' + '0'.repeat(32), TWILIO_AUTH_TOKEN: 'test-twilio', TWILIO_FROM: '+12025550000',
    },
    serviceBindings: { DISCORD_HTTP: discordHttp, PROVIDER_HTTP: providerHttp },
  });
  db = await mf.getD1Database('DB');
  const migrations = new URL('../migrations/', import.meta.url);
  for (const name of (await readdir(migrations)).filter(name => name.endsWith('.sql')).sort()) {
    const schema = await readFile(new URL(name, migrations), 'utf8');
    for (const statement of schema.replace(/--[^\n]*/g, '').split(/;(?=\s*(?:CREATE|ALTER|INSERT|UPDATE|DELETE|DROP|PRAGMA|$))/i).map(s => s.trim()).filter(Boolean)) {
      await db.prepare(statement).run();
    }
  }
});

after(async () => { await mf?.dispose(); });
beforeEach(async () => {
  signupCounter = 0;
  discordState = { lobbies: new Map(), creates: 0, failCreate: 0, failDelete: false, scope: 'identify sdk.social_layer', paths: [], deliveries: [], failEmail: false };
  await db.batch(['DELETE FROM voice_matches', 'DELETE FROM users', 'DELETE FROM rate_limits', 'DELETE FROM login_attempts'].map(sql => db.prepare(sql)));
});

function request(path, { method = 'GET', data, token, headers = {}, raw } = {}) {
  return mf.dispatchFetch(`https://accounts.test${path}`, {
    method,
    headers: {
      ...(data !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers,
    },
    body: data !== undefined ? JSON.stringify(data) : raw,
  });
}

async function register(username = 'Player_One') {
  const response = await request('/register', { method: 'POST', data: { username, password,
    email: username.toLowerCase() + '@example.com', phone: '+1202555' + String(++signupCounter).padStart(4, '0') } });
  assert.equal(response.status, 201, JSON.stringify(await response.clone().json()));
  return response.json();
}

test('readiness validates the migrated database and configuration', async () => {
  const response = await request('/ready');
  assert.equal(response.status, 200);
  assert.equal((await response.json()).ready, true);
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  const discordReady = await request('/discord/ready');
  assert.equal(discordReady.status, 200);
  assert.ok(Object.values((await discordReady.json()).checks).every(Boolean));
});

test('register, verify, case-insensitive login, account, and logout work together', async () => {
  const account = await register();
  assert.deepEqual(Object.keys(account.user).sort(), ['created_at', 'id', 'username']);
  const stored = await db.prepare('SELECT password_hash FROM users').first();
  assert.match(stored.password_hash, /^pbkdf2-sha256\$600000\$/);
  assert.ok(!stored.password_hash.includes(password));
  const verification = await request('/verify', { token: account.token });
  assert.equal(verification.status, 200);
  assert.equal((await verification.json()).user.id, account.user.id);
  const login = await request('/login', { method: 'POST', data: { username: 'player_one', password } });
  assert.equal(login.status, 200);
  const loginBody = await login.json();
  assert.notEqual(loginBody.token, account.token);
  const profile = await request('/account', { token: loginBody.token });
  const profileBody = await profile.json();
  assert.equal(profileBody.id, account.user.id);
  assert.equal(profileBody.email_verified, false);
  const logout = await request('/logout', { method: 'POST', token: loginBody.token });
  assert.equal(logout.status, 200);
  assert.equal((await request('/verify', { token: loginBody.token })).status, 401);
  assert.equal((await request('/verify', { token: account.token })).status, 200);
});

test('concurrent duplicate registrations preserve one account and one session', async () => {
  const responses = await Promise.all(['Duplicate', 'duplicate'].map(username =>
    request('/register', { method: 'POST', data: { username, password, email: username.toLowerCase() + '@example.com', phone: '+12025550123' } })));
  assert.deepEqual(responses.map(r => r.status).sort(), [201, 409]);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM users').first()).n, 1);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM sessions').first()).n, 1);
});

test('invalid credentials use the same error for absent users and bad passwords', async () => {
  await register();
  for (const username of ['Player_One', 'Nonexistent']) {
    const response = await request('/login', { method: 'POST', data: { username, password: 'an incorrect password' } });
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: 'invalid_credentials' });
  }
});

test('coordinator verification requires both the key and an active player token', async () => {
  const account = await register();
  for (const key of ['', 'wrong-key']) {
    assert.equal((await request('/internal/verify', {
      method: 'POST', headers: { 'X-Coordinator-Key': key }, data: { token: account.token },
    })).status, 401);
  }
  const verify = () => request('/internal/verify', {
    method: 'POST', headers: { 'X-Coordinator-Key': coordinator }, data: { token: account.token },
  });
  assert.equal((await verify()).status, 200);
  await request('/logout', { method: 'POST', token: account.token });
  assert.equal((await verify()).status, 401);
});

test('tampered, expired, wrong-audience, and unrecorded tokens are rejected', async () => {
  const account = await register();
  const payload = JSON.parse(Buffer.from(account.token.split('.')[1], 'base64url').toString());
  const sign = (claims, key = secret) => new SignJWT(claims).setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .sign(new TextEncoder().encode(key));
  const tokens = [
    `${account.token}a`, 'e30.e30.',
    await sign({ ...payload, exp: payload.iat - 1 }),
    await sign({ ...payload, aud: 'some-other-service' }),
    await sign({ ...payload, jti: crypto.randomUUID() }),
    await sign(payload, 'a-different-secret-with-at-least-32-bytes'),
  ];
  for (const token of tokens) assert.equal((await request('/verify', { token })).status, 401);
  await db.prepare('UPDATE sessions SET expires_at = 0').run();
  assert.equal((await request('/verify', { token: account.token })).status, 401);
});

test('account rate limits apply across distinct IP addresses and return Retry-After', async () => {
  const responses = await Promise.all(Array.from({ length: 11 }, (_, i) =>
    request('/login', { method: 'POST', data: { username: 'Missing', password }, headers: { 'CF-Connecting-IP': `192.0.2.${i}` } })));
  assert.equal(responses.filter(r => r.status === 401).length, 10);
  const limited = responses.find(r => r.status === 429);
  assert.ok(limited);
  assert.ok(Number(limited.headers.get('Retry-After')) > 0);
  const rows = await db.prepare('SELECT key FROM rate_limits').all();
  assert.ok(rows.results.every(row => /^[a-f0-9]{64}$/.test(row.key)));
});

test('IP rate limits run before JSON validation', async () => {
  const responses = await Promise.all(Array.from({ length: 31 }, () => request('/login', {
    method: 'POST', raw: '{', headers: { 'Content-Type': 'application/json' },
  })));
  assert.equal(responses.filter(r => r.status === 400).length, 30);
  assert.equal(responses.filter(r => r.status === 429).length, 1);
});

test('CORS permits only configured browser origins, including preflight', async () => {
  const allowed = await request('/health', { headers: { Origin: 'https://ancientnest.net' } });
  assert.equal(allowed.status, 200);
  assert.equal(allowed.headers.get('Access-Control-Allow-Origin'), 'https://ancientnest.net');
  const denied = await request('/health', { headers: { Origin: 'https://untrusted.example' } });
  assert.equal(denied.status, 403);
  assert.equal(denied.headers.get('Access-Control-Allow-Origin'), null);
  const preflight = await request('/login', { method: 'OPTIONS', headers: {
    Origin: 'http://localhost:3000', 'Access-Control-Request-Method': 'POST',
    'Access-Control-Request-Headers': 'content-type,authorization',
  } });
  assert.equal(preflight.status, 204);
  assert.match(preflight.headers.get('Access-Control-Allow-Headers'), /Authorization/);
});

test('invalid input, oversized bodies, absent bearer tokens, and wrong methods fail safely', async () => {
  for (const data of [{ username: 'ab', password }, { username: 'Valid', password: 'short' }, [], null]) {
    assert.equal((await request('/register', { method: 'POST', data })).status, 400);
  }
  assert.equal((await request('/register', { method: 'POST', raw: '{}' })).status, 415);
  assert.equal((await request('/register', { method: 'POST', data: { extra: 'x'.repeat(5000) } })).status, 413);
  assert.equal((await request('/account')).status, 401);
  const wrongMethod = await request('/login');
  assert.equal(wrongMethod.status, 405);
  assert.equal(wrongMethod.headers.get('Allow'), 'POST');
  assert.equal((await request('/missing')).status, 404);
});

test('missing configuration and an unmigrated database report not ready', async () => {
  const broken = new Miniflare({ modules: true, script: (await build({
    entryPoints: ['src/index.js'], bundle: true, write: false, format: 'esm', platform: 'browser',
  })).outputFiles[0].text, d1Databases: ['DB'] });
  try {
    const response = await broken.dispatchFetch('https://accounts.test/ready');
    assert.equal(response.status, 503);
    const ready = await response.json();
    assert.equal(ready.checks.secrets, false);
    assert.equal(ready.checks.database, false);
    assert.equal((await broken.dispatchFetch('https://accounts.test/health')).status, 200);
    assert.equal((await broken.dispatchFetch('https://accounts.test/login', { method: 'POST' })).status, 410);
  } finally { await broken.dispose(); }
});

test('first account creation supplies an opaque device token stored only as a hash', async () => {
  const account = await register();
  assert.match(account.refresh_token, /^[a-f0-9]{64}$/);
  assert.ok(account.refresh_expires_at - account.expires_at > 89 * 86400);
  const session = await db.prepare('SELECT * FROM sessions').first();
  assert.notEqual(session.refresh_hash, account.refresh_token);
  assert.match(session.refresh_hash, /^[a-f0-9]{64}$/);
  assert.ok(!JSON.stringify(session).includes(account.refresh_token));
});

test('reopening the game restores the same account after its access token expired', async () => {
  const account = await register();
  const payload = JSON.parse(Buffer.from(account.token.split('.')[1], 'base64url').toString());
  const now = Math.floor(Date.now() / 1000);
  const expired = await new SignJWT({ ...payload, iat: now - 7200, exp: now - 3600 })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' }).sign(new TextEncoder().encode(secret));
  assert.equal((await request('/verify', { token: expired })).status, 401);
  await db.prepare('UPDATE sessions SET expires_at = ?').bind(now + 300).run();
  const response = await request('/refresh', { method: 'POST', data: { refresh_token: account.refresh_token } });
  assert.equal(response.status, 200);
  const restored = await response.json();
  assert.deepEqual(restored.user, account.user);
  assert.notEqual(restored.refresh_token, account.refresh_token);
  assert.ok(restored.refresh_expires_at >= now + 90 * 86400);
  assert.equal((await request('/verify', { token: restored.token })).status, 200);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM sessions').first()).n, 1);
});

test('concurrent refresh and lost-response retries produce the same rotated device secret', async () => {
  const account = await register();
  const refresh = token => request('/refresh', { method: 'POST', data: { refresh_token: token } });
  const responses = await Promise.all([refresh(account.refresh_token), refresh(account.refresh_token)]);
  assert.ok(responses.every(r => r.status === 200));
  const [first, second] = await Promise.all(responses.map(r => r.json()));
  assert.equal(first.refresh_token, second.refresh_token);
  const retried = await (await refresh(account.refresh_token)).json();
  assert.equal(retried.refresh_token, first.refresh_token);
  assert.equal(retried.refresh_expires_at, first.refresh_expires_at);
  assert.equal((await request('/verify', { token: first.token })).status, 200);
  const next = await (await refresh(first.refresh_token)).json();
  assert.notEqual(next.refresh_token, first.refresh_token);
  assert.equal((await refresh(account.refresh_token)).status, 401);
  await db.prepare('UPDATE sessions SET previous_refresh_until = 0').run();
  assert.equal((await refresh(first.refresh_token)).status, 401);
  assert.equal((await refresh(next.refresh_token)).status, 200);
});

test('logout using a device token revokes access and refresh only on that device', async () => {
  const first = await register();
  const second = await (await request('/login', { method: 'POST', data: { username: first.user.username, password } })).json();
  const rotated = await (await request('/refresh', { method: 'POST', data: { refresh_token: first.refresh_token } })).json();
  const logout = await request('/logout', { method: 'POST', data: { refresh_token: rotated.refresh_token } });
  assert.equal(logout.status, 200);
  for (const token of [first.token, rotated.token]) {
    assert.equal((await request('/verify', { token })).status, 401);
  }
  for (const refresh_token of [first.refresh_token, rotated.refresh_token]) {
    assert.equal((await request('/refresh', { method: 'POST', data: { refresh_token } })).status, 401);
  }
  assert.equal((await request('/verify', { token: second.token })).status, 200);
  assert.equal((await request('/refresh', { method: 'POST', data: { refresh_token: second.refresh_token } })).status, 200);
});

test('expired devices and invalid refresh tokens cannot restore a login', async () => {
  const account = await register();
  await db.prepare('UPDATE sessions SET expires_at = 0').run();
  for (const refresh_token of [account.refresh_token, '0'.repeat(64), 'malformed', null]) {
    assert.equal((await request('/refresh', { method: 'POST', data: { refresh_token } })).status, 401);
  }
  assert.equal((await request('/verify', { token: account.token })).status, 401);
});

test('bearer logout revokes persistent refresh as well as access', async () => {
  const account = await register();
  assert.equal((await request('/logout', { method: 'POST', token: account.token })).status, 200);
  assert.equal((await request('/refresh', { method: 'POST', data: { refresh_token: account.refresh_token } })).status, 401);
});

async function linkDiscord(account, id = '111111111111111111') {
  return request('/discord/exchange', { method: 'POST', token: account.token,
    data: { code: `discord-code-${id}`, code_verifier: 'x'.repeat(43), redirect_uri: 'http://127.0.0.1/callback' } });
}

function matchRequest(value) {
  return request('/internal/voice/matches', { method: 'POST', headers: { 'X-Coordinator-Key': coordinator }, data: value });
}

test('Discord linking exchanges codes on the server and binds verified Discord identity', async () => {
  const account = await register();
  assert.deepEqual(await (await request('/discord/status', { token: account.token })).json(), { linked: false, discord_id: null });
  const linked = await linkDiscord(account);
  assert.equal(linked.status, 200, JSON.stringify({ response: await linked.clone().json(), paths: discordState.paths }));
  const tokens = await linked.json();
  assert.equal(tokens.discord_id, '111111111111111111');
  assert.ok(tokens.refresh_token);
  const row = await db.prepare('SELECT id, discord_id FROM users').first();
  assert.equal(row.id, account.user.id);
  assert.equal(row.discord_id, '111111111111111111');
  const refreshed = await request('/discord/refresh', { method: 'POST', token: account.token, data: { refresh_token: tokens.refresh_token } });
  assert.equal(refreshed.status, 200);
  const badGrant = await request('/discord/refresh', { method: 'POST', token: account.token, data: { refresh_token: 'invalid' } });
  assert.equal(badGrant.status, 401);
  assert.deepEqual(await badGrant.json(), { error: 'discord_authorization_expired' });
});

test('Discord linking rejects missing game auth, alternate redirects, bad PKCE, and missing voice scopes', async () => {
  assert.equal((await request('/discord/status')).status, 401);
  const account = await register();
  for (const extra of [{ redirect_uri: 'https://attacker.example' }, { code_verifier: 'short' }]) {
    const response = await request('/discord/exchange', { method: 'POST', token: account.token, data: {
      code: 'discord-code-111111111111111111', code_verifier: 'x'.repeat(43), redirect_uri: 'http://127.0.0.1/callback', ...extra,
    } });
    assert.equal(response.status, 400);
  }
  discordState.scope = 'identify';
  assert.equal((await linkDiscord(account)).status, 403);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM users WHERE discord_id IS NOT NULL').first()).n, 0);
  discordState.scope = 'identify sdk.social_layer';
  const loopback = await request('/discord/exchange', { method: 'POST', token: account.token, data: {
    code: 'discord-code-111111111111111111', code_verifier: 'x'.repeat(43), redirect_uri: 'http://127.0.0.1:55667/callback',
  } });
  assert.equal(loopback.status, 200);
});

test('a Discord account cannot bind to two players or switch behind an existing link', async () => {
  const first = await register('FirstPlayer');
  const second = await register('OtherPlayer');
  assert.equal((await linkDiscord(first)).status, 200);
  assert.equal((await linkDiscord(second)).status, 409);
  assert.equal((await linkDiscord(first, '222222222222222222')).status, 409);
  const wrongUserRefresh = await request('/discord/refresh', { method: 'POST', token: first.token,
    data: { refresh_token: 'discord-refresh-222222222222222222' } });
  assert.equal(wrongUserRefresh.status, 409);
});

test('only the coordinator assigns server-managed lobbies, with one private room per team', async () => {
  const first = await register('FirstPlayer');
  const second = await register('OtherPlayer');
  const outsider = await register('Outsider');
  await linkDiscord(first);
  await linkDiscord(second, '222222222222222222');
  const value = { match_id: 'match-one', expires_at: Math.floor(Date.now() / 1000) + 1800,
    teams: [{ team_id: 'red', player_ids: [first.user.id] }, { team_id: 'blue', player_ids: [second.user.id] }] };
  assert.equal((await request('/internal/voice/matches', { method: 'POST', token: first.token, data: value })).status, 401);
  const created = await matchRequest(value);
  assert.equal(created.status, 201);
  assert.equal(discordState.lobbies.size, 2);
  const firstRoom = await (await request('/voice/session', { token: first.token })).json();
  const secondRoom = await (await request('/voice/session', { token: second.token })).json();
  assert.equal(firstRoom.team_id, 'red');
  assert.equal(secondRoom.team_id, 'blue');
  assert.notEqual(firstRoom.lobby_id, secondRoom.lobby_id);
  assert.deepEqual(discordState.lobbies.get(firstRoom.lobby_id).members, [{ id: '111111111111111111', additional_name: 'FirstPlayer' }]);
  assert.deepEqual(await (await request('/voice/session', { token: outsider.token })).json(), { assigned: false });
  assert.equal((await matchRequest(value)).status, 200);
  assert.equal(discordState.creates, 2);
  assert.equal((await request('/discord/unlink', { method: 'POST', token: first.token })).status, 409);
  const ended = await request('/internal/voice/matches/match-one', { method: 'DELETE', headers: { 'X-Coordinator-Key': coordinator } });
  assert.equal(ended.status, 200);
  assert.equal(discordState.lobbies.size, 0);
  assert.deepEqual(await (await request('/voice/session', { token: first.token })).json(), { assigned: false });
  assert.equal((await request('/discord/unlink', { method: 'POST', token: first.token })).status, 200);
});

test('voice assignment rejects unlinked, duplicate, and overlapping players', async () => {
  const account = await register();
  const value = { match_id: 'one', expires_at: Math.floor(Date.now() / 1000) + 1000,
    teams: [{ team_id: 'red', player_ids: [account.user.id] }] };
  assert.equal((await matchRequest(value)).status, 409);
  await linkDiscord(account);
  const duplicated = { ...value, teams: [...value.teams, { team_id: 'blue', player_ids: [account.user.id] }] };
  assert.equal((await matchRequest(duplicated)).status, 400);
  assert.equal((await matchRequest(value)).status, 201);
  assert.equal((await matchRequest({ ...value, match_id: 'two' })).status, 409);
  assert.equal(discordState.creates, 1);
  await db.prepare('UPDATE voice_matches SET expires_at = 0').run();
  assert.deepEqual(await (await request('/voice/session', { token: account.token })).json(), { assigned: false });
});

test('partial Discord room creation rolls back and failed deletion stays pending for retry', async () => {
  const first = await register('FirstPlayer');
  const second = await register('OtherPlayer');
  await linkDiscord(first);
  await linkDiscord(second, '222222222222222222');
  discordState.failCreate = 2;
  discordState.failDelete = true;
  const response = await matchRequest({ match_id: 'broken', expires_at: Math.floor(Date.now() / 1000) + 1800,
    teams: [{ team_id: 'red', player_ids: [first.user.id] }, { team_id: 'blue', player_ids: [second.user.id] }] });
  assert.equal(response.status, 503);
  assert.equal((await db.prepare('SELECT status FROM voice_matches').first()).status, 'deleting');
  assert.deepEqual(await (await request('/voice/session', { token: first.token })).json(), { assigned: false });
  discordState.failDelete = false;
  const retry = await request('/internal/voice/matches/broken', { method: 'DELETE', headers: { 'X-Coordinator-Key': coordinator } });
  assert.equal(retry.status, 200);
  assert.equal(discordState.lobbies.size, 0);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM voice_matches').first()).n, 0);
});

test('signup requires normalized email and phone and enforces their uniqueness', async () => {
  const base = { username: 'Contacts', password, email: '  CONTACTS@EXAMPLE.COM ', phone: '(202) 555-0123' };
  for (const missing of ['email', 'phone']) {
    assert.equal((await request('/register', { method: 'POST', data: { ...base, [missing]: '' } })).status, 400);
  }
  const response = await request('/register', { method: 'POST', data: base });
  assert.equal(response.status, 201);
  const user = await db.prepare('SELECT email, phone FROM users').first();
  assert.deepEqual(user, { email: 'contacts@example.com', phone: '+2025550123' });
  assert.equal((await request('/register', { method: 'POST', data: { ...base, username: 'Different' } })).status, 409);
});

test('delivered codes verify email and phone, are hashed at rest, and cannot be reused', async () => {
  const account = await register();
  const codes = discordState.deliveries;
  assert.equal(codes.length, 2);
  const stored = (await db.prepare('SELECT code FROM verification_codes').all()).results;
  assert.ok(stored.every(row => /^hmac:[a-f0-9]{64}$/.test(row.code)));
  for (const { type, code } of codes) {
    assert.match(code, /^\d{6}$/);
    assert.equal((await request(`/verify/${type}`, { method: 'POST', token: account.token, data: { code } })).status, 200);
    assert.equal((await request(`/verify/${type}`, { method: 'POST', token: account.token, data: { code } })).status, 400);
  }
  const profile = await (await request('/account', { token: account.token })).json();
  assert.deepEqual(profile.verification, { email: true, phone: true, discord: false, fully_verified: false });
  await linkDiscord(account);
  const verified = await (await request('/verify', { token: account.token })).json();
  assert.equal(verified.user.fully_verified, true);
});

test('verification exhausts guesses and resend invalidates previous challenges with delivery limits', async () => {
  const account = await register();
  const old = discordState.deliveries.find(value => value.type === 'email').code;
  const wrong = old === '000000' ? '111111' : '000000';
  for (let i = 0; i < 5; i++) {
    assert.equal((await request('/verify/email', { method: 'POST', token: account.token, data: { code: wrong } })).status, 400);
  }
  assert.equal((await request('/verify/email', { method: 'POST', token: account.token, data: { code: old } })).status, 429);
  const resend = () => request('/verify/email/resend', { method: 'POST', token: account.token, data: {} });
  assert.equal((await resend()).status, 200);
  assert.equal((await db.prepare("SELECT COUNT(*) AS n FROM verification_codes WHERE type = 'email' AND used = 0").first()).n, 1);
  const fresh = discordState.deliveries.at(-1).code;
  assert.equal((await resend()).status, 200);
  assert.equal((await resend()).status, 429);
  const latest = discordState.deliveries.at(-1).code;
  assert.equal((await request('/verify/email', { method: 'POST', token: account.token, data: { code: latest } })).status, 200);
  assert.match(fresh, /^\d{6}$/);
});

test('delivery failures preserve the account and expose only safe provider errors', async () => {
  discordState.failEmail = true;
  const account = await register();
  assert.deepEqual(account.send_errors, [{ email: 'provider_request_failed' }]);
  assert.equal((await request('/account', { token: account.token })).status, 200);
  assert.equal(discordState.deliveries.length, 1);
});

test('browser Discord linking uses PKCE and independent single-use state bound to an active session', async () => {
  const account = await register();
  const start = await (await request('/auth/discord', { token: account.token })).json();
  const authorize = new URL(start.url);
  const state = authorize.searchParams.get('state');
  const claims = JSON.parse(Buffer.from(account.token.split('.')[1], 'base64url').toString());
  assert.notEqual(state, claims.jti);
  assert.equal(authorize.searchParams.get('code_challenge_method'), 'S256');
  assert.equal(start.redirect_uri, 'https://accounts.test/auth/discord/callback');
  const saved = await db.prepare('SELECT * FROM oauth_states').first();
  assert.notEqual(saved.state_hash, state);
  assert.equal(saved.token_id, claims.jti);
  const callback = `/auth/discord/callback?state=${state}&code=discord-code-111111111111111111`;
  assert.equal((await request(callback)).status, 200);
  assert.equal((await request(callback)).status, 400);
  assert.equal((await db.prepare('SELECT discord_id FROM users').first()).discord_id, '111111111111111111');
  const another = new URL((await (await request('/auth/discord', { token: account.token })).json()).url);
  await request('/logout', { method: 'POST', token: account.token });
  assert.equal((await request(`/auth/discord/callback?state=${another.searchParams.get('state')}&code=discord-code-111111111111111111`)).status, 400);
});

test('password changes revoke every device and allow only the new password', async () => {
  const account = await register();
  const other = await (await request('/login', { method: 'POST', data: { username: account.user.username, password } })).json();
  const nextPassword = 'a changed strong password';
  const change = await request('/account/password', { method: 'POST', token: account.token,
    data: { current_password: password, new_password: nextPassword } });
  assert.equal(change.status, 200);
  for (const device of [account, other]) {
    assert.equal((await request('/verify', { token: device.token })).status, 401);
    assert.equal((await request('/refresh', { method: 'POST', data: { refresh_token: device.refresh_token } })).status, 401);
  }
  assert.equal((await request('/login', { method: 'POST', data: { username: account.user.username, password } })).status, 401);
  assert.equal((await request('/login', { method: 'POST', data: { username: account.user.username, password: nextPassword } })).status, 200);
});

test('exported legacy passwords and JWT sessions remain usable and upgrade on login', async () => {
  const id = crypto.randomUUID();
  const salt = Buffer.alloc(16, 7);
  const hash = pbkdf2Sync(password, salt, 100000, 32, 'sha256').toString('base64');
  await db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email, phone)
    VALUES (?, ?, ?, ?, ?, ?)`).bind(id, 'Legacy', hash, salt.toString('base64'), 'legacy@example.com', '+12025550123').run();
  const now = Math.floor(Date.now() / 1000);
  const jti = crypto.randomUUID();
  await db.prepare('INSERT INTO sessions (token_id, user_id, issued_at, expires_at) VALUES (?, ?, ?, ?)')
    .bind(jti, id, now, now + 86400).run();
  const token = await new SignJWT({ sub: id, username: 'Legacy', jti, iat: now, exp: now + 86400 })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' }).sign(new TextEncoder().encode(secret));
  assert.equal((await request('/verify', { token })).status, 200);
  const login = await request('/login', { method: 'POST', data: { username: 'legacy', password } });
  assert.equal(login.status, 200);
  assert.ok((await login.json()).refresh_token);
  assert.match((await db.prepare('SELECT password_hash FROM users').first()).password_hash, /^pbkdf2-sha256\$600000\$/);
  assert.equal((await request('/verify', { token })).status, 200);
  await db.prepare('UPDATE users SET banned = 1').run();
  assert.equal((await request('/verify', { token })).status, 401);
});

test('live service-test page is public, isolated by CSP, and works on its own Worker origin', async () => {
  for (const [path, type] of [['/setup-test', 'text/html'], ['/setup-test.js', 'text/javascript'], ['/setup-test.css', 'text/css']]) {
    const response = await request(path);
    assert.equal(response.status, 200);
    assert.ok(response.headers.get('Content-Type').startsWith(type));
    assert.match(response.headers.get('Content-Security-Policy'), /frame-ancestors 'none'/);
    const text = await response.text();
    assert.ok(!text.includes(secret));
    assert.ok(!text.includes(coordinator));
  }
  assert.equal((await request('/setup-test', { method: 'POST' })).status, 405);
  const profile = await register();
  const verified = await request('/verify', { token: profile.token, headers: { Origin: 'https://accounts.test' } });
  assert.equal(verified.status, 200);
  assert.equal(verified.headers.get('Access-Control-Allow-Origin'), 'https://accounts.test');
  const external = await request('/verify', { token: profile.token, headers: { Origin: 'https://evil.example' } });
  assert.equal(external.status, 403);
});


test('game assertions bind the account to its RSA game key and are isolated from access tokens', async () => {
  const account = await register();
  const { publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const pem = publicKey.export({ type: 'spki', format: 'pem' });
  const key_hash = createHash('sha256').update(pem).digest('hex');
  const response = await request('/api/game/assertion', { method: 'POST', token: account.token, data: { public_key: pem } });
  assert.equal(response.status, 200);
  const issued = await response.json();
  assert.equal(issued.key_hash, key_hash);
  assert.ok(issued.expires_in <= 600);
  const verify = assertion => request('/api/game/verify', { method: 'POST', data: { assertion, key_hash } });
  assert.deepEqual(await (await verify(issued.assertion)).json(), { valid: true, account_id: account.user.id, username: account.user.username, key_hash });
  assert.equal((await verify(account.token)).status, 401);
  assert.equal((await request('/verify', { token: issued.assertion })).status, 401);
  assert.equal((await request('/api/game/verify', { method: 'POST', data: { assertion: issued.assertion, key_hash: '0'.repeat(64) } })).status, 401);
  await request('/logout', { method: 'POST', token: account.token });
  assert.equal((await verify(issued.assertion)).status, 401);
});

test('assertion issuance requires a real authenticated RSA public key', async () => {
  assert.equal((await request('/api/game/assertion', { method: 'POST', data: {} })).status, 401);
  const account = await register();
  for (const public_key of ['not a key', '-----BEGIN PUBLIC KEY-----broken-----END PUBLIC KEY-----']) {
    assert.equal((await request('/api/game/assertion', { method: 'POST', token: account.token, data: { public_key } })).status, 400);
  }
  const { publicKey } = generateKeyPairSync('rsa', { modulusLength: 1024 });
  assert.equal((await request('/api/game/assertion', { method: 'POST', token: account.token,
    data: { public_key: publicKey.export({ type: 'spki', format: 'pem' }) } })).status, 400);
});
