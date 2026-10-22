// Provider integrations from the exported account service, with bounded requests,
// PKCE support, fixed destinations, and sanitized errors.
const API = 'https://discord.com/api/v10';

async function request(env, url, options) {
  let response;
  try {
    const req = new Request(url, { ...options, redirect: 'manual', signal: AbortSignal.timeout(10000) });
    response = env.PROVIDER_HTTP ? await env.PROVIDER_HTTP.fetch(req) : await fetch(req);
  } catch { throw new Error('provider_unavailable'); }
  if (!response.ok) throw new Error(response.status === 429 ? 'provider_rate_limited' : 'provider_request_failed');
  return response;
}

export function buildDiscordAuthorizeUrl(env, redirectUri, state, challenge) {
  const params = new URLSearchParams({ client_id: env.DISCORD_CLIENT_ID, redirect_uri: redirectUri,
    response_type: 'code', scope: 'identify sdk.social_layer', state,
    code_challenge: challenge, code_challenge_method: 'S256' });
  return `https://discord.com/oauth2/authorize?${params}`;
}

export async function exchangeDiscordCode(env, code, redirectUri, verifier) {
  const response = await request(env, `${API}/oauth2/token`, { method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: env.DISCORD_CLIENT_ID, client_secret: env.DISCORD_CLIENT_SECRET,
      grant_type: 'authorization_code', code, redirect_uri: redirectUri, code_verifier: verifier }).toString() });
  return response.json();
}

export async function getDiscordUser(accessToken, env) {
  return (await request(env, `${API}/users/@me`, { headers: { Authorization: `Bearer ${accessToken}` } })).json();
}

export async function sendVerificationEmail(env, to, code) {
  if (!env.RESEND_API_KEY) throw new Error('email_not_configured');
  await request(env, 'https://api.resend.com/emails', { method: 'POST',
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: env.EMAIL_FROM || 'noreply@ancientnest.net', to,
      subject: 'Ancient Nest — Verify your email',
      html: `<p>Your Ancient Nest verification code is <strong>${code}</strong>.</p><p>It expires in 10 minutes.</p>` }) });
  return true;
}

export async function sendVerificationSMS(env, to, code) {
  if (!env.TWILIO_ACCOUNT_SID || !env.TWILIO_AUTH_TOKEN || !env.TWILIO_FROM) throw new Error('sms_not_configured');
  if (!/^AC[0-9a-f]{32}$/i.test(env.TWILIO_ACCOUNT_SID)) throw new Error('sms_not_configured');
  const auth = btoa(`${env.TWILIO_ACCOUNT_SID}:${env.TWILIO_AUTH_TOKEN}`);
  await request(env, `https://api.twilio.com/2010-04-01/Accounts/${env.TWILIO_ACCOUNT_SID}/Messages.json`, {
    method: 'POST', headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ From: env.TWILIO_FROM, To: to,
      Body: `Ancient Nest: your verification code is ${code}. It expires in 10 minutes.` }).toString() });
  return true;
}
