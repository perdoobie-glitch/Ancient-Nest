import { test } from 'node:test';
import assert from 'node:assert/strict';
import { collectMissingSecrets, checkReadiness } from '../scripts/setup-support.mjs';

const names = ['JWT_SECRET', 'COORDINATOR_API_KEY', 'RESEND_API_KEY', 'TWILIO_ACCOUNT_SID',
  'TWILIO_AUTH_TOKEN', 'DISCORD_CLIENT_SECRET', 'DISCORD_BOT_TOKEN'];

test('rerunning setup preserves every existing secret and does not prompt for replacements', async () => {
  const result = await collectMissingSecrets(names, () => assert.fail('Existing secrets must not be requested'));
  assert.deepEqual(result, {});
});

test('setup generates only a missing JWT key and requires the real shared coordinator key', async () => {
  const onlyJwt = await collectMissingSecrets(names.filter(name => name !== 'JWT_SECRET'), () => assert.fail());
  assert.deepEqual(Object.keys(onlyJwt), ['JWT_SECRET']);
  assert.match(onlyJwt.JWT_SECRET, /^[a-f0-9]{64}$/);
  let prompted = false;
  const onlyCoordinator = await collectMissingSecrets(names.filter(name => name !== 'COORDINATOR_API_KEY'),
    async (label, validate, hidden) => {
      prompted = true;
      assert.match(label, /Existing matchmaking/);
      assert.equal(hidden, true);
      assert.equal(validate('short'), false);
      return 'the-same-coordinator-key-as-matchmaking-worker';
    });
  assert.equal(prompted, true);
  assert.equal(onlyCoordinator.COORDINATOR_API_KEY, 'the-same-coordinator-key-as-matchmaking-worker');
  assert.equal(onlyCoordinator.JWT_SECRET, undefined);
});

test('setup rejects invalid secret values without returning a partial upload', async () => {
  await assert.rejects(collectMissingSecrets(names.filter(name => name !== 'DISCORD_CLIENT_SECRET'), async () => 'invalid'), /Invalid value/);
});

const accountChecks = { secrets: true, database: true, jwt_secret: true, resend: true, twilio: true, discord: true };
const discordChecks = { application: true, client_secret: true, bot_token: true, database: true };

test('setup probes both live readiness routes without following redirects', async () => {
  const paths = [];
  await checkReadiness('https://accounts.example', async (url, options) => {
    paths.push(url);
    assert.equal(options.redirect, 'error');
    return Response.json({ ready: true, checks: url.endsWith('/discord/ready') ? discordChecks : accountChecks });
  });
  assert.deepEqual(paths, ['https://accounts.example/ready', 'https://accounts.example/discord/ready']);
});

test('base readiness alone cannot report setup success with missing schemas or Discord', async () => {
  for (const checks of [{}, { ...accountChecks, discord: false }, { ...accountChecks, database: false }]) {
    await assert.rejects(checkReadiness('https://accounts.example', async () => Response.json({ ready: true, checks })), /Readiness failed/);
  }
  await assert.rejects(checkReadiness('https://accounts.example', async url => Response.json({ ready: true,
    checks: url.endsWith('/discord/ready') ? { ...discordChecks, bot_token: false } : accountChecks })), /Readiness failed/);
  await assert.rejects(checkReadiness('http://accounts.example', () => assert.fail()), /HTTPS/);
});
