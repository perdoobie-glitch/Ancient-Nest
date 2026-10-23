import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile, readdir } from 'node:fs/promises';
import { build } from 'esbuild';
import { Miniflare } from 'miniflare';

const run = promisify(execFile);
const bundled = await build({ entryPoints: ['src/index.js'], bundle: true, write: false, format: 'esm', platform: 'browser' });
const mf = new Miniflare({
  modules: true, script: bundled.outputFiles[0].text, host: '127.0.0.1', port: 0,
  compatibilityDate: '2026-08-01', d1Databases: ['DB'], bindings: {
    AUTH_MODE: 'legacy',
    JWT_SECRET: 'a-local-godot-test-secret-with-at-least-32-bytes',
    COORDINATOR_API_KEY: 'a-local-godot-coordinator-key-with-at-least-32-bytes',
  },
});
try {
  const db = await mf.getD1Database('DB');
  const migrations = new URL('../migrations/', import.meta.url);
  for (const name of (await readdir(migrations)).filter(name => name.endsWith('.sql')).sort()) {
    const sql = await readFile(new URL(name, migrations), 'utf8');
    for (const statement of sql.replace(/--[^\n]*/g, '').split(/;(?=\s*(?:CREATE|ALTER|INSERT|UPDATE|DELETE|DROP|PRAGMA|$))/i).map(s => s.trim()).filter(Boolean)) await db.prepare(statement).run();
  }
  const url = (await mf.ready).origin;
  // Let a fresh editor import finish before testing native SDK classes. Immediate
  // --import --quit can abort during first-scan native teardown on Godot 4.6.
  const imported = await run(process.env.GODOT_BIN ?? 'godot', [
    '--headless', '--path', 'godot-client', '--editor', '--quit-after', '90',
  ], { timeout: 90000 });
  if (imported.stderr.includes('SCRIPT ERROR')) throw new Error(imported.stderr);
  const { stdout, stderr } = await run(process.env.GODOT_BIN ?? 'godot', [
    '--headless', '--path', 'godot-client', '--script', 'res://tests/auth_smoke.gd',
  ], { env: { ...process.env, ANCIENT_NEST_TEST_URL: url }, timeout: 180000 });
  if (stderr.includes('SCRIPT ERROR') || !stdout.includes('GODOT_AUTH_SMOKE_PASSED')) {
    throw new Error(`Godot auth smoke failed:\n${stdout}\n${stderr}`);
  }
  console.log(stdout.trim());
  const discord = await run(process.env.GODOT_BIN ?? 'godot', [
    '--headless', '--path', 'godot-client', '--script', 'res://tests/discord_smoke.gd',
  ], { timeout: 30000 });
  if (discord.stderr.includes('SCRIPT ERROR') || !discord.stdout.includes('GODOT_DISCORD_SMOKE_PASSED')) {
    throw new Error(`Godot Discord smoke failed:\n${discord.stdout}\n${discord.stderr}`);
  }
  console.log(discord.stdout.trim());
} finally {
  await mf.dispose();
}
