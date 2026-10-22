import { prompt } from './interactive.mjs';

const origin = 'https://ancient-nest-accounts.ancientnest-llc.workers.dev';
const uuid = value => /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value);

async function main() {
  console.log('Two-player live Discord voice test. Both players must already be signed in and Discord linked.');
  console.log('The coordinator key stays in memory. Never share it with the other player.');
  const key = process.env.COORDINATOR_API_KEY || await prompt('Coordinator API key (hidden)', value => Buffer.byteLength(value) >= 32, true);
  const first = await prompt('First game account ID (shown on /setup-test)', uuid);
  const second = await prompt('Second game account ID', value => uuid(value) && value !== first);
  const match = 'voice-test-' + crypto.randomUUID();
  const request = async (path, method, data) => {
    const response = await fetch(origin + path, { method, redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { 'X-Coordinator-Key': key, ...(data ? { 'Content-Type': 'application/json' } : {}) },
      body: data ? JSON.stringify(data) : undefined });
    const value = await response.json();
    if (!response.ok) throw new Error(value.error || `HTTP ${response.status}`);
    return value;
  };
  let attempted = false;
  let failure;
  try {
    attempted = true;
    await request('/internal/voice/matches', 'POST', { match_id: match,
      expires_at: Math.floor(Date.now() / 1000) + 900, teams: [{ team_id: 'test', player_ids: [first, second] }] });
    console.log('Server room created. Both game clients should join their assigned team call within a few seconds.');
    console.log('On both Windows PCs: hold V and speak in each direction. Test team mute and deafen.');
    console.log('Keep a separate personal Discord friends call open and verify it still works.');
    console.log('This script cannot hear the microphones or mark the audio checks as passed.');
    await prompt('Press Enter after the human audio checks to end and delete the test room', () => true);
  } catch (error) { failure = error; }
  finally {
    if (attempted) {
      try {
        await request('/internal/voice/matches/' + match, 'DELETE');
        console.log('Test room deleted. Confirm that both team calls end.');
      } catch {
        console.error('Could not confirm room deletion. The room has a 15-minute expiry; scheduled cleanup retries.');
        console.error('Test match ID: ' + match);
        failure ??= new Error('Voice test cleanup was not confirmed.');
      }
    }
  }
  if (failure) throw failure;
  console.log('Test assignment and cleanup completed. Audio results require your own confirmation.');
}

main().catch(error => { console.error('Voice test stopped: ' + error.message); process.exitCode = 1; });
