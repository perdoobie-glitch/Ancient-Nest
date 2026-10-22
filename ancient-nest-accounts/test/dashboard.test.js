import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { Script } from 'node:vm';
import { Miniflare } from 'miniflare';
import { testScript } from '../src/live-test-page.js';

test('dashboard test-page JavaScript parses as a standalone browser script', () => {
  assert.doesNotThrow(() => new Script(testScript));
  assert.ok(!testScript.includes('localStorage'));
  assert.ok(!testScript.includes('sessionStorage'));
});

test('copy/paste Worker and fresh SQL run without npm at deployment and retain migration history', async () => {
  const source = await readFile(new URL('../cloudflare-paste/worker.js', import.meta.url), 'utf8');
  const mf = new Miniflare({ modules: true, script: source, compatibilityDate: '2026-08-01',
    d1Databases: ['DB'], bindings: { JWT_SECRET: 'dashboard-test-secret-with-more-than-32-bytes',
      COORDINATOR_API_KEY: 'dashboard-coordinator-secret-with-more-than-32-bytes' } });
  try {
    const db = await mf.getD1Database('DB');
    const sql = await readFile(new URL('../cloudflare-paste/database-empty-only.sql', import.meta.url), 'utf8');
    const statements = sql.replace(/--[^\n]*/g, '').split(';').map(s => s.trim()).filter(Boolean);
    for (const statement of statements) await db.prepare(statement).run();
    const ready = await mf.dispatchFetch('https://accounts.test/ready');
    assert.equal(ready.status, 200);
    assert.equal((await ready.json()).ready, true);
    assert.equal((await db.prepare('SELECT COUNT(*) AS n FROM d1_migrations').first()).n, 4);
    await db.prepare(`INSERT INTO users (id, username, password_hash, password_salt, email, phone)
      VALUES ('preserved', 'Existing', 'hash', 'salt', 'existing@example.com', '+12025550123')`).run();
    await assert.rejects(db.prepare(statements[0]).run(), /already exists/);
    assert.equal((await db.prepare('SELECT id FROM users').first()).id, 'preserved');
    const page = await mf.dispatchFetch('https://accounts.test/setup-test');
    assert.equal(page.status, 200);
  } finally { await mf.dispose(); }
});
