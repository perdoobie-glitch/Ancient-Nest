import { build } from 'esbuild';
import { Miniflare } from 'miniflare';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const root = new URL('../', import.meta.url);
const destination = new URL('cloudflare-paste/', root);
await mkdir(destination, { recursive: true });
const bundled = await build({ entryPoints: [fileURLToPath(new URL('src/index.js', root))], bundle: true,
  write: false, format: 'esm', platform: 'browser', target: 'es2022', legalComments: 'inline' });
await writeFile(new URL('worker.js', destination), bundled.outputFiles[0].text);
const mf = new Miniflare({ modules: true, script: 'export default { fetch() { return new Response("schema builder"); } }',
  compatibilityDate: '2026-08-01', d1Databases: ['DB'] });
try {
  const db = await mf.getD1Database('DB');
  const migrations = (await readdir(new URL('migrations/', root))).filter(name => name.endsWith('.sql')).sort();
  for (const name of migrations) {
    const text = await readFile(new URL('migrations/' + name, root), 'utf8');
    for (const statement of text.replace(/--[^\n]*/g, '').split(/;(?=\s*(?:CREATE|ALTER|INSERT|UPDATE|DELETE|DROP|PRAGMA|$))/i).map(s => s.trim()).filter(Boolean)) {
      await db.prepare(statement).run();
    }
  }
  const schema = await db.prepare(`SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL
    AND (type = 'table' OR type = 'index' OR type = 'trigger') AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%'
    ORDER BY CASE WHEN name = 'users' THEN 0 WHEN type = 'table' THEN 1 WHEN type = 'index' THEN 2 ELSE 3 END, name`).all();
  const statements = schema.results.map(row => row.sql.replace(/CREATE TABLE IF NOT EXISTS/i, 'CREATE TABLE') + ';');
  const sql = '-- EMPTY DATABASE ONLY. If users already exists, STOP and use versioned migrations.\n' +
    '-- Uses your existing ancientnestaccounts database; never drop or reset it.\n\n' + statements.join('\n\n') +
    '\n\nCREATE TABLE d1_migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL);\n' +
    migrations.map(name => `INSERT INTO d1_migrations (name) VALUES ('${name}');`).join('\n') + '\n';
  await writeFile(new URL('database-empty-only.sql', destination), sql);
  await writeFile(new URL('check-existing-database.sql', destination),
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%';\n" +
    "PRAGMA table_info(users);\nPRAGMA table_info(sessions);\nPRAGMA table_info(verification_codes);\n");
  console.log('Generated dashboard Worker bundle and fresh-database SQL in cloudflare-paste/.');
} finally { await mf.dispose(); }
