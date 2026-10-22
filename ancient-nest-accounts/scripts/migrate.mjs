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
console.log('Database matches the exported schema (or is empty). Applying pending migrations.');
const applied = spawnSync(process.execPath, [cli, 'd1', 'migrations', 'apply', 'DB', target], { cwd, stdio: 'inherit' });
process.exit(applied.status ?? 1);
