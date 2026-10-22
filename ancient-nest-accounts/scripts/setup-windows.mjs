import { spawn } from 'node:child_process';
import { collectMissingSecrets, checkReadiness } from './setup-support.mjs';
import { readFile, writeFile } from 'node:fs/promises';
import { createInterface } from 'node:readline/promises';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const cli = fileURLToPath(new URL('../node_modules/wrangler/bin/wrangler.js', import.meta.url));
const config = fileURLToPath(new URL('../wrangler.toml', import.meta.url));

async function command(binary, args, { input, capture = false } = {}) {
  return await new Promise((resolve, reject) => {
    const child = spawn(binary, args, { cwd: root, shell: false,
      stdio: [input === undefined ? 'inherit' : 'pipe', capture ? 'pipe' : 'inherit', capture ? 'pipe' : 'inherit'] });
    let output = '';
    if (capture) {
      child.stdout.on('data', chunk => { output += chunk; });
      // Keep stderr out of machine-readable JSON (Wrangler may print proxy notices there).
      child.stderr.resume();
    }
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(output) : reject(new Error(`Command failed: ${args[0]} (exit ${code}). ${capture ? 'Check Cloudflare access and run Setup again.' : ''}`)));
    if (input !== undefined) { child.stdin.on('error', () => {}); child.stdin.end(input); }
  });
}
const wrangler = (args, options) => command(process.execPath, [cli, ...args], options);

async function prompt(label, validate, secret = false) {
  while (true) {
    let value;
    if (secret) {
      if (!process.stdin.isTTY) throw new Error('Secret entry requires an interactive console. Double-click Setup Ancient Nest.cmd.');
      process.stdout.write(`${label}: `);
      value = await new Promise((resolve, reject) => {
        let buffer = '';
        process.stdin.setRawMode(true);
        process.stdin.setEncoding('utf8');
        process.stdin.resume();
        const finish = () => {
          process.stdin.removeListener('data', onData);
          process.stdin.setRawMode(false);
          process.stdin.pause();
          process.stdout.write('\n');
        };
        const onData = data => {
          for (const char of data) {
            if (char === '\u0003') { finish(); reject(new Error('Setup cancelled.')); return; }
            if (char === '\r' || char === '\n') { finish(); resolve(buffer); return; }
            if (char === '\u007f' || char === '\b') buffer = buffer.slice(0, -1);
            else if (char >= ' ') buffer += char;
          }
        };
        process.stdin.on('data', onData);
      });
    } else {
      const reader = createInterface({ input: process.stdin, output: process.stdout });
      try { value = await reader.question(`${label}: `); } finally { reader.close(); }
    }
    value = value.trim();
    if (validate(value)) return value;
    console.log('That value is missing or has an invalid format. Please try again.');
  }
}

async function main() {
  if (Number(process.versions.node.split('.')[0]) < 22) throw new Error('Install Node.js 22 or newer, then open Setup again.');
  console.log('This configures your existing Cloudflare database and deploys the accounts Worker.');
  console.log('Keep this window private. Secrets are hidden and sent directly to Wrangler; no secret file is created.');
  console.log('Existing Worker secrets are preserved. No database is reset or recreated.\n');
  console.log('1/6 Installing the locked project dependencies...');
  // npm-cli.js avoids a shell and handles npm.cmd correctly on Windows.
  // Node's Windows installer places npm beside node.exe.
  const { dirname, join } = await import('node:path');
  const bundledNpm = process.platform === 'win32' ? join(dirname(process.execPath), 'node_modules', 'npm', 'bin', 'npm-cli.js') : '/usr/share/nodejs/npm/bin/npm-cli.js';
  await command(process.execPath, [process.env.npm_execpath || bundledNpm, 'ci', '--ignore-scripts']);
  console.log('2/6 Connecting Cloudflare (a browser may open)...');
  const identity = await wrangler(['whoami'], { capture: true });
  if (/not authenticated|not logged in/i.test(identity)) await wrangler(['login']);
  console.log('3/6 Applying pending migrations after the schema compatibility check...');
  await command(process.execPath, ['scripts/migrate.mjs', '--remote']);
  let toml = await readFile(config, 'utf8');
  if (!/^TWILIO_FROM\s*=/m.test(toml)) {
    const phone = await prompt('SMS-capable Twilio FROM number (including +country code)', value => /^\+[1-9]\d{6,14}$/.test(value));
    toml = toml.replace(/^(EMAIL_FROM\s*=.*)$/m, `$1\nTWILIO_FROM = ${JSON.stringify(phone)}`);
  }
  const sender = /^EMAIL_FROM\s*=\s*"([^"]+)"/m.exec(toml)?.[1];
  console.log(`Email sender: ${sender}. This domain must already be verified with Resend.`);
  if (!/^# Setup sender confirmed$/m.test(toml)) {
    const confirmed = await prompt(`Resend sender address (Enter ${sender} to keep it)`, value => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value));
    toml = toml.replace(/^EMAIL_FROM\s*=.*$/m, `EMAIL_FROM = ${JSON.stringify(confirmed)}\n# Setup sender confirmed`);
  }
  await writeFile(config, toml);
  console.log('4/6 Deploying the Worker bundle...');
  await wrangler(['deploy']);
  console.log('5/6 Configuring missing service secrets...');
  const output = await wrangler(['secret', 'list', '--format', 'json'], { capture: true });
  const entries = JSON.parse(output);
  if (!Array.isArray(entries)) throw new Error('Could not read existing secret names. No secrets were changed.');
  const secrets = await collectMissingSecrets(entries.map(entry => entry.name), prompt);
  if (Object.keys(secrets).length) await wrangler(['secret', 'bulk'], { input: JSON.stringify(secrets) });
  console.log('6/6 Checking readiness...');
  const origin = /^PUBLIC_URL\s*=\s*"([^"]+)"/m.exec(toml)?.[1];
  await checkReadiness(origin);
  console.log(`\nService is configured at ${origin}. Open Ancient Nest.exe from the Windows player download.`);
  console.log('Email/SMS delivery and two-player Discord audio still need live testing before release.');
}

main().catch(error => { console.error(`\nSetup stopped: ${error.message}`); process.exitCode = 1; });
