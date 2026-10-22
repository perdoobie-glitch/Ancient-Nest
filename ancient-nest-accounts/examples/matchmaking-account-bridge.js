// Adapt the matchmaking Worker's existing auth hook to call this helper.
// This is an example contract; the actual matchmaking source is not in this repo.
export async function verifyPlayerToken(token, env) {
  const base = new URL(env.ACCOUNT_API);
  if (base.protocol !== 'https:') throw new Error('ACCOUNT_API must use HTTPS');
  const response = await fetch(new URL('/internal/verify', base), {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Coordinator-Key': env.COORDINATOR_API_KEY,
    },
    body: JSON.stringify({ token }),
    signal: AbortSignal.timeout(5000),
    redirect: 'manual',
  });
  if (response.status === 401) return null;
  if (!response.ok) throw new Error('Account verification unavailable');
  const result = await response.json();
  if (result.valid !== true || typeof result.user?.id !== 'string' || typeof result.user?.username !== 'string') {
    throw new Error('Invalid account verification response');
  }
  return result.user;
}
