import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { assertCompatible, inspectionSql } from './database-shape.mjs';

const target = process.argv[2];
if (!['--local', '--remote'].includes(target) || process.argv.length !== 3) {
  console.error('Usage: node scripts/migrate.mjs --local|--remote');
  process.exit(1);
}
const cli = fileURLToPath(new URL('../node_modules/wrangler/bin/wrangler.js', import.meta.url));
const cwd = fileURLToPath(new URL('../', import.meta.url));
const result = spawnSync(process.execPath, [cli, 'd1', 'execute', 'DB', target, '--command', inspectionSql, '--json'], { cwd, encoding: 'utf8' });
if (result.status !== 0) {
  process.stderr.write(result.stderr || 'Could not inspect the database. No migrations applied.\n');
  process.exit(1);
}
try {
  const responses = JSON.parse(result.stdout);
  if (!Array.isArray(responses) || responses.some(value => !value.success || !Array.isArray(value.results))) {
    throw new Error('Unexpected database inspection response. No migrations applied.');
  }
  assertCompatible(responses.flatMap(value => value.results));
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
if (target === '--remote') {
  const directory = join(process.env.LOCALAPPDATA || homedir(), 'AncientNest-Recovery', 'database-backups');
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const output = join(directory, 'accounts-' + new Date().toISOString().replace(/[:.]/g, '-') + '.sql');
  const exported = spawnSync(process.execPath, [cli, 'd1', 'export', 'DB', '--remote', '--output', output], { cwd, stdio: 'inherit' });
  if (exported.status !== 0) { console.error('Database export failed. No migrations applied.'); process.exit(1); }
  const bytes = readFileSync(output);
  if (bytes.length < 20 || !/CREATE TABLE|INSERT INTO|PRAGMA/i.test(bytes.toString('utf8'))) {
    console.error('Database export could not be verified. No migrations applied.'); process.exit(1);
  }
  writeFileSync(output + '.sha256', createHash('sha256').update(bytes).digest('hex') + '\n', { mode: 0o600 });
  console.log('Private database export and SHA-256 saved: ' + output);
}
console.log('Database matches the exported schema (or is empty). Applying pending migrations.');
const applied = spawnSync(process.execPath, [cli, 'd1', 'migrations', 'apply', 'DB', target], { cwd, stdio: 'inherit' });
process.exit(applied.status ?? 1);
