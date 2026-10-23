import { randomBytes } from 'node:crypto';

const requiredSecrets = [
  ['COORDINATOR_API_KEY', 'Existing matchmaking COORDINATOR_API_KEY (32+ bytes)', value => Buffer.byteLength(value) >= 32],
  ['DISCORD_CLIENT_SECRET', 'Discord application client secret', value => value.length >= 16],
  ['DISCORD_BOT_TOKEN', 'Discord application bot token', value => value.length >= 16],
];

export async function collectMissingSecrets(existingNames, ask) {
  const existing = new Set(existingNames);
  const values = {};
  if (!existing.has('JWT_SECRET')) values.JWT_SECRET = randomBytes(32).toString('hex');
  for (const [name, label, validate] of requiredSecrets) {
    if (!existing.has(name)) {
      const value = await ask(label, validate, true);
      if (typeof value !== 'string' || !validate(value)) throw new Error(`Invalid value for ${name}. No secrets were uploaded.`);
      values[name] = value;
    }
  }
  return values;
}

export async function checkReadiness(origin, fetcher = fetch) {
  const parsed = new URL(origin);
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password || parsed.search || parsed.hash || parsed.pathname !== '/') {
    throw new Error('PUBLIC_URL must be the deployed HTTPS Worker origin.');
  }
  const endpoints = [
    ['/ready', ['secrets', 'database', 'jwt_secret', 'discord']],
    ['/discord/ready', ['application', 'client_secret', 'bot_token', 'database']],
  ];
  for (const [route, required] of endpoints) {
    const response = await fetcher(parsed.origin + route, { redirect: 'error', signal: AbortSignal.timeout(15000) });
    const status = await response.json();
    if (!response.ok || status.ready !== true || !required.every(name => status.checks?.[name] === true)) {
      throw new Error(`Readiness failed at ${route}. Check configuration in the Cloudflare dashboard, then run Setup again.`);
    }
  }
}
