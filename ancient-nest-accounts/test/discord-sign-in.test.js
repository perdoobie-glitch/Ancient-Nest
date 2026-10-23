import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { build } from 'esbuild';
import { Miniflare } from 'miniflare';
let mf, db;
let discordId = '123456789012345678';
let rejectGrant = false;
let calls = [];
const app = '1562796619722793010';
const data = { code: 'one-use-provider-code', code_verifier: 'A'.repeat(43), redirect_uri: 'http://127.0.0.1:4567/callback' };
before(async () => {
  const bundled = await build({ entryPoints: ['src/index.js'], bundle: true, write: false, format: 'esm', platform: 'browser' });
  mf = new Miniflare({ modules: true, script: bundled.outputFiles[0].text, compatibilityDate: '2026-08-01', d1Databases: ['DB'],
    bindings: { JWT_SECRET: 'test-discord-only-secret-at-least-32-bytes', COORDINATOR_API_KEY: 'test-coordinator-secret-at-least-32-bytes',
      DISCORD_CLIENT_ID: app, DISCORD_CLIENT_SECRET: 'test-discord-client-secret' },
    serviceBindings: { DISCORD_HTTP: async request => {
      const path = new URL(request.url).pathname;
      calls.push(path);
      if (path.endsWith('/oauth2/token')) {
        const form = new URLSearchParams(await request.text());
        assert.equal(form.get('client_id'), app);
        assert.equal(form.get('code_verifier'), data.code_verifier);
        if (rejectGrant) return Response.json({}, { status: 400 });
        return Response.json({ access_token: 'provider-access', refresh_token: 'provider-refresh', expires_in: 3600,
          token_type: 'Bearer', scope: 'identify sdk.social_layer' });
      }
      assert.equal(request.headers.get('Authorization'), 'Bearer provider-access');
      return Response.json({ id: discordId, username: 'DiscordUser' });
    } },
  });
  db = await mf.getD1Database('DB');
  for (const file of (await readdir('migrations')).filter(f => f.endsWith('.sql')).sort()) {
    for (const sql of (await readFile('migrations/' + file, 'utf8')).replace(/--[^\n]*/g, '').split(';').filter(s => s.trim())) {
      await db.prepare(sql).run();
    }
  }
});
after(async () => mf?.dispose());
beforeEach(async () => {
  rejectGrant = false; calls = []; discordId = '123456789012345678';
  await db.batch(['DELETE FROM users', 'DELETE FROM rate_limits'].map(s => db.prepare(s)));
});
const request = (path, value, token) => mf.dispatchFetch('https://game.test' + path, {
  method: value === undefined ? 'GET' : 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
  ...(value !== undefined ? { body: JSON.stringify(value) } : {}),
});
async function login() {
  const response = await request('/auth/discord/exchange', data);
  assert.equal(response.status, 200, JSON.stringify(await response.clone().json()));
  return response.json();
}
test('default configuration disables password and verification signup without requiring email/SMS', async () => {
  for (const path of ['/register', '/login', '/verify/email', '/verify/phone', '/account/password', '/auth/discord']) {
    assert.equal((await request(path, {})).status, 410);
  }
  assert.deepEqual(await (await request('/signup/config')).json(), { auth_provider: 'discord', email_required: false, phone_required: false });
  assert.equal((await request('/auth/discord/config')).status, 200);
});
test('Discord proof creates one profile, keeps identity on repeat login, and restores a saved device', async () => {
  const first = await login();
  assert.equal(first.verification.fully_verified, true);
  assert.equal(first.verification.email, false);
  assert.equal(first.discord.discord_id, discordId);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM users').first()).n, 1);
  const second = await login();
  assert.equal(second.user.id, first.user.id);
  const restored = await (await request('/refresh', { refresh_token: first.refresh_token })).json();
  assert.equal(restored.user.id, first.user.id);
  assert.notEqual(restored.refresh_token, first.refresh_token);
  assert.equal((await request('/discord/unlink', {}, restored.token)).status, 409);
});
test('game username changes remain attached to Discord ID and cannot take another profile name', async () => {
  const first = await login();
  let changed = await request('/profile/username', { username: 'NestPlayer' }, first.token);
  assert.equal(changed.status, 200);
  assert.equal((await login()).user.username, 'NestPlayer');
  discordId = '223456789012345678';
  const other = await login();
  assert.equal((await request('/profile/username', { username: 'NestPlayer' }, other.token)).status, 409);
  assert.equal((await request('/profile/username', { username: 'fake' })).status, 401);
  assert.equal((await request('/profile/username', { username: '<script>' }, first.token)).status, 400);
});
test('verified Discord login reuses a previously linked legacy profile without merging by username', async () => {
  await db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email, discord_id)
    VALUES ('legacy-stable-id', 'ExistingPlayer', 'legacy-password', 'salt', 'existing@example.com', ?)`)
    .bind(discordId).run();
  const signed = await login();
  assert.equal(signed.user.id, 'legacy-stable-id');
  assert.equal(signed.user.username, 'ExistingPlayer');
  assert.equal((await db.prepare('SELECT auth_provider FROM users').first()).auth_provider, 'discord');
});
test('failed Discord grants, invalid PKCE, external redirects and banned profiles cannot sign in', async () => {
  rejectGrant = true;
  assert.equal((await request('/auth/discord/exchange', data)).status, 401);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM users').first()).n, 0);
  rejectGrant = false; calls = [];
  for (const invalid of [{ ...data, code_verifier: 'short' }, { ...data, redirect_uri: 'https://attacker.example/callback' }]) {
    assert.equal((await request('/auth/discord/exchange', invalid)).status, 400);
  }
  assert.equal(calls.length, 0);
  await login();
  await db.prepare('UPDATE users SET banned = 1').run();
  assert.equal((await request('/auth/discord/exchange', data)).status, 403);
});

test('an existing game username or synthetic contact cannot preclaim a Discord identity', async () => {
  await db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email)
    VALUES ('different-owner', ?, 'legacy-password', 'salt', ?)`)
    .bind('Dis_' + discordId, discordId + '@discord.identity.invalid').run();
  const signed = await login();
  assert.notEqual(signed.user.id, 'different-owner');
  assert.match(signed.user.username, /^Player_[a-f0-9]{16}$/);
  assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM users').first()).n, 2);
});
