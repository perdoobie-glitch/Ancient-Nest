// Call from the authoritative matchmaking Worker after finalizing a roster.
// Player IDs are Ancient Nest account IDs, never client-selected Discord IDs.
async function voiceRequest(env, path, method, data) {
  const origin = new URL(env.ACCOUNT_API);
  if (origin.protocol !== 'https:') throw new Error('ACCOUNT_API must use HTTPS');
  const response = await fetch(new URL(path, origin), {
    method, redirect: 'manual', signal: AbortSignal.timeout(100000),
    headers: { 'Content-Type': 'application/json', 'X-Coordinator-Key': env.COORDINATOR_API_KEY },
    ...(data ? { body: JSON.stringify(data) } : {}),
  });
  if (!response.ok) throw new Error(`Team voice request failed (${response.status})`);
  return response.json();
}

export function createTeamVoice(env, { matchId, teams, expiresAt }) {
  return voiceRequest(env, '/internal/voice/matches', 'POST', {
    match_id: matchId, expires_at: expiresAt,
    teams: teams.map(team => ({ team_id: team.id, player_ids: team.playerIds })),
  });
}

export function endTeamVoice(env, matchId) {
  if (!/^[a-zA-Z0-9_-]{1,64}$/.test(matchId)) throw new Error('Invalid match ID');
  return voiceRequest(env, `/internal/voice/matches/${matchId}`, 'DELETE');
}
